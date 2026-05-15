#!/usr/bin/env bash
# Symlink this repo's files into $HOME using GNU stow.
#
# Usage:
#   ./stow.sh            # stow (restow, idempotent)
#   ./stow.sh unstow     # remove the symlinks
#   ./stow.sh adopt      # pull existing files in $HOME into this repo, then stow
#   ./stow.sh simulate   # dry-run: print what would happen

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STOW_DIR="$(dirname "$REPO_DIR")"
PKG="$(basename "$REPO_DIR")"
TARGET="${HOME}"

if ! command -v stow >/dev/null 2>&1; then
  echo "error: GNU stow is not installed. Install it and retry (e.g. pacman -S stow)." >&2
  exit 1
fi

# Files at the repo root that are tooling/meta, not configs to stow into $HOME.
IGNORE_REGEX='(^|/)(stow\.sh|README\.md|\.git|\.gitignore)$'

run_stow() {
  stow --dir="$STOW_DIR" --target="$TARGET" --ignore="$IGNORE_REGEX" "$@" "$PKG"
}

ACTION="${1:-stow}"
case "$ACTION" in
  stow)     run_stow --restow ;;
  unstow)   run_stow --delete ;;
  adopt)    run_stow --adopt && run_stow --restow ;;
  simulate) run_stow --simulate --verbose --restow ;;
  *)
    echo "usage: $0 [stow|unstow|adopt|simulate]" >&2
    exit 2
    ;;
esac

echo "done: $ACTION (package=$PKG target=$TARGET)"
