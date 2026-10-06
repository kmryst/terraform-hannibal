#!/usr/bin/env bash

set -euo pipefail

usage() {
	cat <<'EOF'
Usage:
  verify-graphql-routes.sh <GraphQL endpoint URL>

Description:
  Sends the read-only GraphQL query `{ routes { id } }` to the endpoint and
  succeeds only when the response is HTTP 200, has no `errors`, and
  `data.routes` is an array. The query goes through
  GraphQL -> TypeORM -> PostgreSQL, so it fails when the `routes` table is
  missing (for example, when migrations were not applied).

  The request is retried until it succeeds or the timeout expires, because
  right after a deploy the ECS task, ALB target, CloudFront distribution or
  DNS record may not be ready yet.

  This script never sends a mutation.

Environment variables:
  VERIFY_TIMEOUT_SECONDS   Total time to keep retrying (default: 600)
  VERIFY_INTERVAL_SECONDS  Wait between attempts (default: 15)
  VERIFY_REQUEST_TIMEOUT   Per-request timeout for curl (default: 10)

Requirements:
  curl, jq

Examples:
  verify-graphql-routes.sh https://hamilcar-hannibal.click/graphql
  VERIFY_TIMEOUT_SECONDS=60 verify-graphql-routes.sh http://localhost:3000/graphql
EOF
}

if [[ $# -ne 1 || $1 == "-h" || $1 == "--help" ]]; then
	usage
	[[ $# -eq 1 ]] && exit 0
	exit 2
fi

endpoint="$1"
timeout_seconds="${VERIFY_TIMEOUT_SECONDS:-600}"
interval_seconds="${VERIFY_INTERVAL_SECONDS:-15}"
request_timeout="${VERIFY_REQUEST_TIMEOUT:-10}"

for command in curl jq; do
	command -v "$command" >/dev/null 2>&1 || {
		echo "Error: $command is required" >&2
		exit 2
	}
done

query='{"query":"query DeployVerification { routes { id } }"}'
body_file="$(mktemp)"
trap 'rm -f "$body_file"' EXIT

deadline=$((SECONDS + timeout_seconds))
attempt=0
last_reason=""

while true; do
	attempt=$((attempt + 1))
	status="$(curl -sS -o "$body_file" -w '%{http_code}' \
		--max-time "$request_timeout" \
		-X POST \
		-H 'Content-Type: application/json' \
		--data "$query" \
		"$endpoint" 2>/dev/null)" || status="000"

	if [[ $status == "200" ]] &&
		jq -e '(.errors == null) and (.data.routes | type == "array")' "$body_file" >/dev/null 2>&1; then
		count="$(jq '.data.routes | length' "$body_file")"
		echo "OK: routes query succeeded on attempt ${attempt} (HTTP ${status}, ${count} routes)"
		exit 0
	fi

	if jq -e '.errors' "$body_file" >/dev/null 2>&1; then
		last_reason="HTTP ${status}, GraphQL errors: $(jq -c '[.errors[].message]' "$body_file" | cut -c1-300)"
	else
		last_reason="HTTP ${status}, body: $(head -c 300 "$body_file" | tr -d '\n')"
	fi
	echo "Attempt ${attempt}: ${last_reason}"

	remaining=$((deadline - SECONDS))
	((remaining > 0)) || break
	sleep "$((remaining < interval_seconds ? remaining : interval_seconds))"
done

echo "Error: routes query did not succeed within ${timeout_seconds}s (${attempt} attempts). Last result: ${last_reason}" >&2
exit 1
