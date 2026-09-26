#!/usr/bin/env bash
# Minimal Hetzner Cloud API helper. Requires curl; jq is optional for wait-action.
set -euo pipefail

BASE_URL="${HCLOUD_API_BASE_URL:-https://api.hetzner.cloud/v1}"
TOKEN="${HCLOUD_TOKEN:-${HETZNER_CLOUD_API_TOKEN:-}}"

usage() {
  cat <<'EOF'
Usage:
  hcloud-api.sh METHOD /path [json-body]
  hcloud-api.sh wait-action ACTION_ID [timeout_seconds]

Environment:
  HCLOUD_TOKEN (preferred) or HETZNER_CLOUD_API_TOKEN  Required API token
  HCLOUD_API_BASE_URL                                  Optional API base URL
  HCLOUD_ALLOW_DESTRUCTIVE=1                           Required for DELETE
EOF
}

fail() { printf 'Error: %s\n' "$*" >&2; exit 1; }

require_token() {
  [[ -n "$TOKEN" ]] || fail 'Set HCLOUD_TOKEN (or HETZNER_CLOUD_API_TOKEN) in a secret-backed environment variable.'
}

api_call() {
  local method="$1" path="$2" body="${3:-}"
  [[ "$path" == /* ]] || fail 'Path must begin with /, for example /servers.'
  [[ "$path" != *$'\n'* && "$path" != *$'\r'* ]] || fail 'Path contains an invalid newline.'
  if [[ "$method" == "DELETE" && "${HCLOUD_ALLOW_DESTRUCTIVE:-}" != "1" ]]; then
    fail 'DELETE is blocked. Re-run only after explicit approval with HCLOUD_ALLOW_DESTRUCTIVE=1.'
  fi

  local -a args=(--fail-with-body --silent --show-error
    -X "$method"
    -H "Authorization: Bearer $TOKEN"
    -H 'Accept: application/json')
  if [[ -n "$body" ]]; then
    args+=(-H 'Content-Type: application/json' --data "$body")
  fi
  curl "${args[@]}" "${BASE_URL}${path}"
}

wait_action() {
  local action_id="$1" timeout="${2:-600}" elapsed=0 response status
  [[ "$action_id" =~ ^[1-9][0-9]*$ ]] || fail 'Action ID must be a positive integer.'
  [[ "$timeout" =~ ^[1-9][0-9]*$ ]] || fail 'Timeout must be a positive integer.'
  command -v jq >/dev/null 2>&1 || fail 'wait-action requires jq. Install jq or poll GET /actions/{id} manually.'

  while :; do
    response="$(api_call GET "/actions/${action_id}")"
    status="$(printf '%s' "$response" | jq -r '.action.status // empty')"
    case "$status" in
      success) printf '%s\n' "$response"; return 0 ;;
      error) printf '%s\n' "$response" >&2; return 1 ;;
      running) ;;
      *) printf '%s\n' "$response" >&2; fail "Unexpected action status: ${status:-missing}" ;;
    esac
    if (( elapsed >= timeout )); then
      printf '%s\n' "$response" >&2
      fail "Timed out waiting for action ${action_id} after ${timeout} seconds."
    fi
    sleep 5
    elapsed=$((elapsed + 5))
  done
}

[[ $# -ge 1 ]] || { usage >&2; exit 2; }
case "$1" in
  -h|--help|help) usage; exit 0 ;;
  wait-action)
    [[ $# -ge 2 && $# -le 3 ]] || { usage >&2; exit 2; }
    require_token
    wait_action "$2" "${3:-600}"
    ;;
  GET|POST|PUT|DELETE|PATCH)
    [[ $# -ge 2 && $# -le 3 ]] || { usage >&2; exit 2; }
    require_token
    api_call "$1" "$2" "${3:-}"
    ;;
  *) usage >&2; fail "Unsupported command or HTTP method: $1" ;;
esac