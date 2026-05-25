# CLAUDE.md

## Hard rules — check BEFORE answering

**Before stating any third-party SDK / API / CLI / library / cloud-service specifics** (method names, field names, webhook events, default behaviors, pricing tiers, regional coverage, version differences, config flags), call Context7 first — `resolve-library-id` then `query-docs`. Applies to **every** vendor regardless of how well-known: Plaid, Stripe, Supabase, AWS, GCP, Vercel, Next.js, React, Prisma, Django, Neovim, Hyprland, Waybar, etc. Do **not** rely on training data alone, even for libraries you "know." If Context7 has no coverage, say so explicitly and fall back to WebFetch on the vendor's official docs — never silently guess.

**Before recommending an architectural pattern** without in-repo precedent (integration approach, schema layout, event vs. polling, framework choice, service boundaries, deployment topology), call GitHub MCP `search_repositories` and look at 2–3 recently-pushed repos doing the same thing in the same language. Prefer their patterns over guessing. Skip only for routine syntax questions.

**In review / recommendation / "what should I do" / "what do you think" tasks**: before writing the response, mentally list the SDK/API claims and architectural calls you're about to make. Each one must be backed by Context7 or `search_repositories` — not memory. If you can't ground a claim, either ground it first or flag it as un-verified in the response. Advisory mode is exactly when this rule is easiest to skip and most important to follow.

## Context routing — MUST invoke skill BEFORE these operations

**Before any operation that could dump >20 lines into context**, invoke the `context-mode:context-mode` skill **first** and follow its routing guidance (`ctx_execute` / `ctx_execute_file` / `ctx_fetch_and_index`). This is non-negotiable, not "when relevant." Triggers:

- Shell commands with large output (`find`, `ls -R`, `git log`, `npm ls`, logs, build/test output, etc.)
- `WebFetch` of doc / article / HTML pages
- GitHub MCP `search_*`, `list_*`, `get_file_contents`, `get_commit`, `list_commits`
- `supabase get_logs`, `list_*`, `execute_sql` with broad selects
- Large `grep` / `Grep` results
- File analysis when *reading-to-understand* (not editing) — see the Read-tool hint about `ctx_execute_file`
- Log / JSON / CSV / large-blob parsing
- Any other MCP tool whose response is likely >20 lines

**Narrow exemption — do NOT generalize:** *only* `context7 query-docs` skips routing, because it returns distilled snippets by design. No other MCP server is exempt, including ones that "feel similar" (vendor doc fetchers, GitHub `search_code`, Supabase docs, etc.).

**Parallel-batch trap:** when issuing multiple tool calls in one message, audit *each call individually* against the trigger list. Bundling one exempt call (Context7) with non-exempt calls (GitHub `search_*`, `WebFetch`, etc.) does **not** extend the exemption to the batch — each non-exempt call still requires routing through `context-mode:context-mode`.

**Self-audit before any parallel tool batch:** explicitly state which calls in the batch are routed vs. exempt and why. If you can't justify an exemption out loud, route it.

If `context-mode:context-mode` is not in the available-skills list, the project does not have context-mode installed — use Bash / WebFetch / Grep directly.

## Slash commands

User-triggered context-mode commands (only present where context-mode is installed): `/ctx-stats`, `/ctx-doctor`, `/ctx-upgrade`, `/ctx-purge`, `/ctx-insight`, `/context-mode`.
