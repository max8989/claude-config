# claude-configs

Stow-managed configuration for Claude Code, Codex, and other tools that support
the AGENTS.md and Agent Skills standards. Claude files remain the canonical
source; the agent-standard files reference them.

## Layout

```
.claude/
  CLAUDE.md           # global instructions (loaded for every session)
  settings.json       # theme, default permission mode, enabled plugins
  settings.local.json # per-host overrides (which .mcp.json servers to enable)
.codex/
  AGENTS.md           # Codex global entry point referencing .claude/CLAUDE.md
  config.toml         # Codex defaults and existing preferences
.local/bin/codex-sudo-askpass # desktop password dialog used by sudo -A
.agents/AGENTS.md      # ~/.agents entry point referencing .claude/CLAUDE.md
.agents/skills/       # reusable skills and wrappers referencing .claude/skills
AGENTS.md             # agent-standard instructions referencing .claude/CLAUDE.md
.mcp.json             # project-level MCP server definitions
install.sh            # one-shot setup: installs prereqs, OpenCLI, Agent Reach, and stows
stow.sh               # symlink wrapper around GNU stow (called by install.sh)
```

### Shared design and native skills

The following skills are vendored under `.claude/skills/` for Claude Code, with
`.agents/skills/` wrappers for Codex and other Agent Skills clients:

- [UI/UX Pro Max](https://github.com/nextlevelbuilder/ui-ux-pro-max-skill): visual
  direction, design systems, and searchable UX and implementation guidance.
- [Callstack React Native Best Practices](https://github.com/callstackincubator/agent-skills/tree/main/skills/react-native-best-practices):
  native performance guidance for scrolling, animations, startup, and memory use.

Run `./stow.sh` to expose both entry points under your home directory. UI/UX Pro
Max's bundled search uses Python 3 and resolves its scripts and data through
`~/.claude/skills/ui-ux-pro-max/` for both clients.

## Install

### 1. Run the setup script

```bash
./install.sh
```

Works on Linux (apt / dnf / pacman), NixOS, and macOS (Homebrew). It will:

1. Install prerequisites if missing — `gh`, `stow`, `uv`, and `npm` — using Homebrew on macOS or the system package manager on Linux.
2. Install OpenCLI and Agent Reach if missing.
3. Run `stow.sh` to symlink the configs into `$HOME`.

After it finishes, open a new shell to pick up any newly installed commands.

#### On NixOS

`install.sh` installs nothing imperatively there — packages come from the system
flake. It detects NixOS and adapts:

| Step | Behaviour on NixOS |
|------|--------------------|
| Prerequisites | Not installed. Anything missing is collected and printed as a list of nixpkgs attributes to add to your config, then re-run. |
| OpenCLI | npm's prefix is the read-only nodejs store path, so the install redirects to `$HOME/.npm-global`. |

Packages to add to your NixOS / Home Manager config:

```nix
gh       # GitHub CLI for Agent Reach
nodejs   # OpenCLI
uv       # Agent Reach
stow
```

To allow npm global installs:

```nix
home.sessionVariables.NPM_CONFIG_PREFIX = "${config.home.homeDirectory}/.npm-global";
home.sessionPath = [ "${config.home.homeDirectory}/.npm-global/bin" ];
```

### 2. Install the Claude Code plugins

Inside a Claude Code session, install the plugins listed in `.claude/settings.json`:

**Official marketplace** (`claude-plugins-official`, ships with Claude Code):

```
/plugin install context7@claude-plugins-official
/plugin install commit-commands@claude-plugins-official
/plugin install figma@claude-plugins-official
/plugin install vercel@claude-plugins-official
/plugin install typescript-lsp@claude-plugins-official
/plugin install lua-lsp@claude-plugins-official
/plugin install csharp-lsp@claude-plugins-official
```

LSP plugins also need their language server installed on the host:

| Plugin | Server | Setup |
|--------|--------|-------|
| `typescript-lsp` | `typescript-language-server` | `npm i -g typescript typescript-language-server` |
| `lua-lsp` | `lua-language-server` | `pacman -S lua-language-server` (Arch) |
| `csharp-lsp` | [`csharp-ls`](https://github.com/razzmatazz/csharp-language-server) | `dotnet tool install --global csharp-ls` (needs .NET SDK 6+) |

**Third-party marketplaces** (add the marketplace before installing):

```
/plugin marketplace add mksglu/context-mode
/plugin install context-mode@context-mode
```

- [`context-mode`](https://github.com/mksglu/context-mode) — context-window optimizer (sandboxed tool output, FTS5 knowledge base, hook-based `curl`/`wget` blocking)

### 3. MCP server dependencies

The server in `.mcp.json` runs through `npx`, provided by the npm prerequisite:

| Server | Source | Setup |
|--------|--------|-------|
| `chrome-devtools` | `chrome-devtools-mcp` on npm | auto via `npx` |

### 4. Verify

Inside Claude Code:

```
/ctx doctor   # context-mode self-check
/mcp          # lists connected MCP servers
```

All servers should report `connected`; `ctx doctor` should be green across the board.

## Codex defaults

Stow installs `~/.codex/config.toml` and `~/.codex/AGENTS.md`. New Codex sessions
start with Vim mode enabled and full filesystem/network access without command
approval prompts. Existing model, reasoning, project-trust, and status-line
preferences are preserved in the configuration. The global `AGENTS.md` loads
the canonical Claude instructions, including the sudo authentication rule.

Commands requiring sudo use `sudo -A` with the executable
`~/.local/bin/codex-sudo-askpass` helper. It opens a hidden-entry password dialog
using YAD; YAD must be installed and a graphical desktop session must be
available. The password goes directly to sudo. Normal sudo credential caching
still applies.

Before stowing an existing installation, merge any host-specific Codex settings
you want to keep into `.codex/config.toml`. `stow.sh` backs up conflicting files
before linking the repository's versions. Restart Codex to load the new defaults.

### Share MCP servers with a project

Copy [`examples/project/.codex/config.toml`](examples/project/.codex/config.toml)
to your project's `.codex/config.toml` and commit it. Codex loads project MCP
configuration after each contributor trusts the project. Keep project MCP
definitions in this file and Claude Code definitions in `.mcp.json`.
See the [official Codex MCP documentation](https://developers.openai.com/codex/mcp).

The template configures Chrome DevTools, Git, GitHub, and Supabase using commands
on `PATH` and hosted endpoints. Contributors need Node.js/npm, `uv`/`uvx`,
Python 3, and `gh`. Git runs with the MCP Python SDK constrained below 2 because
the server still uses the 1.x API. GitHub reads each contributor's existing
GitHub CLI credential at connection time; no token is stored in the TOML file.
Authenticate once from the project directory:

```bash
gh auth login
codex mcp login supabase
```

Restart Codex and use `/mcp` to check the connections. Supabase remains configured
but requires authorization before its tools are available. The global Codex
configuration also includes these servers and preserves the existing Playwright
entry.

## Reusable application skills

- [`pwa-stack`](.agents/skills/pwa-stack/SKILL.md) creates the PWA application
  architecture and a health-checked `deploy.sh` workflow with isolated production
  and development Compose stacks. It offers optional Grafana telemetry through
  the independent observability skill.
- [`observability`](.agents/skills/observability/SKILL.md) instruments new or
  existing projects, including non-PWA applications. It discovers and reuses
  centralized Grafana, Prometheus, Loki, Tempo, and compatible collectors;
  creation of missing central infrastructure requires explicit confirmation.
- [`ticktick`](.agents/skills/ticktick/SKILL.md) manages tasks and reminders through
  the connected TickTick app plugin. Invoke `$ticktick` to view, add, update,
  reschedule, complete, or delete reminders. Stow exposes it globally at
  `~/.agents/skills/ticktick/`.
- [`hyprland-desktop`](.claude/skills/hyprland-desktop/SKILL.md) controls the local
  Hyprland/Quickshell desktop, captures screenshots, and opens previews in a
  specific existing Chrome window. It distinguishes the project terminal's
  workspace from current focus and the DevTools MCP browser from ordinary
  Chrome. Shared links expose it to Claude, Codex, and Agent Skills clients.

## Maintenance

Re-stow after pulling repo changes: `./stow.sh` (idempotent — uses `--restow`).

The stow step, invoked automatically by `install.sh`, installs the portable
entry point at `~/.agents/AGENTS.md` and skill wrappers under
`~/.agents/skills/`. The repository-root `AGENTS.md` supports project-local
discovery but is not stowed over an independently managed `~/AGENTS.md`. Tools
that implement these standards can therefore reuse the Claude instructions
without maintaining duplicate copies.
