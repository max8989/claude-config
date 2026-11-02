# Agent instructions

The canonical instructions for this configuration live in
[`~/.claude/CLAUDE.md`](../.claude/CLAUDE.md).

Before doing any work, read that file completely and follow it as if its
contents appeared here. Relative paths in those instructions are resolved from
`~/.claude/`.

## UI work

Follow the canonical **UI work — test with Chrome DevTools MCP** rule for
every UI change. Test the running UI using Chrome DevTools MCP; when
available, invoke `agent-skills:browser-testing-with-devtools` from the
installed `agent-skills` plugin to run that workflow. Ask the user to enter
existing-account credentials directly in the browser, or create a test
account yourself when needed and registration is available. Resume testing
after any login or verification step.
