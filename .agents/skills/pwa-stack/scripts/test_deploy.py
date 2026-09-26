#!/usr/bin/env python3
"""Exercise deployment in temporary checkouts; never contact a Docker daemon."""

import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


SKILL = Path(__file__).resolve().parents[1]
FAKE_COMMAND = r'''#!/usr/bin/env python3
import json, os, pathlib, sys
command = pathlib.Path(sys.argv[0]).name
args = sys.argv[1:]
with open(os.environ["TEST_COMMAND_LOG"], "a") as log:
    log.write(json.dumps({"command": command, "args": args, "env": {
        key: os.environ.get(key) for key in (
            "ENV_FILE", "COMPOSE_PROJECT_NAME", "PB_DATA_DIR", "APP_ENV",
            "APP_PORT", "VITE_VAPID_PUBLIC_KEY"
        )}}) + "\n")
if command == "git":
    if args[0] == "rev-parse":
        print(os.environ.get("TEST_BRANCH", "main"))
    elif args[0] == "status":
        print(" M tracked-file" if os.environ.get("TEST_DIRTY") else "")
    elif args[0] == "pull":
        if os.environ.get("TEST_PULL_FAIL"):
            sys.exit(1)
        if os.environ.get("TEST_REWRITE"):
            pathlib.Path("deploy.sh").write_text("#!/bin/bash\nexit 97\n")
elif command == "docker":
    if "logs" in args:
        print("healthy diagnostic marker")
        print("diagnostic value " + os.environ["PB_ADMIN_PASSWORD"])
        print('request /api/events?token=synthetic-session-secret')
        print('{"authorization":"Bearer synthetic-bearer-secret"}')
    elif "upsert" in args and os.environ.get("TEST_UPSERT_FAIL"):
        sys.exit(1)
    elif "wget" in args and os.environ.get("TEST_PB_FAIL"):
        sys.exit(1)
    elif "up" in args and os.environ.get("TEST_BUILD_FAIL"):
        print("build failed")
        sys.exit(1)
    elif "config" in args and os.environ.get("TEST_CONFIG_FAIL"):
        sys.exit(1)
elif command == "curl" and os.environ.get("TEST_API_FAIL"):
    sys.exit(1)
'''


class DeploymentTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="pwa deploy test ")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.bin = self.root / "bin"
        self.bin.mkdir()
        fake = self.bin / "fake"
        fake.write_text(FAKE_COMMAND)
        fake.chmod(0o755)
        for name in ("git", "docker", "curl", "sleep"):
            (self.bin / name).symlink_to(fake)
        self.script = self.root / "deploy.sh"
        self.script.write_text(
            (SKILL / "templates/deploy.sh").read_text().replace("__APP_SLUG__", "sample-app")
        )
        self.script.chmod(0o755)
        self.log = self.root / "commands.jsonl"
        self.env = {
            "PATH": str(self.bin) + os.pathsep + os.environ["PATH"],
            "HOME": str(self.root),
            "TEST_COMMAND_LOG": str(self.log),
            "VITE_VAPID_PUBLIC_KEY": "",  # selected file must override this
            "COMPOSE_PROJECT_NAME": "unrelated-host-project",
        }
        for name, app_port, admin_port in ((".env", 18090, 18093), (".env.dev", 28090, 28093)):
            (self.root / name).write_text(
                f"APP_PORT={app_port}\nPB_ADMIN_PORT={admin_port}\n"
                "PB_ADMIN_EMAIL=admin@example.local\n"
                "PB_ADMIN_PASSWORD='fake-$-password-#-with spaces'\n"
                "VITE_VAPID_PUBLIC_KEY=public-test-value\n"
                "DEPLOY_HEALTH_ATTEMPTS=3\nDEPLOY_HEALTH_INTERVAL=1\n"
            )

    def run_deploy(self, *args, **env):
        self.result = subprocess.run(
            [str(self.script), *args], cwd=self.root.parent,
            env={**self.env, **env}, text=True, capture_output=True, timeout=10,
        )
        self.events = [json.loads(line) for line in self.log.read_text().splitlines()] if self.log.exists() else []
        return self.result

    def matching(self, command, argument):
        return [e for e in self.events if e["command"] == command and argument in e["args"]]

    def assert_success(self):
        self.assertEqual(self.result.returncode, 0, self.result.stderr)
        self.assertIn("OK", self.result.stdout)

    def test_default_and_explicit_production(self):
        for args in ((), ("prod",)):
            with self.subTest(args=args):
                self.log.unlink(missing_ok=True)
                self.run_deploy(*args)
                self.assert_success()
                up = self.matching("docker", "up")[0]
                self.assertEqual(up["env"]["COMPOSE_PROJECT_NAME"], "sample-app")
                self.assertEqual(up["env"]["PB_DATA_DIR"], "./pocketbase/pb_data")
                self.assertEqual(up["env"]["APP_ENV"], "production")
                self.assertEqual(up["env"]["ENV_FILE"], ".env")
                self.assertIn("--build", up["args"])
                self.assertIn("--force-recreate", up["args"])
                self.assertEqual(self.matching("git", "pull")[0]["args"], ["pull", "--ff-only"])
                self.assertEqual(self.matching("docker", "upsert")[0]["args"][-1], "fake-$-password-#-with spaces")
                self.assertNotIn("fake-$-password", self.result.stdout + self.result.stderr)
                self.assertEqual(up["env"]["VITE_VAPID_PUBLIC_KEY"], "public-test-value")

    def test_dev_isolation_survives_copied_env_and_inherited_variables(self):
        with (self.root / ".env.dev").open("a") as file:
            file.write("COMPOSE_PROJECT_NAME=sample-app\nPB_DATA_DIR=./pocketbase/pb_data\nENV_FILE=.env\nAPP_ENV=production\n")
        self.run_deploy("dev", TEST_BRANCH="dev")
        self.assert_success()
        for event in [e for e in self.events if e["command"] == "docker"]:
            self.assertEqual(event["env"]["COMPOSE_PROJECT_NAME"], "sample-app-dev")
            self.assertEqual(event["env"]["PB_DATA_DIR"], "./pocketbase/pb_data_dev")
            self.assertEqual(event["env"]["ENV_FILE"], ".env.dev")
            self.assertEqual(event["env"]["APP_ENV"], "development")
        self.assertIn("http://127.0.0.1:28090/api/health", self.matching("curl", "--fail")[0]["args"])

    def test_wrong_branch_stops_before_pull(self):
        self.run_deploy("dev")
        self.assertNotEqual(self.result.returncode, 0)
        self.assertFalse(self.matching("git", "pull"))
        self.assertFalse([e for e in self.events if e["command"] == "docker"])

    def test_explicit_branch_override(self):
        self.run_deploy(TEST_BRANCH="release", DEPLOY_BRANCH="release")
        self.assert_success()

    def test_missing_env_stops_before_pull(self):
        (self.root / ".env").unlink()
        self.run_deploy()
        self.assertNotEqual(self.result.returncode, 0)
        self.assertFalse(self.matching("git", "pull"))

    def test_dirty_checkout_stops_before_pull(self):
        self.run_deploy(TEST_DIRTY="1")
        self.assertNotEqual(self.result.returncode, 0)
        self.assertFalse(self.matching("git", "pull"))

    def test_failed_pull_stops_before_docker(self):
        self.run_deploy(TEST_PULL_FAIL="1")
        self.assertNotEqual(self.result.returncode, 0)
        self.assertFalse([e for e in self.events if e["command"] == "docker"])

    def test_script_can_be_replaced_during_pull(self):
        self.run_deploy(TEST_REWRITE="1")
        self.assert_success()
        self.assertIn("exit 97", self.script.read_text())

    def test_invalid_target_and_extra_arguments(self):
        for args in (("staging",), ("prod", "dev")):
            self.run_deploy(*args)
            self.assertNotEqual(self.result.returncode, 0)
            self.assertFalse(self.events)

    def test_invalid_config_stops_before_changes(self):
        self.run_deploy(TEST_CONFIG_FAIL="1")
        self.assertNotEqual(self.result.returncode, 0)
        self.assertFalse(self.matching("docker", "up"))

    def test_build_failure_reports_redacted_logs(self):
        self.run_deploy(TEST_BUILD_FAIL="1")
        self.assertNotEqual(self.result.returncode, 0)
        output = self.result.stdout + self.result.stderr
        self.assertIn("healthy diagnostic marker", output)
        for secret in ("fake-$-password-#-with spaces", "synthetic-session-secret", "synthetic-bearer-secret"):
            self.assertNotIn(secret, output)
        self.assertFalse(self.matching("docker", "upsert"))

    def test_pocketbase_timeout_prevents_upsert_and_api_restart(self):
        self.run_deploy(TEST_PB_FAIL="1")
        self.assertNotEqual(self.result.returncode, 0)
        self.assertEqual(len(self.matching("docker", "wget")), 3)
        self.assertFalse(self.matching("docker", "upsert"))
        self.assertFalse([e for e in self.matching("docker", "restart") if e["args"][-1] == "api"])
        self.assertTrue(self.matching("docker", "logs"))

    def test_upsert_failure_prevents_api_restart(self):
        self.run_deploy(TEST_UPSERT_FAIL="1")
        self.assertNotEqual(self.result.returncode, 0)
        self.assertFalse([e for e in self.matching("docker", "restart") if e["args"][-1] == "api"])

    def test_api_timeout_is_bounded_and_nonzero(self):
        self.run_deploy(TEST_API_FAIL="1")
        self.assertNotEqual(self.result.returncode, 0)
        requests = self.matching("curl", "--fail")
        self.assertEqual(len(requests), 3)
        self.assertTrue(all("--max-time" in e["args"] for e in requests))
        self.assertTrue(self.matching("docker", "logs"))

    def test_successful_order(self):
        self.run_deploy()
        self.assert_success()
        ordered = [self.events.index(self.matching(*pair)[0]) for pair in (
            ("git", "pull"), ("docker", "config"), ("docker", "up"),
            ("docker", "wget"), ("docker", "upsert"), ("curl", "--fail"), ("docker", "ps"),
        )]
        self.assertEqual(ordered, sorted(ordered))
        restart_api = next(e for e in self.matching("docker", "restart") if e["args"][-1] == "api")
        self.assertGreater(self.events.index(restart_api), self.events.index(self.matching("docker", "upsert")[0]))

    def test_missing_port_fails_before_docker(self):
        (self.root / ".env").write_text("PB_ADMIN_EMAIL=a\nPB_ADMIN_PASSWORD=b\n")
        self.run_deploy()
        self.assertNotEqual(self.result.returncode, 0)
        self.assertFalse([e for e in self.events if e["command"] == "docker"])


class ComposeTests(unittest.TestCase):
    def test_real_compose_resolves_isolated_targets(self):
        docker = shutil.which("docker")
        if not docker or subprocess.run([docker, "compose", "version"], capture_output=True).returncode:
            self.skipTest("Docker Compose CLI unavailable; mocked deploy checks still run")
        with tempfile.TemporaryDirectory(prefix="pwa compose test ") as temp:
            root = Path(temp)
            shutil.copytree(SKILL / "templates", root, dirs_exist_ok=True)
            compose_file = root / "docker-compose.yml"
            compose_file.write_text(compose_file.read_text().replace("__APP_SLUG__", "sample-app"))
            configs = []
            for target, file, suffix, port in (("production", ".env", "", 18090), ("development", ".env.dev", "-dev", 28090)):
                (root / file).write_text(f"APP_PORT={port}\nPB_ADMIN_PORT={port+3}\nPB_ADMIN_EMAIL=admin@example.local\nPB_ADMIN_PASSWORD=synthetic-{target}\nTZ=UTC\nVITE_VAPID_PUBLIC_KEY=public-{target}\n")
                env = {"PATH": os.environ["PATH"], "HOME": temp, "ENV_FILE": file,
                       "COMPOSE_PROJECT_NAME": "sample-app" + suffix,
                       "PB_DATA_DIR": "./pocketbase/pb_data" + ("_dev" if suffix else ""),
                       "APP_ENV": target}
                result = subprocess.run([docker, "compose", "--env-file", file, "config", "--format", "json"], cwd=root, env=env, capture_output=True, text=True, timeout=20)
                self.assertEqual(result.returncode, 0, "Compose config failed (output withheld to avoid secret disclosure)")
                config = json.loads(result.stdout)
                configs.append(config)
                self.assertEqual(config["name"], "sample-app" + suffix)
                api = config["services"]["api"]
                self.assertEqual(api["environment"]["PB_ADMIN_PASSWORD"], "synthetic-" + target)
                self.assertEqual(api["environment"]["APP_ENV"], target)
                self.assertEqual(int(api["ports"][0]["published"]), port)
                self.assertEqual(api["depends_on"]["frontend-build"]["condition"], "service_completed_successfully")
                self.assertEqual(config["services"]["frontend-build"]["build"]["args"]["VITE_VAPID_PUBLIC_KEY"], "public-" + target)
            self.assertNotEqual(configs[0]["volumes"]["frontend_dist"]["name"], configs[1]["volumes"]["frontend_dist"]["name"])
            data_paths = [next(v["source"] for v in c["services"]["pocketbase"]["volumes"] if v["target"] == "/pb/pb_data") for c in configs]
            self.assertNotEqual(*data_paths)


if __name__ == "__main__":
    unittest.main(verbosity=2)
