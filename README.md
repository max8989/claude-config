# claude-configs

Stow-managed Claude Code configuration: global instructions, settings, and MCP servers.

## Layout

```
.claude/
  CLAUDE.md           # global instructions (loaded for every session)
  settings.json       # theme, default permission mode, enabled plugins
  settings.local.json # per-host overrides (which .mcp.json servers to enable)
.mcp.json             # project-level MCP server definitions
stow.sh               # symlink wrapper around GNU stow
```

## Install

### 1. Stow the configs into `~`

```bash
./stow.sh           # symlink everything into ~
./stow.sh simulate  # dry-run, prints what would happen
./stow.sh adopt     # absorb existing ~ files into the repo, then symlink
./stow.sh unstow    # remove the symlinks
```

If stow reports conflicts on first run, either back up the conflicting files in `~` or use `adopt` (then review the diff before committing).

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

### 3. Install the MCP server dependencies

The servers in `.mcp.json` need their backing binaries on the host:

| Server | Source | Setup |
|--------|--------|-------|
| `chrome-devtools` | `chrome-devtools-mcp` on npm | auto via `npx` |
| `git` | `mcp-server-git` on PyPI | `pipx install uv` (provides `uvx`) |
| `supabase` | `@supabase/mcp-server-supabase` on npm | auto via `npx`; needs `SUPABASE_ACCESS_TOKEN` in env |
| `github` | [github/github-mcp-server](https://github.com/github/github-mcp-server) binary | download release to `~/.local/bin/github-mcp-server` |
| `github-intel` | local checkout of `mcp-server-github-intel` | clone to `~/repos/mcp-server-github-intel`, create `.venv`, install deps |

### 4. Set environment variables

Add to your shell rc:

- `SUPABASE_ACCESS_TOKEN` — required by the `supabase` MCP server.

### 5. Verify

Inside Claude Code:

```
/ctx doctor   # context-mode self-check
/mcp          # lists connected MCP servers
```

All servers should report `connected`; `ctx doctor` should be green across the board.
