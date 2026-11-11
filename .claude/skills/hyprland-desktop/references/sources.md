# Research and local evidence

Checked 2026-11-06. Context7 supplied Hyprland, Quickshell, and Omarchy material;
primary source and installed command help supplied the remaining input and
browser-connection details. These are references, not dependencies to install.

- [Hyprland dispatcher documentation](https://github.com/hyprwm/hyprland-wiki/blob/main/content/configuring/core/dispatchers.md): Lua focus, cursor, and window operations. The helper's `hl.dispatch(...)` calls were checked against the installed compositor.
- [Hyprland hyprctl documentation](https://github.com/hyprwm/hyprland-wiki/blob/main/content/configuring/core/advanced-configuration/using-hyprctl.md): runtime JSON queries and command discovery.
- [Quickshell IpcHandler](https://quickshell.org/docs/v0.3.1/types/Quickshell.Io/IpcHandler/): inspect handlers with `ipc show`, then call their registered methods. Local `quickshell ipc --config desktop show` is authoritative for this shell's targets.
- [Omarchy's AI manual](https://omarchy.org/manual/ai/#the-omarchy-skill): ships desktop knowledge as a skill exposed to multiple agent clients.
- [Omarchy capture skill](https://github.com/omacom/omarchy/blob/14abc0762ce38547d1912061969df58962f6f10a/default/agents/skills/omarchy/capture.md): distinguishes interactive capture from direct-to-file capture. Local NixOS capture helpers are adapted from an earlier Omarchy snapshot and have their own command names.
- [Omarchy browser launcher](https://github.com/omacom/omarchy/blob/14abc0762ce38547d1912061969df58962f6f10a/bin/omarchy-launch-browser) and [browser handoff](https://github.com/omacom/omarchy/blob/14abc0762ce38547d1912061969df58962f6f10a/bin/omarchy-cmd-browser-handoff): launching a URL may use the running browser process. Its app-focus helper does not establish an exact browser-window identity for every multi-window case.
- [Hypruse](https://github.com/IlyasKhallouki/hypruse), latest inspected commit 2026-10-19: Python implementation combines semantic Hyprland state, grim screenshots, wtype, and native Wayland pointer events. Its background-input discussion documents the XWayland `sendshortcut` caveat and screenshot coordinate requirements.
- [Agent Desktops](https://github.com/DevNvll/agent-desktops), latest inspected commit 2026-08-13: Python tooling and a skill for isolated workspaces/headless outputs. That architecture is useful for separate agent desktops but adds a compositor plugin; this skill instead operates the existing desktop requested by the user.
- [hyprland-mcp](https://github.com/alderban107/hyprland-mcp), latest inspected commit 2026-03-02: another Python example wrapping native screenshot/input/window tools. No external MCP server is needed for the local shell workflow.
- [wtype manual](https://github.com/atx/wtype/blob/master/man/wtype.1): stdin text, XKB key names, modifier press/release, and per-event pauses.
- [wlrctl upstream](https://git.sr.ht/~brocellous/wlrctl): the installed Nix package's upstream-authored man page documents click/move/scroll. Version 0.2.2 was used transiently for validation.
- [Chrome DevTools MCP configuration](https://github.com/ChromeDevTools/chrome-devtools-mcp/blob/main/docs/configuration.md): temporary profiles with `--isolated`, and explicit connection options for existing Chrome.

Local evidence: the desktop repository's `CLAUDE.md`, capture-tool definitions,
the deployed screenshot wrapper, agent browser-tool configuration, live
`hyprctl -j` state, and live Quickshell IPC introspection. Re-read these when
the desktop changes; do not freeze monitor layouts, addresses, process IDs,
Nix store paths, or browser connection assumptions in future tasks.
