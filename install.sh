#!/usr/bin/env bash
# One-shot setup: prompts for tokens, persists them to your shell rc,
# installs prerequisites (gh, stow, uv, OpenCLI), downloads the github-mcp-server
# binary, sets up the git MCP server, and stows configs into $HOME.
#
# Cross-platform: Linux (apt / dnf / pacman) and macOS (Homebrew).
# Re-running is safe — existing entries are updated, not duplicated.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OS="$(uname -s)"

# .mcp.json launches the github/git servers by absolute path, so the checkout
# has to live where that file expects it.
EXPECTED_DIR="$HOME/repos/claude-config"
if [[ "$REPO_DIR" != "$EXPECTED_DIR" ]]; then
  echo "WARNING: this checkout is at $REPO_DIR but .mcp.json launches its MCP"
  echo "         servers from $EXPECTED_DIR. Move the repo there, or update the"
  echo "         'command' paths in .mcp.json, or those servers will not start."
  echo
fi

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

# ---- ensure uv/uvx (backs the git MCP server) ------------------------------
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

# ---- detect the shell rc file to write env vars into -----------------------
# Under Home Manager the rc file is a symlink into /nix/store and is read-only,
# so writing tokens into it fails. Those configs source a sibling ".local" file
# for exactly this kind of machine-local secret — redirect there instead.
detect_rc() {
  local rc
  case "${SHELL##*/}" in
    zsh)  rc="$HOME/.zshrc" ;;
    fish) rc="$HOME/.config/fish/config.fish" ;;
    *)    rc="$HOME/.bashrc" ;;
  esac

  if [[ -L "$rc" && "$(readlink -f "$rc")" == /nix/store/* ]]; then
    echo "$rc.local"
  else
    echo "$rc"
  fi
}
RC="$(detect_rc)"
RC_IS_LOCAL=0
[[ "$RC" == *.local ]] && RC_IS_LOCAL=1
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
if (( RC_IS_LOCAL )); then
  echo "    (your real rc file is a read-only /nix/store symlink; using the"
  echo "     machine-local override instead — make sure your shell config"
  echo "     sources it. The zsh config in nixos-dotfiles sources ~/.zshrc.local.)"
fi
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
ensure_cmd stow stow stow stow stow stow
ensure_uv
ensure_cmd npm node npm npm npm nodejs
if (( HAVE_GH_PAT )); then
  ensure_cmd gh gh gh gh github-cli gh
fi

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

# ---- download the latest github-mcp-server release -------------------------
echo
if (( ! HAVE_GH_PAT )); then
  echo "==> Skipping github MCP server (no GitHub PAT entered or saved)"
  echo "    Re-run install.sh with a PAT to enable it."
elif command -v github-mcp-server >/dev/null 2>&1; then
  # Already provided by the system (packaged, or installed by hand). Link it
  # into bin/ so .mcp.json keeps pointing at one stable path on every platform,
  # and skip re-downloading a copy we already have.
  echo "==> Using the system github-mcp-server (skipping release download)"
  mkdir -p "$REPO_DIR/bin"
  ln -sfn "$(command -v github-mcp-server)" "$REPO_DIR/bin/github-mcp-server"
  echo "    linked $REPO_DIR/bin/github-mcp-server -> $(command -v github-mcp-server)"
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

# ---- set up the git MCP server ---------------------------------------------
# .mcp.json launches bin/mcp-server-git, so every platform has one stable path.
# That entry is either a link to a system-provided binary or a shim over uvx.
echo
echo "==> Setting up the git MCP server"
mkdir -p "$REPO_DIR/bin"
if command -v mcp-server-git >/dev/null 2>&1; then
  # Provided by the system (packaged, or installed by hand) — prefer it over
  # having uv fetch a second copy plus its own CPython.
  ln -sfn "$(command -v mcp-server-git)" "$REPO_DIR/bin/mcp-server-git"
  echo "    linked $REPO_DIR/bin/mcp-server-git -> $(command -v mcp-server-git)"
elif command -v uv >/dev/null 2>&1; then
  # install it persistently so the first launch is instant
  uv tool install --quiet mcp-server-git
  rm -f "$REPO_DIR/bin/mcp-server-git"
  cat > "$REPO_DIR/bin/mcp-server-git" <<'SHIM'
#!/usr/bin/env bash
exec uvx mcp-server-git "$@"
SHIM
  chmod 0755 "$REPO_DIR/bin/mcp-server-git"
  echo "    mcp-server-git ready (bin/mcp-server-git shims 'uvx mcp-server-git')"
else
  echo "    SKIP: neither mcp-server-git nor uv is available — the git MCP server"
  echo "          will not start until one of them is installed."
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
echo "Open a new shell, or run:  source \"$RC\""
echo "For Reddit access, open Chrome, log in to reddit.com, and keep Chrome running."
echo "Then verify with: opencli reddit search \"local LLM\" -f yaml"
echo "Agent Reach status: agent-reach doctor --json"
echo "Then inside Claude Code, install the plugins listed in README.md (step 2)."
