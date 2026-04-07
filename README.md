# Claude Code Configuration

Personal [Claude Code CLI](https://docs.anthropic.com/en/docs/claude-code) global configuration.

## What's Included

| File | Purpose |
|------|---------|
| `CLAUDE.md` | Global instructions loaded in every Claude Code session |
| `settings.json` | Plugin and feature toggles |

## How It Works

- **`CLAUDE.md`** — Global rules (MCP tool routing, context-mode rules, output constraints). Applied to *every* project.
- **`AGENTS.md`** — Project-specific instructions live in each repo's root. Claude Code auto-loads them.

## Installation

See the [ai-coding-configs](https://github.com/max8989/ai-coding-configs) repo for the full setup guide and install script.

### Quick Manual Setup

```bash
# Back up existing config
cp -r ~/.claude ~/.claude.bak 2>/dev/null

# Symlink this repo
ln -sf "$(pwd)/CLAUDE.md" ~/.claude/CLAUDE.md
ln -sf "$(pwd)/settings.json" ~/.claude/settings.json
```
