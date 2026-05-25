---
name: context-mode-routing
description: Route to the context-mode MCP sandbox tools instead of running heavy operations directly. Use when the task involves shell commands with large output (>20 lines), web fetching, file analysis (not editing), large grep results, or anything that would otherwise dump a lot of text into the context window.
---

# context-mode routing

The `context-mode` plugin provides a sandboxed knowledge base (FTS5-indexed) and execution environment. Route work through it whenever the alternative is to flood the context window. The plugin already enforces some of these rules via its own hooks — the routing below covers what's left to your judgment.

## Hard blocks (enforced by the plugin)

These commands are intercepted and rejected by the plugin's `PreToolUse` hooks. Don't retry them; pick the sandbox equivalent immediately.

| Blocked pattern | Use instead |
|-----------------|-------------|
| `curl`, `wget` in shell | `context-mode_ctx_fetch_and_index(url, source)` then `context-mode_ctx_search(queries)` |
| `fetch('http`, `requests.get(`, `requests.post(`, `http.get(`, `http.request(` in shell | `context-mode_ctx_execute(language, code)` — runs in sandbox, only stdout enters context |
| Direct URL fetching tools (`WebFetch`, etc.) | `context-mode_ctx_fetch_and_index` + `ctx_search`, OR `ctx_execute` with `fetch(...)` |

If a hook denies a call, do **not** retry the same call — pick the sandbox equivalent.

## Soft routing (your judgment)

### Shell commands
Shell is fine for short-output commands: `git`, `mkdir`, `rm`, `mv`, `cd`, `ls`, `npm install`, `pip install`, etc. For anything that may print >20 lines:

- `context-mode_ctx_batch_execute(commands, queries)` — run multiple commands plus a search in one call. Primary tool; one call replaces 30+ individual ones.
- `context-mode_ctx_execute(language: "shell", code: "...")` — single command in sandbox, only stdout enters context.

### File reads
- Reading to **edit** → use the normal `Read` tool (Edit needs the content in context).
- Reading to **analyze, explore, summarize** → `context-mode_ctx_execute_file(path, language, code)`. Only your printed summary enters context.

### grep / search
Large search results flood context. Use `context-mode_ctx_execute(language: "shell", code: "grep ...")` and print only what matters.

## Tool selection hierarchy

1. **GATHER**: `context-mode_ctx_batch_execute(commands, queries)` — run all commands, auto-index output, return search results in one call.
2. **FOLLOW-UP**: `context-mode_ctx_search(queries: ["q1", "q2", ...])` — query indexed content; pass all questions as one array.
3. **PROCESSING**: `context-mode_ctx_execute(language, code)` or `context-mode_ctx_execute_file(path, language, code)` — sandbox execution, only stdout enters context.
4. **WEB**: `context-mode_ctx_fetch_and_index(url, source)` then `context-mode_ctx_search(queries)` — fetch, chunk, index, query. Raw HTML never enters context.
5. **INDEX**: `context-mode_ctx_index(content, source)` — store content in the FTS5 knowledge base for later search.

## Output discipline (when this skill is active)

- Write artifacts (code, configs, PRDs) to **files**, not inline text. Return only: file path + one-line description.
- When indexing content, use descriptive `source` labels so future calls can `search(source: "label")`.
