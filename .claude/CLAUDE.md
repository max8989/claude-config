# CLAUDE.md

## MCP defaults

- **Context7** — for any library/framework/SDK/CLI docs (Neovim, Lazy.nvim, Hyprland, Waybar, Next.js, etc.). Call `resolve-library-id` then `query-docs`. Do not rely on training data alone.
- **GitHub MCP — `search_repositories`** — for non-trivial architectural decisions (layout, abstraction, integration pattern) when there's no in-repo precedent and no Context7 coverage. Find 2–3 recently-pushed repos in the same language and prefer their patterns over guessing. Skip for routine syntax questions.

## Skills (load when relevant)

- Shell with >20-line output, web fetching, file analysis (not editing), or large grep results → use the `context-mode-routing` skill.

## Slash commands

- `/ctx-stats`, `/ctx-doctor`, `/ctx-upgrade` — context-mode MCP wrappers.
