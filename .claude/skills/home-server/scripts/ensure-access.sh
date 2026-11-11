#!/usr/bin/env bash
# Check the existing SSH route before activating the home-server VPN.
set -euo pipefail

readonly server='maxime@192.168.2.42'
readonly vpn='maxime-server-nix'

if (( $# )); then
  printf 'Usage: %s\n' "$0" >&2
  exit 2
fi
if ! command -v ssh >/dev/null 2>&1; then
  printf 'SSH is not installed; no network settings were changed.\n' >&2
  exit 1
fi

probe_output=''
probe() {
  if probe_output="$(LC_ALL=C ssh -o BatchMode=yes -o ConnectTimeout=8 \
    -o ConnectionAttempts=1 -o StrictHostKeyChecking=yes "$server" hostname 2>&1)"; then
    return 0
  else
    return "$?"
  fi
}

if probe; then
  printf 'SSH ready: %s via the existing route. VPN left unchanged.\n' "$server"
  exit 0
else
  probe_status=$?
fi

# Login/trust failures do not mean the user is away from home.
case "$probe_output" in
  *'Permission denied'*|*'Host key verification failed'*|*'REMOTE HOST IDENTIFICATION HAS CHANGED'*|*'Too many authentication failures'*)
    printf 'SSH authentication or host-key check failed; VPN left unchanged.\n%s\n' "$probe_output" >&2
    exit "$probe_status"
    ;;
esac
case "$probe_output" in
  *'Connection timed out'*|*'Operation timed out'*|*'No route to host'*|*'Network is unreachable'*|*'Connection refused'*) ;;
  *)
    printf 'SSH probe failed without a recognized network error; VPN left unchanged.\n%s\n' "$probe_output" >&2
    exit "$probe_status"
    ;;
esac

if ! command -v nmcli >/dev/null 2>&1; then
  printf 'SSH is unreachable and NetworkManager nmcli is unavailable.\n' >&2
  exit 1
fi
if active_profiles="$(nmcli -t -f NAME connection show --active 2>&1)"; then
  :
else
  printf 'Could not check active VPN profiles.\n%s\n' "$active_profiles" >&2
  exit 1
fi
if printf '%s\n' "$active_profiles" | grep -Fxq -- "$vpn"; then
  printf 'VPN %s is already active; leaving it connected and retrying SSH once.\n' "$vpn"
else
  printf 'SSH is unreachable; connecting VPN %s.\n' "$vpn"
  if nmcli --wait 30 connection up id "$vpn"; then
    :
  else
    printf 'VPN activation failed; no further SSH attempts.\n' >&2
    exit 1
  fi
fi

if probe; then
  printf 'SSH ready: %s after checking VPN %s.\n' "$server" "$vpn"
else
  probe_status=$?
  printf 'SSH is still unavailable after the VPN check; stopping.\n%s\n' "$probe_output" >&2
  exit "$probe_status"
fi
