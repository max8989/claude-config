# Put the preview in the intended Chrome window

## Existing window

Take a fresh helper `snapshot`. Resolve the requested project/workspace and
then a Chrome address there. Do not use the first Chrome in `clients`, a
shared title, or a shared browser PID to distinguish multiple windows.
If one Chrome on the chosen workspace fits the task, use it. If several fit,
an already established target or the user must disambiguate them.

```bash
python3 "$desktop_helper" open-tab "$target_address" 'http://localhost:5173/'
python3 "$desktop_helper" screenshot --window "$target_address"
```

Inspect the screenshot's address bar and page. A browser connected to this
same instance can also read the page URL. A title change alone does not prove
the URL when pages share titles. On a slow load, observe again; do not open
another tab to retry navigation that may already have succeeded.

The helper deliberately uses focused `wtype` input. At inspection time Chrome
reported `xwayland: true`; background `sendshortcut` targeting has a documented
XWayland delivery caveat in the Hypruse implementation. Do not send keys to an
unfocused XWayland window assuming they are isolated from the active window.

Launching `google-chrome URL`, `xdg-open URL`, or selecting a workspace first
does not itself identify an existing Chrome window. A browser may hand the URL
to its already running process. Hyprland workspace rules place windows; they
do not select browser tabs inside an existing window.

## When there is no suitable window

If the task calls for a visible preview on the project workspace and no Chrome
window is there, create a new window, identify it from before/after client
snapshots and its preview URL/title, then move **that new address** if needed:

```bash
google-chrome --new-window 'http://localhost:5173/'
```

Use the Lua dispatcher shown in the desktop guide to move it to the requested
workspace. Verify the address, workspace, and rendered page. If concurrent
window creation makes the new address ambiguous, inspect rather than moving
an arbitrary Chrome. Leave the user's existing Chrome windows in place unless
their request includes moving them.

## Chrome DevTools MCP is a separate connection

At inspection time both `~/.codex/config.toml` and the claude-config repository's
`.mcp.json` passed `--isolated` to Chrome DevTools MCP. That flag uses a temporary
user-data directory. Its tabs therefore belong to the tool's browser, not the
user's ordinary Chrome session. Recheck configuration rather than assuming
this observation remains true after setup changes.

For page testing, use DevTools MCP as configured. When visible placement of
its browser matters, correlate the window created by the tool with fresh
Hyprland state, then position that specific window. A DevTools page ID is not
a Hyprland address. Do not navigate an unrelated user tab to establish a mapping.

Opening the preview with the desktop helper does not attach DevTools MCP to
that tab. If the user asks for browser tools to control their ordinary Chrome,
the official MCP configuration supports `--autoConnect` for Chrome 144+ after
remote debugging is enabled through `chrome://inspect/#remote-debugging`, or
`--browserUrl` for an already debuggable local browser. Check the current
[configuration guide](https://github.com/ChromeDevTools/chrome-devtools-mcp/blob/main/docs/configuration.md)
before changing setup. Creating this skill is not a request to restart the
user's browser or change its debugging/profile configuration.

For temporary validation, create identifiable scratch windows and close only
those windows after checking the result. Restore the previous focus only if
the desktop is still on a test window; a user focus change takes precedence.
