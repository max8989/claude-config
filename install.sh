#!/usr/bin/env bash
# One-shot setup: prompts for tokens, persists them to your shell rc,
# installs prerequisites (gh, stow, uv), downloads the github-mcp-server
# binary, sets up the git MCP server, and stows configs into $HOME.
#
# Cross-platform: Linux (apt / dnf / pacman) and macOS (Homebrew).
# Re-running is safe — existing entries are updated, not duplicated.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OS="$(uname -s)"

# ---- on macOS, surface Homebrew even if it's not yet on PATH ---------------
if [[ "$OS" == "Darwin" ]] && ! command -v brew >/dev/null 2>&1; then
  for b in /opt/homebrew/bin/brew /usr/local/bin/brew; do
    [[ -x "$b" ]] && eval "$("$b" shellenv)" && break
  done
fi
HAS_BREW=0
command -v brew >/dev/null 2>&1 && HAS_BREW=1

# ---- portable in-place sed (GNU takes no arg, BSD/macOS needs '') ----------
sed_inplace() {
  if sed --version >/dev/null 2>&1; then
    sed -i "$@"               # GNU sed
  else
    local expr="$1"; shift
    sed -i '' "$expr" "$@"    # BSD / macOS sed
  fi
}

# ---- install a missing command via the platform package manager -----------
# usage: ensure_cmd <cmd> <brew> <apt> <dnf> <pacman>
ensure_cmd() {
  local cmd="$1" brew_pkg="$2" apt_pkg="$3" dnf_pkg="$4" pac_pkg="$5"
  command -v "$cmd" >/dev/null 2>&1 && return 0

  echo "    $cmd not found — installing..."
  if (( HAS_BREW )); then
    brew install "$brew_pkg"
  elif command -v apt-get >/dev/null 2>&1; then
    sudo apt-get update -y && sudo apt-get install -y "$apt_pkg"
  elif command -v dnf >/dev/null 2>&1; then
    sudo dnf install -y "$dnf_pkg"
  elif command -v pacman >/dev/null 2>&1; then
    sudo pacman -S --needed --noconfirm "$pac_pkg"
  else
    echo "    ERROR: no supported package manager found — install '$cmd' manually and rerun." >&2
    return 1
  fi
}

# ---- ensure uv/uvx (backs the git MCP server) ------------------------------
ensure_uv() {
  command -v uvx >/dev/null 2>&1 && return 0

  echo "    uv not found — installing..."
  if (( HAS_BREW )); then
    brew install uv
  elif command -v pacman >/dev/null 2>&1; then
    sudo pacman -S --needed --noconfirm uv
  else
    # apt/dnf have no uv package — use the official standalone installer
    curl -LsSf https://astral.sh/uv/install.sh | sh
  fi
  # uv installs into ~/.local/bin; make it visible for the rest of this run
  command -v uvx >/dev/null 2>&1 || export PATH="$HOME/.local/bin:$PATH"
}

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
echo "    Leave blank to skip the github MCP server entirely."
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
      sed_inplace "s|^set -gx $name .*|$line|" "$RC"
    else
      printf '\n%s\n' "$line" >> "$RC"
    fi
  else
    line="export $name=\"$value\""
    if grep -q "^export $name=" "$RC"; then
      # use a separator unlikely to appear in tokens
      sed_inplace "s|^export $name=.*|$line|" "$RC"
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

# ---- is a GitHub PAT available? --------------------------------------------
# The github MCP server is only set up when a PAT exists: freshly entered,
# already exported in the environment, or already persisted to the rc file.
# With no PAT anywhere, the github MCP install (gh + binary) is skipped.
HAVE_GH_PAT=0
if [[ -n "$GITHUB_PAT" || -n "${GITHUB_PERSONAL_ACCESS_TOKEN:-}" ]]; then
  HAVE_GH_PAT=1
elif (( IS_FISH )) && grep -q "^set -gx GITHUB_PERSONAL_ACCESS_TOKEN " "$RC"; then
  HAVE_GH_PAT=1
elif grep -q "^export GITHUB_PERSONAL_ACCESS_TOKEN=" "$RC"; then
  HAVE_GH_PAT=1
fi

# ---- install prerequisites -------------------------------------------------
echo
echo "==> Installing prerequisites"
ensure_cmd stow stow stow stow stow
ensure_uv
if (( HAVE_GH_PAT )); then
  ensure_cmd gh gh gh gh github-cli
fi

# ---- download the latest github-mcp-server release -------------------------
echo
if (( ! HAVE_GH_PAT )); then
  echo "==> Skipping github MCP server (no GitHub PAT entered or saved)"
  echo "    Re-run install.sh with a PAT to enable it."
else
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
fi

# ---- set up the git MCP server (mcp-server-git, run via uvx) ----------------
echo
echo "==> Setting up the git MCP server"
if command -v uv >/dev/null 2>&1; then
  # install it persistently so the first `uvx mcp-server-git` launch is instant
  uv tool install --quiet mcp-server-git
  echo "    mcp-server-git ready (launched as 'uvx mcp-server-git')"
else
  echo "    SKIP: uv unavailable — install uv, then it will be fetched on first use."
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
