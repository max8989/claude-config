# claude-configs

Stow-managed Claude Code configuration: global instructions, settings, and MCP servers.

## Layout

```
.claude/
  CLAUDE.md           # global instructions (loaded for every session)
  settings.json       # theme, default permission mode, enabled plugins
  settings.local.json # per-host overrides (which .mcp.json servers to enable)
.mcp.json             # project-level MCP server definitions
vendor/               # git submodules (e.g. github-mcp-server source)
bin/                  # built binaries (gitignored)
install.sh            # one-shot setup: prompts for tokens, builds, stows
stow.sh               # symlink wrapper around GNU stow (called by install.sh)
```

## Install

### 1. Run the setup script

```bash
./install.sh
```

It will:

1. Prompt for your **GitHub PAT** (with the scopes listed below) and **Supabase access token** — both inputs are hidden, blank skips.
2. Persist them to your shell rc (`~/.bashrc`, `~/.zshrc`, or fish config) as `GITHUB_PERSONAL_ACCESS_TOKEN` and `SUPABASE_ACCESS_TOKEN`.
3. Initialize the `vendor/github-mcp-server` submodule and build `bin/github-mcp-server` (needs Go on PATH).
4. Run `stow.sh` to symlink the configs into `$HOME`.

Token sources:

- **GitHub PAT** — create at <https://github.com/settings/tokens>. Scopes: `repo`, `read:org`, `read:user`, and `workflow` if you want Actions tools.
- **Supabase token** — create at <https://supabase.com/dashboard/account/tokens>.

After it finishes: open a new shell (or `source` the rc file shown by the script) so the env vars are picked up.

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

`install.sh` handles `github`. The other servers in `.mcp.json` need their own backing binaries:

| Server | Source | Setup |
|--------|--------|-------|
| `chrome-devtools` | `chrome-devtools-mcp` on npm | auto via `npx` |
| `git` | `mcp-server-git` on PyPI | `pipx install uv` (provides `uvx`) |
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

Update the vendored `github-mcp-server`:

```bash
git submodule update --remote vendor/github-mcp-server
(cd vendor/github-mcp-server && go build -o ../../bin/github-mcp-server ./cmd/github-mcp-server)
```

Re-stow after pulling repo changes: `./stow.sh` (idempotent — uses `--restow`).
