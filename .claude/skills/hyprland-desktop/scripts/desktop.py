#!/usr/bin/env python3
"""Small, explicit Hyprland operations using the current user's Wayland session."""

import argparse
import json
import os
from pathlib import Path
import re
import shutil
import struct
import subprocess
import sys
import tempfile
import time
from urllib.parse import urlsplit


class DesktopError(RuntimeError):
    pass


def command(argv, *, input=None):
    result = subprocess.run(argv, input=input, capture_output=True, text=True, timeout=15)
    if result.returncode:
        raise DesktopError(f"{Path(argv[0]).name}: {result.stderr.strip()[:600] or 'command failed'}")
    return result.stdout


def query(name):
    return json.loads(command(["hyprctl", "-j", name]))


def lock_state():
    state = query("locked")
    return state.get("locked") if isinstance(state, dict) else state


def unlocked():
    if lock_state() is not False:
        raise DesktopError("Session is locked or lock state is unknown; no input or capture allowed.")


def window(address):
    if not re.fullmatch(r"0x[0-9a-fA-F]+", address):
        raise DesktopError("Use a live window address from snapshot, such as 0xabc.")
    matches = [w for w in query("clients") if w.get("address") == address]
    if len(matches) != 1 or not matches[0].get("mapped", False):
        raise DesktopError("Window no longer exists or is not mapped; take a new snapshot.")
    return matches[0]


def focused(address):
    unlocked()
    active = query("activewindow")
    if active.get("address") != address or active.get("acceptsInput") is False:
        raise DesktopError("Target lost keyboard focus; stopped. Inspect before continuing.")
    return active


def dispatch(expression):
    reply = command(["hyprctl", "eval", f"hl.dispatch({expression})"]).strip()
    if reply != "ok":
        raise DesktopError(f"Hyprland rejected the operation: {reply[:500]}")


def focus(address):
    window(address)
    unlocked()
    dispatch(f'hl.dsp.focus({{ window = "address:{address}" }})')
    deadline = time.monotonic() + 1.5
    while query("activewindow").get("address") != address:
        if time.monotonic() > deadline:
            raise DesktopError("Focus did not reach the target; no keyboard input sent.")
        time.sleep(0.03)
    return focused(address)


def key(address, name, modifiers=""):
    mods = modifiers.split(",") if modifiers else []
    if any(m not in {"shift", "ctrl", "logo", "win", "alt", "altgr", "capslock"} for m in mods):
        raise DesktopError("Unsupported wtype modifier.")
    if not re.fullmatch(r"[A-Za-z0-9_]+", name):
        raise DesktopError("Use an XKB key name such as Return, Escape, or t.")
    args = ["wtype"]
    for mod in mods:
        args.extend(["-M", mod])
    args.extend(["-k", name])
    for mod in reversed(mods):
        args.extend(["-m", mod])
    focused(address)
    command(args)
    focused(address)


def type_text(address, text):
    focused(address)
    command(["wtype", "-"], input=text)
    focused(address)


def open_tab(address, url):
    parsed = urlsplit(url)
    if (any(c.isspace() or ord(c) < 32 or ord(c) == 127 for c in url)
            or not ((parsed.scheme in {"http", "https"} and parsed.netloc)
                    or url == "about:blank")):
        raise DesktopError("Supply an http(s) URL or about:blank without whitespace/control characters.")
    target = window(address)
    if not any(s in target.get("class", "").lower() for s in ("chrome", "chromium")):
        raise DesktopError("open-tab expects a Chrome/Chromium window, not another application.")
    focus(address)
    key(address, "t", "ctrl")
    # Let Chrome process Ctrl+T before typing; success still requires observation.
    time.sleep(0.2)
    type_text(address, url)
    key(address, "Return")
    return {"address": address, "status": "input-sent", "verified_url": False,
            "next": "Inspect this window's screenshot or connected browser page URL; do not retry blindly."}


def pointer(address, x, y, action, values):
    target = focused(address)
    left, top = target["at"]
    width, height = target["size"]
    if not (left <= x < left + width and top <= y < top + height):
        raise DesktopError("Point is outside the target window's logical rectangle.")
    if not shutil.which("wlrctl"):
        raise DesktopError("wlrctl is absent. Rerun this command inside: nix shell nixpkgs#wlrctl")
    dispatch(f"hl.dsp.cursor.move({{ x = {x}, y = {y} }})")
    focused(address)
    command(["wlrctl", "pointer", action, *map(str, values)])
    focused(address)
    return {"address": address, "status": "input-sent"}


def ancestor_pids():
    pid = os.getpid()
    result = []
    while pid > 1 and pid not in result:
        result.append(pid)
        try:
            status = Path(f"/proc/{pid}/status").read_text()
            pid = int(next(l.split(":", 1)[1] for l in status.splitlines() if l.startswith("PPid:")))
        except (OSError, StopIteration, ValueError):
            break
    return result


def caller_window(clients):
    for pid in ancestor_pids():
        matches = [w for w in clients if w.get("pid") == pid]
        if matches:
            return matches[0] if len(matches) == 1 else None
    return None


def monitor_geometry(monitor):
    width, height = monitor["width"], monitor["height"]
    if monitor.get("transform", 0) % 2:
        width, height = height, width
    scale = monitor.get("scale", 1)
    return [monitor["x"], monitor["y"], width / scale, height / scale]


def grim_path():
    if found := shutil.which("grim"):
        return found
    # Nix's packaged capture helper has grim in its private PATH, not the user's.
    if wrapper := shutil.which("nixos-screenshot"):
        try:
            match = re.search(r'^export PATH="([^"]+)"', Path(wrapper).read_text(), re.M)
            for directory in match.group(1).split(":") if match else []:
                candidate = Path(directory) / "grim"
                if candidate.is_file() and os.access(candidate, os.X_OK):
                    return str(candidate)
        except (OSError, UnicodeError):
            pass
    raise DesktopError("grim is absent. Use the packaged nixos-screenshot helper or nix shell nixpkgs#grim.")


def snapshot():
    clients = query("clients")
    fields = ("address", "class", "initialClass", "title", "pid", "workspace", "monitor",
              "at", "size", "mapped", "hidden", "visible", "xwayland", "grouped", "focusHistoryID")

    def compact(w):
        return {k: w[k] for k in fields if k in w} if w else None

    return {
        "hyprland_version": query("version").get("version"),
        "locked": lock_state(),
        "caller": compact(caller_window(clients)),
        "active": compact(query("activewindow")),
        "monitors": [{k: m[k] for k in ("id", "name", "width", "height", "x", "y", "scale",
                     "transform", "focused", "activeWorkspace") if k in m} for m in query("monitors")],
        "cursor": query("cursorpos"),
        "windows": [compact(w) for w in clients],
    }


def screenshot(address=None, monitor_name=None):
    unlocked()
    args = [grim_path(), "-s", "1"]
    if address:
        target = focused(address)
        geometry = [*target["at"], *target["size"]]
        args.extend(["-g", f"{geometry[0]},{geometry[1]} {geometry[2]}x{geometry[3]}"])
    else:
        monitors = [m for m in query("monitors")
                    if m.get("name") == monitor_name] if monitor_name else [
                        m for m in query("monitors") if m.get("focused")]
        if len(monitors) != 1:
            raise DesktopError("Select one live monitor by name from snapshot.")
        monitor = monitors[0]
        monitor_name = monitor["name"]
        geometry = monitor_geometry(monitor)
        args.extend(["-o", monitor_name])
    directory = Path(tempfile.mkdtemp(prefix="hyprland-desktop-", dir=os.environ.get("XDG_RUNTIME_DIR")))
    image = directory / "capture.png"
    command([*args, str(image)])
    image.chmod(0o600)
    with image.open("rb") as png:
        header = png.read(24)
    if len(header) < 24 or header[:8] != b"\x89PNG\r\n\x1a\n":
        raise DesktopError("Capture did not produce a valid PNG.")
    width, height = struct.unpack(">II", header[16:24])
    if not width or not height:
        raise DesktopError("Capture has invalid dimensions.")
    if address:
        after = focused(address)
        if [*after["at"], *after["size"]] != geometry:
            raise DesktopError("Window moved during capture; take another screenshot before acting.")
    else:
        after = [m for m in query("monitors") if m.get("name") == monitor_name]
        if len(after) != 1 or monitor_geometry(after[0]) != geometry:
            raise DesktopError("Monitor moved during capture; take another screenshot before acting.")
    unlocked()
    metadata = {
        "path": str(image), "metadata_path": str(directory / "capture.json"),
        "captured_at": time.time(), "source": "visible-screen-crop" if address else "monitor",
        "window": address, "monitor": monitor_name, "logical_geometry": geometry,
        "image_dimensions": [width, height],
        "pixel_to_global": {"origin": geometry[:2],
                            "logical_units_per_pixel": [geometry[2] / width, geometry[3] / height]},
    }
    metadata_file = Path(metadata["metadata_path"])
    metadata_file.write_text(json.dumps(metadata) + "\n")
    metadata_file.chmod(0o600)
    return metadata


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    actions = parser.add_subparsers(dest="action", required=True)
    actions.add_parser("snapshot", help="Live windows, monitors, cursor, and the invoking terminal")
    capture = actions.add_parser("screenshot", help="Private PNG and pixel-to-desktop mapping")
    target = capture.add_mutually_exclusive_group()
    target.add_argument("--window", help="Address of an already focused window; captures visible screen pixels")
    target.add_argument("--monitor", help="Output name; defaults to the currently focused monitor")
    commands = {}
    for name in ("focus", "key", "type", "open-tab", "click", "scroll"):
        commands[name] = actions.add_parser(name)
        commands[name].add_argument("address", help="Live Hyprland window address from snapshot")
    commands["key"].add_argument("key", help="XKB key name, e.g. Return")
    commands["key"].add_argument("--mods", default="", help="Comma-separated wtype modifiers, e.g. ctrl,shift")
    commands["open-tab"].add_argument("url")
    for name in ("click", "scroll"):
        commands[name].add_argument("x", type=int, help="Global logical X coordinate")
        commands[name].add_argument("y", type=int, help="Global logical Y coordinate")
    commands["click"].add_argument("--button", choices=("left", "right", "middle"), default="left")
    commands["scroll"].add_argument("dy", type=int, help="Vertical scroll; negative scrolls up")
    commands["scroll"].add_argument("--dx", type=int, default=0)
    args = parser.parse_args()
    if args.action == "snapshot":
        result = snapshot()
    elif args.action == "screenshot":
        result = screenshot(args.window, args.monitor)
    elif args.action == "focus":
        result = focus(args.address)
    elif args.action == "open-tab":
        result = open_tab(args.address, args.url)
    elif args.action in {"click", "scroll"}:
        values = [args.button] if args.action == "click" else [args.dy, args.dx]
        result = pointer(args.address, args.x, args.y, args.action, values)
    else:
        if args.action == "key":
            key(args.address, args.key, args.mods)
        else:
            type_text(args.address, sys.stdin.read())
        result = {"address": args.address, "status": "input-sent"}
    print(json.dumps(result, ensure_ascii=False, separators=(",", ":")))


if __name__ == "__main__":
    os.umask(0o077)
    try:
        main()
    except (DesktopError, OSError, ValueError, subprocess.TimeoutExpired) as error:
        print(f"desktop: {error}", file=sys.stderr)
        sys.exit(1)
