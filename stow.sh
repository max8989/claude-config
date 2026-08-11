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
# Keep the repository's root AGENTS.md for project-local discovery, but do not
# replace an independently managed ~/AGENTS.md. The portable global entry point
# and skills are installed below ~/.agents instead.
#
# `bin/` holds the MCP server binaries that .mcp.json launches by absolute path
# inside the repo — they are never meant to land in ~/bin.
IGNORE_REGEX='(^AGENTS\.md$|^bin(/|$)|(^|/)(stow\.sh|install\.sh|README\.md|\.git|\.gitignore)$)'

run_stow() {
  stow --dir="$STOW_DIR" --target="$TARGET" --ignore="$IGNORE_REGEX" "$@" "$PKG"
}

# A real file where stow wants to put a symlink aborts the whole run — and a
# fresh machine reliably has some (Claude writes its own ~/.claude/settings.json
# on first launch). Move those aside rather than failing or, worse, adopting
# them into the repo. Symlinks are left alone: stow re-points its own.
backup_conflicts() {
  local stamp src rel target
  stamp="$(date +%Y%m%d-%H%M%S)"
  while IFS= read -r src; do
    rel="${src#"$REPO_DIR"/}"
    [[ "$rel" =~ $IGNORE_REGEX ]] && continue
    target="$TARGET/$rel"
    [[ -e "$target" && ! -L "$target" && ! -d "$target" ]] || continue
    mv "$target" "$target.pre-stow-$stamp"
    echo "  moved existing $target -> $target.pre-stow-$stamp"
  done < <(find "$REPO_DIR" -type f -not -path "$REPO_DIR/.git/*")
}

ACTION="${1:-stow}"
case "$ACTION" in
  stow)     backup_conflicts; run_stow --restow ;;
  unstow)   run_stow --delete ;;
  adopt)    run_stow --adopt && run_stow --restow ;;
  simulate) run_stow --simulate --verbose --restow ;;
  *)
    echo "usage: $0 [stow|unstow|adopt|simulate]" >&2
    exit 2
    ;;
esac

echo "done: $ACTION (package=$PKG target=$TARGET)"
