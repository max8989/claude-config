#!/usr/bin/env bash
# One-shot setup: prompts for tokens, persists them to your shell rc,
# builds the vendored github-mcp-server, and stows configs into $HOME.
#
# Re-running is safe — existing entries are updated, not duplicated.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ---- detect the shell rc file to write env vars into -----------------------
detect_rc() {
  case "${SHELL##*/}" in
    zsh)  echo "$HOME/.zshrc" ;;
    fish) echo "$HOME/.config/fish/config.fish" ;;
    *)    echo "$HOME/.bashrc" ;;
  esac
}
RC="$(detect_rc)"
IS_FISH=0
[[ "$RC" == *fish/config.fish ]] && IS_FISH=1
mkdir -p "$(dirname "$RC")"
touch "$RC"

# ---- token prompts ---------------------------------------------------------
echo
echo "==> GitHub Personal Access Token"
echo "    Create one at: https://github.com/settings/tokens (classic)"
echo "    Or fine-grained: https://github.com/settings/personal-access-tokens"
echo "    Scopes needed by the github MCP server:"
echo "      • repo            (full control of private repos)"
echo "      • read:org        (read org/team membership)"
echo "      • read:user       (read profile info)"
echo "      • workflow        (only if you'll trigger/inspect Actions)"
read -rsp "    Paste token (hidden, blank = skip): " GITHUB_PAT
echo

echo
echo "==> Supabase Access Token"
echo "    Create one at: https://supabase.com/dashboard/account/tokens"
read -rsp "    Paste token (hidden, blank = skip): " SUPABASE_TOKEN
echo

# ---- write tokens to shell rc (idempotent) ---------------------------------
write_var() {
  local name="$1" value="$2"
  [[ -z "$value" ]] && { echo "    skipped $name (blank)"; return; }

  local line
  if (( IS_FISH )); then
    line="set -gx $name $value"
    if grep -q "^set -gx $name " "$RC"; then
      sed -i "s|^set -gx $name .*|$line|" "$RC"
    else
      printf '\n%s\n' "$line" >> "$RC"
    fi
  else
    line="export $name=\"$value\""
    if grep -q "^export $name=" "$RC"; then
      # use a separator unlikely to appear in tokens
      sed -i "s|^export $name=.*|$line|" "$RC"
    else
      printf '\n%s\n' "$line" >> "$RC"
    fi
  fi
  echo "    wrote $name to $RC"
}

echo
echo "==> Persisting env vars to $RC"
write_var GITHUB_PERSONAL_ACCESS_TOKEN "$GITHUB_PAT"
write_var SUPABASE_ACCESS_TOKEN "$SUPABASE_TOKEN"

# ---- download the latest github-mcp-server release -------------------------
echo
echo "==> Downloading github-mcp-server release binary"

uname_s="$(uname -s)" uname_m="$(uname -m)"
case "$uname_s-$uname_m" in
  Linux-x86_64)        asset="Linux_x86_64.tar.gz"   ;;
  Linux-aarch64|Linux-arm64) asset="Linux_arm64.tar.gz" ;;
  Linux-i?86)          asset="Linux_i386.tar.gz"     ;;
  Darwin-x86_64)       asset="Darwin_x86_64.tar.gz"  ;;
  Darwin-arm64)        asset="Darwin_arm64.tar.gz"   ;;
  *)
    echo "    SKIP: no prebuilt release for $uname_s/$uname_m — fetch manually from"
    echo "          https://github.com/github/github-mcp-server/releases/latest"
    asset=""
    ;;
esac

if [[ -n "$asset" ]]; then
  if ! command -v gh >/dev/null 2>&1; then
    echo "    ERROR: gh CLI required for the release download. Install gh and rerun."
    exit 1
  fi
  mkdir -p "$REPO_DIR/bin"
  tmpdir="$(mktemp -d)"
  trap 'rm -rf "$tmpdir"' EXIT
  gh release download --repo github/github-mcp-server \
    --pattern "*${asset}" --dir "$tmpdir" --clobber
  tar -xz -C "$tmpdir" -f "$tmpdir"/*"${asset}"
  install -m 0755 "$tmpdir/github-mcp-server" "$REPO_DIR/bin/github-mcp-server"
  echo "    installed $REPO_DIR/bin/github-mcp-server ($("$REPO_DIR/bin/github-mcp-server" --version 2>/dev/null | head -1 || echo 'ok'))"
fi

# ---- stow ------------------------------------------------------------------
echo
echo "==> Stowing configs into \$HOME"
"$REPO_DIR/stow.sh"

# ---- done ------------------------------------------------------------------
echo
echo "Setup complete."
echo "Open a new shell, or run:  source \"$RC\""
echo "Then inside Claude Code, install the plugins listed in README.md (step 2)."
