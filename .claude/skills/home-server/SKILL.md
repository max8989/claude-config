---
name: home-server
description: Access Maxime's home server at maxime@192.168.2.42. Use for tasks on this home server; try SSH first, then use the existing maxime-server-nix OpenVPN profile if the network connection fails.
---

# Home Server

- SSH target: `maxime@192.168.2.42`.
- Existing NetworkManager OpenVPN profile: `maxime-server-nix`.
- Use the existing SSH keys, agent and trusted host key; no credentials belong in this skill.

## Establish access

Run the bundled helper before the remote task:

```sh
bash "${CODEX_HOME:-$HOME/.codex}/skills/home-server/scripts/ensure-access.sh"
```

The helper first attempts a noninteractive SSH `hostname` probe with an eight-second connection timeout. If it succeeds, use that connection without changing the VPN. A successful probe means the server is reachable; it may be through the LAN or an already active VPN, so do not claim it proves the user is physically home.

On a network timeout, refusal or unreachable route, it checks the VPN. It activates `maxime-server-nix` only if that profile is inactive, then retries SSH once. An already active VPN is left running. Stop and report the failed step if activation or the retry fails; do not cycle connections, import profiles or change networking settings automatically.

Authentication and host-key failures stop before VPN activation. Resolve the actual SSH error using the existing key/desktop authentication setup; never weaken host-key checking or delete known-host entries to make the probe pass. If a credential prompt is necessary, the user enters it directly in the desktop prompt or terminal, never in chat.

## Work on the server

After the helper succeeds, carry out the user's authorized task through `ssh maxime@192.168.2.42`. For an interactive shell, use that command directly. Read the target project's instructions before editing or deploying there.

Setting up connectivity does not itself authorize deployments, service restarts or configuration changes. Continue work already authorized by the request without asking again merely to connect. Leave existing connections and unrelated VPN profiles alone; do not disconnect this VPN after the task unless the user asks.
