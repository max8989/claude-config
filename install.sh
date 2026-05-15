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

# ---- build the github-mcp-server submodule ---------------------------------
echo
echo "==> Building vendored github-mcp-server"
if command -v go >/dev/null 2>&1; then
  git -C "$REPO_DIR" submodule update --init --recursive
  (cd "$REPO_DIR/vendor/github-mcp-server" \
    && go build -o "$REPO_DIR/bin/github-mcp-server" ./cmd/github-mcp-server)
  echo "    built $REPO_DIR/bin/github-mcp-server"
else
  echo "    SKIP: Go not on PATH — install Go and rerun, or build manually."
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
