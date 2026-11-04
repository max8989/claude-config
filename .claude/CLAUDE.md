# CLAUDE.md

## Sudo authentication

When an authorized command requires sudo, use `sudo -A` so the configured
askpass helper opens a desktop password dialog. The user enters their password
directly in that dialog. Never request passwords in chat, put them in tool
arguments, or store or log them. Normal sudo credential caching still applies.

## UI work — test with Chrome DevTools MCP

For every UI change, use **Chrome DevTools MCP** to test the running UI in
a real browser before considering the work complete. Exercise the changed
flows, check the relevant viewport sizes, and inspect console errors and
failed network requests.

If the `agent-skills` plugin from `addyosmani/agent-skills` is installed and its
`browser-testing-with-devtools` skill is available (Codex plugin
`agent-skills@agent-skills`; skill
`agent-skills:browser-testing-with-devtools`), invoke that skill and follow
its Chrome DevTools MCP workflow.

Authentication is part of UI verification; do not skip testing because a
page requires login. For an existing account, ask the user to enter their
username and password directly in the browser, then continue testing after
sign-in. Never ask for the user's password in chat or copy it into tool
arguments, files, or logs. If a new account is needed and registration is
available, create a test account yourself and continue. If registration or
sign-in requires a user-only step such as email verification or MFA, ask
the user to complete that step and resume testing afterward.

## Hard rules — check BEFORE answering

**Before stating any third-party SDK / API / CLI / library / cloud-service specifics** (method names, field names, webhook events, default behaviors, pricing tiers, regional coverage, version differences, config flags), call Context7 first — `resolve-library-id` then `query-docs`. Applies to **every** vendor regardless of how well-known: Plaid, Stripe, Supabase, AWS, GCP, Vercel, Next.js, React, Prisma, Django, Neovim, Hyprland, Waybar, etc. Do **not** rely on training data alone, even for libraries you "know." If Context7 has no coverage, say so explicitly and fall back to WebFetch on the vendor's official docs — never silently guess.

**Before recommending an architectural pattern** without in-repo precedent (integration approach, schema layout, event vs. polling, framework choice, service boundaries, deployment topology), use the available read-only research tools to look at 2–3 recently-pushed repos doing the same thing in the same language. Prefer their patterns over guessing. Skip only for routine syntax questions.

**In review / recommendation / "what should I do" / "what do you think" tasks**: before writing the response, mentally list the SDK/API claims and architectural calls you're about to make. Each one must be backed by Context7 or researched repository examples — not memory. If you can't ground a claim, either ground it first or flag it as un-verified in the response. Advisory mode is exactly when this rule is easiest to skip and most important to follow.

## Context routing — MUST invoke skill BEFORE these operations

**Before any operation that could dump >20 lines into context**, invoke the `context-mode:context-mode` skill **first** and follow its routing guidance (`ctx_execute` / `ctx_execute_file` / `ctx_fetch_and_index`), except for the narrow exemptions below. This is non-negotiable, not "when relevant." Triggers:

- Shell commands with large output (`find`, `ls -R`, `git log`, `npm ls`, logs, build/test output, etc.)
- `WebFetch` of doc / article / HTML pages
- Large `grep` / `Grep` results
- File analysis when *reading-to-understand* (not editing) — see the Read-tool hint about `ctx_execute_file`
- Log / JSON / CSV / large-blob parsing
- Any other MCP tool whose response is likely >20 lines

**Narrow exemptions — do NOT generalize:**
- `context7 query-docs` skips routing because it returns distilled snippets by design. No other MCP server is exempt, including ones that "feel similar" (vendor doc fetchers, repository searches, etc.).
- Global agent instructions and installed skill instructions outside the current workspace (for example, `~/.claude/CLAUDE.md`, `~/.codex/plugins/cache/.../skills/.../SKILL.md`, and referenced skill instructions) use the normal host file reader, or a shell reader scoped to the specific instruction file. Read required instructions completely. `ctx_execute_file` confines reads to the workspace and rejects these paths. Do not retry a blocked read through `ctx_execute` or add broad filesystem allow rules; this exception is for instruction files, not arbitrary files outside the workspace.

**Parallel-batch trap:** when issuing multiple tool calls in one message, audit *each call individually* against the trigger list. Bundling one exempt call (Context7) with non-exempt calls (repository searches, `WebFetch`, etc.) does **not** extend the exemption to the batch — each non-exempt call still requires routing through `context-mode:context-mode`.

**Self-audit before any parallel tool batch:** explicitly state which calls in the batch are routed vs. exempt and why. If you can't justify an exemption out loud, route it.

If `context-mode:context-mode` is not in the available-skills list, the project does not have context-mode installed — use Bash / WebFetch / Grep directly.

## Internet research — use the agent-reach skill

**Before any internet research or platform lookup**, invoke the `agent-reach` skill first. Triggers: "research X", "search the web for X", "look this up", "see what people say about X", or any mention of / URL from Twitter/X, Reddit, Facebook, Instagram, YouTube, GitHub, Bilibili, XiaoHongShu, Xiaoyuzhou Podcast, LinkedIn, V2EX, Xueqiu, or RSS feeds. Run `agent-reach doctor` to check installed channels and tools; it prints JSON by default.

**Not** for writing reports/analysis/translation (it only fetches content), write operations (posting/commenting/liking), or platforms covered by a dedicated skill (prefer that skill). If `agent-reach` is not in the available-skills list, it isn't installed on that machine — fall back to normal web tools (still routed through context-mode per the rules above).

## Slash commands

User-triggered context-mode commands (only present where context-mode is installed): `/ctx-stats`, `/ctx-doctor`, `/ctx-upgrade`, `/ctx-purge`, `/ctx-insight`, `/context-mode`.
