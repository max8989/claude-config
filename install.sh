#!/usr/bin/env bash
# One-shot setup: installs prerequisites (gh, stow, uv, npm), OpenCLI, and
# Agent Reach, then stows configs into $HOME.
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

# ---- NixOS: nothing is installed imperatively ------------------------------
# On NixOS there is no package manager to shell out to — packages come from the
# system flake. So instead of installing, we collect what's missing and print a
# ready-to-paste list at the end. MISSING_NIX holds "cmd -> nixpkgs attribute".
IS_NIXOS=0
if [[ -e /etc/NIXOS ]] || command -v nixos-rebuild >/dev/null 2>&1; then
  IS_NIXOS=1
fi
MISSING_NIX=()

note_missing_nix() {
  MISSING_NIX+=("$1")
  echo "    $2 not found — add '$1' to your NixOS/Home Manager package list."
}

# ---- install a missing command via the platform package manager -----------
# usage: ensure_cmd <cmd> <brew> <apt> <dnf> <pacman> [nix-attr]
ensure_cmd() {
  local cmd="$1" brew_pkg="$2" apt_pkg="$3" dnf_pkg="$4" pac_pkg="$5" nix_pkg="${6:-$1}"
  command -v "$cmd" >/dev/null 2>&1 && return 0

  if (( IS_NIXOS )); then
    note_missing_nix "$nix_pkg" "$cmd"
    return 0
  fi

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

# ---- ensure uv/uvx (installs Agent Reach) ----------------------------------
ensure_uv() {
  command -v uvx >/dev/null 2>&1 && return 0

  if (( IS_NIXOS )); then
    note_missing_nix uv uv
    return 0
  fi

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

# ---- install prerequisites -------------------------------------------------
echo
echo "==> Installing prerequisites"
ensure_cmd stow stow stow stow stow stow
ensure_uv
ensure_cmd npm node npm npm npm nodejs
ensure_cmd gh gh gh gh github-cli gh

# ---- npm global prefix -----------------------------------------------------
# nixpkgs' npm points its prefix at its own (read-only) store path, so a global
# install fails with EACCES. Redirect to a writable prefix for this run; the
# NixOS config makes the same setting permanent via NPM_CONFIG_PREFIX.
if command -v npm >/dev/null 2>&1; then
  npm_prefix="$(npm config get prefix 2>/dev/null || echo '')"
  if [[ "$npm_prefix" == /nix/store/* ]]; then
    export NPM_CONFIG_PREFIX="$HOME/.npm-global"
    export PATH="$NPM_CONFIG_PREFIX/bin:$PATH"
    mkdir -p "$NPM_CONFIG_PREFIX/bin"
    echo "    npm prefix was read-only ($npm_prefix) — using $NPM_CONFIG_PREFIX"
  fi
fi

# ---- install OpenCLI (browser-session backend for Agent Reach) -------------
echo
echo "==> Installing OpenCLI"
if command -v opencli >/dev/null 2>&1; then
  echo "    OpenCLI already installed ($(opencli --version 2>/dev/null | head -1 || echo 'version unknown'))"
else
  npm install -g @jackwener/opencli
  hash -r
  if ! command -v opencli >/dev/null 2>&1; then
    echo "    ERROR: OpenCLI installed but is not on PATH." >&2
    echo "    Add npm's global bin directory to PATH, then rerun install.sh." >&2
    exit 1
  fi
  echo "    OpenCLI installed ($(opencli --version 2>/dev/null | head -1 || echo 'ok'))"
fi

# ---- install Agent Reach (router the agent-reach skill drives) --------------
echo
echo "==> Installing Agent Reach"
if command -v agent-reach >/dev/null 2>&1; then
  echo "    Agent Reach already installed ($(agent-reach --version 2>/dev/null | head -1 || echo 'version unknown'))"
elif command -v uv >/dev/null 2>&1; then
  uv tool install --quiet https://github.com/Panniantong/agent-reach/archive/main.zip
  echo "    Agent Reach installed to ~/.local/bin (home.sessionPath must include it)"
else
  echo "    SKIP: uv not available — the agent-reach skill will have no CLI backend."
fi

# ---- stow Claude and agent-standard configs --------------------------------
echo
echo "==> Stowing Claude and agent-standard configs into \$HOME"
"$REPO_DIR/stow.sh"

# ---- done ------------------------------------------------------------------
echo
if (( ${#MISSING_NIX[@]} )); then
  echo "==> Missing packages (NixOS installs nothing imperatively)"
  echo "    Add these to home.packages / environment.systemPackages, rebuild,"
  echo "    then re-run install.sh:"
  echo
  printf '      %s\n' "${MISSING_NIX[@]}"
  echo
fi
echo "Setup complete."
echo "Open a new shell to pick up any newly installed commands."
echo "For Reddit access, open Chrome, log in to reddit.com, and keep Chrome running."
echo "Then verify with: opencli reddit search \"local LLM\" -f yaml"
echo "Agent Reach status: agent-reach doctor --json"
echo "Then inside Claude Code, install the plugins listed in README.md (step 2)."
