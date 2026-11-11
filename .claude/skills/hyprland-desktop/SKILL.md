---
name: hyprland-desktop
description: >-
  Inspect and control the local Hyprland/Wayland desktop with Quickshell:
  screenshots, windows and workspaces, mouse and keyboard input, and web-dev
  tabs in a specific existing Chrome window. Use for desktop interaction or
  opening/placing a visible development browser; use browser tools directly for DOM-only work.
---

# Hyprland Desktop

Work in the user's existing desktop session. Use Hyprland's live window data
for targeting, screenshots for visual decisions, and Quickshell's existing IPC
for shell actions. This machine runs NixOS; Omarchy is a reference, not its OS.

## Establish the target

```bash
desktop_helper="$HOME/.claude/skills/hyprland-desktop/scripts/desktop.py"
python3 "$desktop_helper" snapshot
```

The snapshot contains `caller` (the terminal found through process ancestry),
`active`, monitors, cursor, and windows. For “open my preview here”, prefer the
project terminal's workspace over whichever workspace happens to have focus.
An explicit user target takes precedence. If `caller` is null, establish the
workspace from task context or a focused question instead of guessing.

Choose a **live window address**, using workspace, class, and task context.
Two Chrome windows can have identical titles and share a Hyprland group.
Browser tabs, compositor group members, and workspaces are distinct objects.
Addresses are temporary: refresh after windows close or the session restarts.
If multiple windows still fit the request, ask one focused target question.

## Act and observe

Read [the local desktop guide](references/desktop.md) for screenshot mapping,
pointer input, Quickshell IPC, and window arrangement. For browser placement,
read [the Chrome guide](references/chrome.md) before creating a tab or window.

With `target_address` set from the fresh snapshot:

```bash
python3 "$desktop_helper" focus "$target_address"
python3 "$desktop_helper" screenshot --window "$target_address"
python3 "$desktop_helper" key "$target_address" Return
```

Capture returns a private PNG path and coordinate metadata. Open the PNG with
the host's image-viewing tool before deciding where to click. The `type`
command takes literal text on stdin; `key`, `type`, `click`, and `scroll`
require that the selected window already has focus.

For the common web-dev case:

```bash
python3 "$desktop_helper" open-tab "$target_address" 'http://localhost:5173/'
```

This focuses that exact Chrome window, creates a tab through its keyboard
shortcut, and enters the URL. It does not launch another browser instance.
The result means **input was sent**; verify the requested URL in that window
with a screenshot or a browser tool connected to that instance.

Use the task's existing authorization. If focus changes, the session locks,
or an action has an uncertain result, stop the sequence and inspect. Do not
blindly retry a tab creation, click, or submission. Foreground input shares
the user's seat; focus checks reduce races but cannot make input atomic.
Explicit focus is appropriate when starting a requested action on a named
window. A mid-sequence focus change requires understanding the new state
before resuming; do not automatically refocus against the user's activity.

Use direct browser tools for DOM, accessibility, and web tests when connected
to the intended browser. Confirm the connection before assuming their page
IDs refer to windows on this desktop. Keep captures in the private runtime
directory unless the user requests saved artifacts.

## Maintenance

The helper uses Python's standard library, `hyprctl`, `wtype`, and `grim`.
Clicks/scrolls additionally need `wlrctl`; the desktop guide gives a transient
Nix invocation. No MCP server, input daemon, or compositor plugin is required.
Tool and configuration details were checked on 2026-11-06; re-inspect live
state and command help when they differ. See [research sources](references/sources.md)
for official Hyprland, Quickshell, Omarchy, and community implementations.

Offline regression checks (no desktop input):

```bash
python3 -B -m unittest discover -s "$HOME/.claude/skills/hyprland-desktop/scripts" -p 'test_desktop.py'
```
