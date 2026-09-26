#!/usr/bin/env bash
# Usage: ./deploy.sh [prod|dev] (default: prod). See README for server setup.
set -Eeuo pipefail

# Parse the whole function before git pull can replace this script on disk.
main() {
  cd "$(dirname "${BASH_SOURCE[0]}")"
  local target expected_branch env_file branch
  if (( $# > 1 )); then
    echo "Usage: $0 [prod|dev]" >&2
    exit 1
  fi
  case "${1:-prod}" in
    prod) target=prod; expected_branch=${DEPLOY_BRANCH:-main}; env_file=.env ;;
    dev) target=dev; expected_branch=${DEPLOY_BRANCH:-dev}; env_file=.env.dev ;;
    *) echo "Usage: $0 [prod|dev]" >&2; exit 1 ;;
  esac
  readonly target expected_branch env_file
  branch=$(git rev-parse --abbrev-ref HEAD)
  if [[ "$branch" != "$expected_branch" ]]; then
    echo "Refusing $target deployment: branch '$branch', expected '$expected_branch'." >&2
    echo "Switch branches or explicitly set DEPLOY_BRANCH when invoking this script." >&2
    exit 1
  fi
  if [[ ! -f "$env_file" ]]; then
    echo "Missing $env_file. Copy .env.example and fill it; dev needs distinct host ports." >&2
    exit 1
  fi
  # A deployment must not merge around uncommitted edits.
  if [[ -n "$(git status --porcelain --untracked-files=no)" ]]; then
    echo "Commit or stash tracked changes before deploying." >&2
    exit 1
  fi
  git pull --ff-only

  # This is a trusted operator-owned file, not arbitrary dotenv syntax.
  # Loading it overrides inherited empty variables used by build interpolation.
  set -a
  # shellcheck disable=SC1090
  . "./$env_file"
  set +a
  # Select isolation AFTER loading env, so copying .env cannot select prod's
  # project or database for dev. Never use fixed container/volume/image names.
  export ENV_FILE="$env_file"
  if [[ "$target" == dev ]]; then
    export COMPOSE_PROJECT_NAME=__APP_SLUG__-dev
    export PB_DATA_DIR=./pocketbase/pb_data_dev
    export APP_ENV=development
  else
    export COMPOSE_PROJECT_NAME=__APP_SLUG__
    export PB_DATA_DIR=./pocketbase/pb_data
    export APP_ENV=production
  fi
  : "${APP_PORT:?Set APP_PORT in the selected env file}"
  : "${PB_ADMIN_PORT:?Set PB_ADMIN_PORT in the selected env file}"
  : "${PB_ADMIN_EMAIL:?Set PB_ADMIN_EMAIL in the selected env file}"
  : "${PB_ADMIN_PASSWORD:?Set PB_ADMIN_PASSWORD in the selected env file}"
  local value
  for value in "$APP_PORT" "$PB_ADMIN_PORT"; do
    if [[ ! "$value" =~ ^[1-9][0-9]{0,4}$ ]] || (( value > 65535 )); then
      echo "Host ports must be integers from 1 to 65535." >&2
      exit 1
    fi
  done
  if [[ "$APP_PORT" == "$PB_ADMIN_PORT" ]]; then
    echo "APP_PORT and PB_ADMIN_PORT must differ." >&2
    exit 1
  fi
  local attempts=${DEPLOY_HEALTH_ATTEMPTS:-30}
  local interval=${DEPLOY_HEALTH_INTERVAL:-2}
  if [[ ! "$attempts" =~ ^[1-9][0-9]{0,3}$ || ! "$interval" =~ ^[1-9][0-9]{0,2}$ ]]; then
    echo "Health attempts/interval must be positive, bounded integers." >&2
    exit 1
  fi

  # Match these services and paths to the generated Compose file/API routes.
  local -a compose=(docker compose --file docker-compose.yml --env-file "$ENV_FILE" --project-name "$COMPOSE_PROJECT_NAME")
  local diagnostics=0
  local -a secret_values=()
  local variable
  while IFS= read -r variable; do
    case "$variable" in
      *PASSWORD*|*SECRET*|*TOKEN*|*KEY*)
        [[ -z "${!variable}" ]] || secret_values+=("${!variable}") ;;
    esac
  done < <(compgen -e)

  redact_logs() {
    local line secret
    while IFS= read -r line || [[ -n "$line" ]]; do
      for secret in "${secret_values[@]}"; do
        line=${line//"$secret"/[REDACTED]}
      done
      # Suppress credential-bearing fields, including SSE query tokens.
      if [[ "$line" =~ [Pp][Aa][Ss][Ss][Ww][Oo][Rr][Dd]|[Ss][Ee][Cc][Rr][Ee][Tt]|[Tt][Oo][Kk][Ee][Nn]|[Aa][Uu][Tt][Hh][Oo][Rr][Ii][Zz][Aa][Tt][Ii][Oo][Nn]|[Aa][Pp][Ii][_-]?[Kk][Ee][Yy] ]]; then
        printf '%s\n' '[credential-bearing log line omitted]'
      else
        printf '%s\n' "$line"
      fi
    done
  }

  failed() {
    local status=$?
    trap - ERR
    echo "Deployment failed (exit $status). Recent service diagnostics:" >&2
    if (( diagnostics )); then
      "${compose[@]}" ps >&2 || true
      "${compose[@]}" logs --no-color --since 2m --tail 40 api pocketbase frontend-build 2>&1 | redact_logs >&2 || true
    fi
    exit "$status"
  }
  trap failed ERR
  command -v curl >/dev/null
  "${compose[@]}" config --quiet
  diagnostics=1
  echo "Deploying $target ($COMPOSE_PROJECT_NAME, $ENV_FILE)."
  # Recreate the one-shot frontend copier even when its image is unchanged;
  # API startup waits for its successful exit via depends_on.
  "${compose[@]}" up -d --build --force-recreate pocketbase frontend-build api 2>&1 | redact_logs
  # Bind-mounted migrations are loaded when PocketBase starts.
  "${compose[@]}" restart pocketbase

  wait_for_health() {
    local label=$1 i
    shift
    for (( i=1; i<=attempts; i++ )); do
      if "$@" >/dev/null 2>&1; then return 0; fi
      if (( i < attempts )); then sleep "$interval"; fi
    done
    echo "$label failed health verification." >&2
    return 1
  }
  wait_for_health PocketBase "${compose[@]}" exec -T pocketbase \
    wget -q -T 5 -O /dev/null http://127.0.0.1:8090/api/health
  # Never echo credentials or run with shell tracing. An upsert may invalidate
  # the API's existing superuser token, so always restart the API afterwards.
  "${compose[@]}" exec -T pocketbase /pb/pocketbase superuser upsert \
    "$PB_ADMIN_EMAIL" "$PB_ADMIN_PASSWORD" >/dev/null 2>&1
  "${compose[@]}" restart api
  wait_for_health API curl --fail --silent --show-error --connect-timeout 2 \
    --max-time 5 "http://127.0.0.1:${APP_PORT}/api/health"
  echo "OK — $target API is healthy on host port $APP_PORT."
  "${compose[@]}" ps
  trap - ERR
}

main "$@"
