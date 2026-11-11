# Local desktop operations

## Session and configuration

Run in the logged-in user's Wayland session. Relevant inherited variables are
`HYPRLAND_INSTANCE_SIGNATURE`, `WAYLAND_DISPLAY`, and `XDG_RUNTIME_DIR`.
If they are absent in a remote shell, inspect `hyprctl instances -j` and the
user session's environment to identify the intended session; do not guess a
socket, start a second compositor, or connect as root.

The inspected host ran Hyprland 0.57.0 and Quickshell 0.3.1. Monitor names,
positions, scales, window groups, and focus change during ordinary use.
Use fresh state, including on external monitors with negative coordinates.

Desktop source configuration lives in `~/repos/nixos-dotfiles/`, especially
`home/files/hypr/`, `home/quickshell.nix`, and `home/capture-tools.nix`.
Hyprland uses Lua. Quickshell's deployed bundle is immutable in the Nix store;
its user state lives under XDG state/runtime directories. Runtime control does
not require changing these files. For requested configuration changes, read
that repository's instructions and edit its declarative sources.

## Screenshots and coordinates

```bash
python3 "$desktop_helper" screenshot                       # Focused monitor
python3 "$desktop_helper" screenshot --monitor eDP-1       # Use a live output name
python3 "$desktop_helper" screenshot --window "$target_address"
```

The window option requires that address already be focused. It crops visible
screen pixels; it does not retrieve a hidden window's buffer. Bars, menus, or
other overlays can still cover the window: inspect the image.

Each capture produces `capture.png` and `capture.json` in a unique private
runtime directory. JSON contains the image dimensions, global logical
rectangle, and the conversion from screenshot pixels to desktop coordinates:

```text
global_x = pixel_to_global.origin[0] + image_x * logical_units_per_pixel[0]
global_y = pixel_to_global.origin[1] + image_y * logical_units_per_pixel[1]
```

Use coordinates from the original image dimensions, adjusting if the viewer
resized the displayed image. Round the final global coordinates to integers.
Re-capture after scrolling, resizing, switching group members, moving windows,
or changing monitors. Never reuse another screenshot's scale or origin.

`grim` was installed inside the packaged `nixos-screenshot` helper's private
PATH, although absent from the interactive PATH. The Python helper locates
that executable by reading the wrapper's declared PATH; it does not evaluate
the wrapper or hard-code Nix store hashes.

The existing capture command also works without a picker or clipboard change:

```bash
nixos-screenshot fullscreen save
```

It saves the focused monitor and prints the saved path. Bare
`nixos-screenshot` starts an interactive selection flow; use it only when
human selection is intended. Recording/OCR already have packaged helpers;
inspect their current usage in `home/capture-tools.nix` before invoking them.

## Native keyboard and pointer

Set `target_address` from the live snapshot, then explicitly focus it:

```bash
python3 "$desktop_helper" focus "$target_address"
python3 "$desktop_helper" key "$target_address" l --mods ctrl
printf '%s' 'literal text, including Unicode' | python3 "$desktop_helper" type "$target_address"
python3 "$desktop_helper" key "$target_address" Return
```

The text comes through stdin, so shell metacharacters are not interpreted.
Use proper shell quoting for literal content. Keys use XKB names such as
`Return`, `Escape`, `BackSpace`, and `Tab`. Modifiers use wtype names such as
`ctrl`, `shift`, `alt`, and `logo`. For compositor actions prefer direct
Hyprland dispatchers over simulating global shortcuts.

Clicks and scrolls need `wlrctl`. If it is not on PATH, run the action in a
transient Nix shell; this does not change system/Home Manager configuration:

```bash
nix shell nixpkgs#wlrctl --command python3 "$desktop_helper" click "$target_address" "$desktop_x" "$desktop_y"
nix shell nixpkgs#wlrctl --command python3 "$desktop_helper" scroll "$target_address" "$desktop_x" "$desktop_y" 120
```

`desktop_x` and `desktop_y` must come from the image mapping. Pointer commands
reject points outside the selected window, move via Hyprland's global logical
coordinates, then inject a Wayland click/scroll. Check the screenshot for
overlays and the result afterward. They do not implement dragging. Prefer
compositor window-move/resize actions for window arrangement.

## Window arrangement

The helper handles focus. For other requested compositor actions, current Lua
dispatcher examples are:

```lua
-- Pass to hyprctl eval as one properly quoted argument.
hl.dispatch(hl.dsp.focus({ workspace = "3" }))
hl.dispatch(hl.dsp.window.move({ window = "address:0x...", workspace = "3", follow = false }))
hl.dispatch(hl.dsp.window.close({ window = "address:0x..." }))
```

Replace the workspace/address from live state. A workspace's display name can
differ from its identity: prefer its explicit identity from the snapshot.
Verify the resulting window data. Moving a grouped member may affect its
group, so inspect `grouped` before moving an existing user window.

## Quickshell IPC

Select the existing `desktop` configuration explicitly. The default config
is not the running desktop, and starting a second instance duplicates shell
ownership. Discover the actual handlers before a call:

```bash
quickshell ipc --config desktop show
quickshell ipc --config desktop call menus current
quickshell ipc --config desktop call auth isActive
quickshell ipc --config desktop call session isSecure
```

At inspection time handlers included `menus`, `switcher`, `notifications`,
`audio`, `media`, `display`, `bar`, `network`, `theme`, `auth`, and `session`.
Examples for a requested shell action, after confirming they remain listed:

```bash
quickshell ipc --config desktop call menus toggle controls
quickshell ipc --config desktop call menus close
```

Never lock the user's desktop as a test. There is no production unlock IPC;
authentication stays in the user's PAM/Quickshell flow. Helpers refuse captures
and input while the session is locked.
