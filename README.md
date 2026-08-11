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
.agents/AGENTS.md      # ~/.agents entry point referencing .claude/CLAUDE.md
.agents/skills/       # Agent Skills wrappers referencing .claude/skills
AGENTS.md             # agent-standard instructions referencing .claude/CLAUDE.md
.mcp.json             # project-level MCP server definitions
bin/                  # downloaded MCP server binaries (gitignored)
install.sh            # one-shot setup: prompts for tokens, installs prereqs, fetches binaries, stows
stow.sh               # symlink wrapper around GNU stow (called by install.sh)
```

## Install

### 1. Run the setup script

```bash
./install.sh
```

Works on Linux (apt / dnf / pacman), NixOS, and macOS (Homebrew). It will:

1. Prompt for your **GitHub PAT** (with the scopes listed below) and **Supabase access token** — both inputs are hidden, blank skips.
2. Persist them to your shell rc (`~/.bashrc`, `~/.zshrc`, or fish config) as `GITHUB_PERSONAL_ACCESS_TOKEN` and `SUPABASE_ACCESS_TOKEN`.
3. Install prerequisites if missing — `gh`, `stow`, and `uv` — using Homebrew on macOS or the system package manager on Linux.
4. Download the latest `github-mcp-server` release for your OS/arch into `bin/` (needs the `gh` CLI; supports Linux x86_64/arm64/i386 and macOS x86_64/arm64).
5. Set up the **git** MCP server by installing `mcp-server-git` via `uv tool install`.
6. Run `stow.sh` to symlink the configs into `$HOME`.

Token sources:

- **GitHub PAT** — create at <https://github.com/settings/tokens>. Scopes: `repo`, `read:org`, `read:user`, and `workflow` if you want Actions tools.
- **Supabase token** — create at <https://supabase.com/dashboard/account/tokens>.

After it finishes: open a new shell (or `source` the rc file shown by the script) so the env vars are picked up.

#### On NixOS

`install.sh` installs nothing imperatively there — packages come from the system
flake. It detects NixOS and adapts:

| Step | Behaviour on NixOS |
|------|--------------------|
| Prerequisites | Not installed. Anything missing is collected and printed as a list of nixpkgs attributes to add to your config, then re-run. |
| Token persistence | `~/.zshrc` is a read-only `/nix/store` symlink under Home Manager, so tokens go to `~/.zshrc.local` (which the zsh config sources) instead. |
| `github-mcp-server` | Unchanged — the upstream release is a static Go binary and runs on NixOS as-is. If a copy is already on `PATH` it is symlinked into `bin/` and the download is skipped. |
| `mcp-server-git` | Unchanged — `uv tool install` works on NixOS. `bin/mcp-server-git` is a shim over `uvx`, or a symlink if a `PATH` binary already exists. |
| OpenCLI | npm's prefix is the read-only nodejs store path, so the install redirects to `$HOME/.npm-global`. |

Packages to add to your NixOS / Home Manager config:

```nix
gh       # also performs the github-mcp-server release download
nodejs   # OpenCLI
uv       # mcp-server-git
stow
```

nixpkgs also carries `github-mcp-server` and `mcp-server-git`; adding them is
optional — `install.sh` will pick them up from `PATH` and skip fetching its own.

and, so `npm install -g` works at all:

```nix
home.sessionVariables.NPM_CONFIG_PREFIX = "${config.home.homeDirectory}/.npm-global";
home.sessionPath = [ "${config.home.homeDirectory}/.npm-global/bin" ];
```

> The MCP servers are launched by absolute path from `.mcp.json`, so the
> checkout must live at `~/repos/claude-config` (the script warns if it does
> not).

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

### 3. Install the remaining MCP server dependencies

`install.sh` handles `github` and `git`. The other servers in `.mcp.json` need their own backing binaries:

| Server | Source | Setup |
|--------|--------|-------|
| `chrome-devtools` | `chrome-devtools-mcp` on npm | auto via `npx` |
| `git` | `mcp-server-git` on PyPI | handled by `install.sh` (`uv tool install mcp-server-git`) |
| `supabase` | `@supabase/mcp-server-supabase` on npm | auto via `npx` (token from `install.sh`) |
| `github-intel` | local checkout of `mcp-server-github-intel` | clone to `~/repos/mcp-server-github-intel`, create `.venv`, install deps |

### 4. Verify

Inside Claude Code:

```
/ctx doctor   # context-mode self-check
/mcp          # lists connected MCP servers
```

All servers should report `connected`; `ctx doctor` should be green across the board.

## Maintenance

Upgrade `github-mcp-server` to the latest upstream release: just re-run `./install.sh` — it always fetches the latest release for your platform.

Re-stow after pulling repo changes: `./stow.sh` (idempotent — uses `--restow`).

The stow step, invoked automatically by `install.sh`, installs the portable
entry point at `~/.agents/AGENTS.md` and skill wrappers under
`~/.agents/skills/`. The repository-root `AGENTS.md` supports project-local
discovery but is not stowed over an independently managed `~/AGENTS.md`. Tools
that implement these standards can therefore reuse the Claude instructions
without maintaining duplicate copies.
