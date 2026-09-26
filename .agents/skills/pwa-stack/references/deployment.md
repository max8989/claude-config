# Deployment

Use `templates/deploy.sh` as the default generated workflow. Its behavioral
reference is [Chinese Learning's deploy.sh](https://github.com/max8989/chinese-learning/blob/main/deploy.sh):
branch guards, fast-forward pull, separate targets, migration restart,
superuser synchronization, and health verification. App names, secrets, host
ports, and domain features must come from the generated project.

## Script and Compose contract

| Target | Branch default | Env file | Compose project | PocketBase data | APP_ENV |
|---|---|---|---|---|---|
| prod (default) | main | .env | app slug | ./pocketbase/pb_data | production |
| dev | dev | .env.dev | app slug-dev | ./pocketbase/pb_data_dev | development |

Keep `set -Eeuo pipefail` and all executable deployment logic in `main()`.
The final `main "$@"` call must be the last command: a pull can replace the
script while Bash is executing it. `DEPLOY_BRANCH=release ./deploy.sh prod`
is an explicit invocation override, not an env-file setting. Wrong branches,
missing env files, and tracked local edits fail before pull or container changes.

The selected trusted, operator-owned env file is sourced with auto-export
before Compose interpolation/builds. Use Bash-compatible assignments with no
spaces around `=`; single-quote literal secrets containing `$`, `#`, spaces,
or shell metacharacters. Do not use commands, interpolation, or multiline
secrets in these files. Compose dotenv accepts syntax Bash does not; keep to
their common literal subset. Never print resolved env/config values, use
`set -x`, commit secrets, or put private values into `VITE_*`.

The script sets the target's isolation variables after sourcing the env file.
Keep them out of `.env.example` assignments so copying `.env` for dev cannot
reuse production's project/data. `--env-file` controls interpolation;
`env_file: ${ENV_FILE:-.env}` separately selects the API container's env file.
Use required `APP_PORT`/`PB_ADMIN_PORT` from the selected file; no host port
defaults in the script. Both dev host ports must be free and different from
both production ports. Do not use fixed container names, globally shared image
tags, external app data volumes, or a fixed `frontend_dist` volume name.

Keep service names `pocketbase`, `api`, `frontend-build` synchronized with the
script. The frontend copier must finish before the API starts and run again on
each deploy, including when the image has not changed. Its template therefore
exits after copying; Compose waits for successful completion and the script
recreates the services. The deployment has a restart window; it is not zero
downtime. Retain old hashed assets if existing clients need them; define a
separate retention policy rather than deleting all assets during deployment.

The script restarts PocketBase to apply bind-mounted migrations, polls its
internal `/api/health` with a per-request timeout, upserts the configured
superuser without echoing credentials, then restarts the API to renew its
authentication. The public API `/api/health` must check PocketBase and return
a failure status if unhealthy; it must not fall through to the SPA. Adapt the
service names, internal port, binary path, admin model, and health routes if
the generated stack changes. Both health loops must exit nonzero on exhaustion.

Errors after Compose validation print bounded recent logs and service status.
The template redacts known secret values and omits credential-bearing lines;
the generated application must also redact at log emission, including query
tokens, arbitrary payloads, and personal data. Do not rely on a deployment
filter as the only protection. A failed deployment does not delete data or
roll back migrations automatically. Back up data and plan migration recovery
before production deployment.

## Generated README / server handoff

Require Git, Bash, curl, and a compatible Docker Engine with Compose v2 on the
target host. Verify the existing Dockerfile's platform support against that
host. Confirm the server/environment, available ports, repository access,
backup location and existing reverse proxy/TLS before executing deployment.
Do not install a proxy or change host infrastructure as part of scaffolding.

Production (replace repo/project placeholders):

```bash
git clone <repo> <project>
cd <project>
git switch main
cp .env.example .env
chmod 600 .env
# Fill ports, a strong PB_ADMIN_PASSWORD, and selected feature settings.
./deploy.sh
```

Make `deploy.sh` executable when generating it and commit its executable bit.
The first run provisions the superuser; use the protected PocketBase admin UI
to add app users with `active = true`. The app is served on `APP_PORT`;
PocketBase admin defaults to loopback. Configure the host's chosen HTTPS
proxy for the app; this skill does not choose its implementation.

For side-by-side server development, use a second clone/check-out directory.
Ensure a remote `dev` branch exists and the checkout tracks it before pulling:

```bash
# In the separate development checkout, securely prepare its env file.
cp .env .env.dev
chmod 600 .env.dev
# Change BOTH host ports; choose independent credentials and feature settings.
git switch dev
./deploy.sh dev
```

If `.env` is absent there, copy `.env.example` to `.env.dev` instead. Do not
copy production database contents as part of setup. Ignore `.env`, `.env.*`
(except `.env.example`), `pb_data`, and `pb_data_dev` in Git.

## Verify before handing off

- Run `bash -n deploy.sh`; check executable mode and no unresolved placeholders.
- Use synthetic, non-secret env files to run Compose `config --quiet` for both
  targets. Set `ENV_FILE`, `COMPOSE_PROJECT_NAME`, `PB_DATA_DIR`, and `APP_ENV`
  exactly as the script does. A bare `--env-file .env.dev` alone is insufficient
  to select the API env file, project, and data path.
- Inspect resolved configs privately: distinct projects, host ports, data bind
  mounts, frontend volumes, and correct API env/build args. Do not print secrets.
- Run `python3 scripts/test_deploy.py` from this skill directory to exercise
  the template with isolated fake Git/Docker/curl commands; this never deploys.
- For an authorized live run, verify both health checks and service status,
  frontend assets/update flow, and that deploying dev leaves prod unchanged.
  Report mocked/config-only verification separately from real container tests.

Consult current [Compose interpolation](https://docs.docker.com/compose/how-tos/environment-variables/variable-interpolation/),
[Compose startup dependencies](https://docs.docker.com/compose/how-tos/startup-order/),
[Compose up](https://docs.docker.com/reference/cli/docker/compose/up/), and
[PocketBase production guidance](https://pocketbase.io/docs/going-to-production/)
when changing these contracts. Check Context7 first where available.
