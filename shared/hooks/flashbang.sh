#!/usr/bin/env bash
set -euo pipefail

# Linux equivalent of flashbang.ps1. The visual overlay is implemented with
# Python's standard tkinter module because Bash itself cannot create windows.
# No third-party Python package is required.

if ! command -v python3 >/dev/null 2>&1; then
  command -v notify-send >/dev/null 2>&1 && notify-send 'AI assistant requires attention'
  exit 0
fi

exec python3 - "$@" <<'PY'
import argparse
import re
import shutil
import subprocess
import sys


def notify_fallback() -> None:
    notify_send = shutil.which("notify-send")
    if notify_send:
        subprocess.run([notify_send, "AI assistant requires attention"], check=False)


try:
    import tkinter as tk
except ImportError:
    notify_fallback()
    sys.exit(0)


def monitor_bounds(primary_only: bool) -> tuple[int, int, int, int]:
    root = tk.Tk()
    root.withdraw()
    width = root.winfo_screenwidth()
    height = root.winfo_screenheight()
    root.destroy()

    if primary_only or not shutil.which("xrandr"):
        return 0, 0, width, height

    try:
        output = subprocess.run(
            ["xrandr", "--current"],
            check=True,
            capture_output=True,
            text=True,
        ).stdout
    except (OSError, subprocess.SubprocessError):
        return 0, 0, width, height

    monitors = [
        (int(w), int(h), int(x), int(y))
        for w, h, x, y in re.findall(r"(\d+)x(\d+)\+(-?\d+)\+(-?\d+)", output)
    ]
    if not monitors:
        return 0, 0, width, height

    left = min(x for _, _, x, _ in monitors)
    top = min(y for _, _, _, y in monitors)
    right = max(x + w for w, _, x, _ in monitors)
    bottom = max(y + h for _, h, _, y in monitors)
    return left, top, right - left, bottom - top


def main() -> int:
    parser = argparse.ArgumentParser(add_help=False)
    parser.add_argument("--hold-ms", type=int, default=250)
    parser.add_argument("--fade-ms", type=int, default=250)
    parser.add_argument("--color", default="white")
    parser.add_argument("--max-opacity", type=float, default=0.35)
    parser.add_argument("--primary-screen-only", action="store_true")
    args, _ = parser.parse_known_args()

    args.hold_ms = max(0, min(5000, args.hold_ms))
    args.fade_ms = max(0, min(5000, args.fade_ms))
    args.max_opacity = max(0.05, min(1.0, args.max_opacity))

    try:
        left, top, width, height = monitor_bounds(args.primary_screen_only)
        root = tk.Tk()
        root.overrideredirect(True)
        root.attributes("-topmost", True)
        root.attributes("-alpha", args.max_opacity)
        root.configure(background=args.color)
        root.geometry(f"{width}x{height}{left:+d}{top:+d}")
        root.withdraw()
        root.deiconify()
        root.lift()
        root.update()

        def finish() -> None:
            root.destroy()

        def fade(start_ms: int = 0) -> None:
            if args.fade_ms == 0:
                finish()
                return
            progress = min(1.0, start_ms / args.fade_ms)
            root.attributes("-alpha", args.max_opacity * (1.0 - progress))
            if progress >= 1.0:
                finish()
            else:
                root.after(8, fade, start_ms + 8)

        root.after(args.hold_ms, fade)
        root.mainloop()
        return 0
    except (tk.TclError, RuntimeError, OSError, ValueError):
        # Headless sessions and minimal installations may not provide a usable
        # display or tkinter. Keep the hook non-blocking and informative.
        notify_fallback()
        return 0


if __name__ == "__main__":
    sys.exit(main())
PY
