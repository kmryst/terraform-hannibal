#!/usr/bin/env bash

set -euo pipefail

usage() {
	cat <<'EOF'
Usage:
  wait-for-synthetics-canary.sh <canary name>

Description:
  Waits for a CloudWatch Synthetics canary run that STARTS after this script
  starts, and succeeds when such a run ends in PASSED. Runs that started
  earlier are ignored, so the result reflects the code and infrastructure that
  were just deployed.

  A FAILED run does not stop the wait immediately: right after a deploy the
  ECS task, ALB target or CloudFront distribution may not be ready yet, and the
  next scheduled run is expected to pass. The script fails when no run that
  started after it passes before the timeout, and prints the last failure.

  Transient AWS API errors (throttling, network) are retried until the timeout.

  The script only reads the canary (synthetics:GetCanary / GetCanaryRuns).
  It does not start, stop or update the canary.

Environment variables:
  CANARY_WAIT_TIMEOUT_SECONDS   Total time to wait (default: 1200)
  CANARY_POLL_INTERVAL_SECONDS  Wait between polls (default: 30)
  AWS_REGION / AWS_DEFAULT_REGION  Region of the canary (AWS CLI default)

Requirements:
  aws (AWS CLI v2), jq, GNU date

Example:
  wait-for-synthetics-canary.sh hannibal-canary
EOF
}

if [[ $# -ne 1 || $1 == "-h" || $1 == "--help" ]]; then
	usage
	[[ $# -eq 1 ]] && exit 0
	exit 2
fi

canary_name="$1"
timeout_seconds="${CANARY_WAIT_TIMEOUT_SECONDS:-1200}"
interval_seconds="${CANARY_POLL_INTERVAL_SECONDS:-30}"

for command in aws jq date; do
	command -v "$command" >/dev/null 2>&1 || {
		echo "Error: $command is required" >&2
		exit 2
	}
done

started_after="$(date +%s)"
deadline=$((SECONDS + timeout_seconds))
last_failure=""
reported_runs=" "

echo "Waiting for a run of canary ${canary_name} that starts after $(date -u -d "@${started_after}" +%Y-%m-%dT%H:%M:%SZ)"

aws_error_file="$(mktemp)"
trap 'rm -f "$aws_error_file"' EXIT

while true; do
	# AWS API の一時的な失敗（throttling など）では止めずに次の poll で再試行する
	if canary_state="$(aws synthetics get-canary --name "$canary_name" \
		--query 'Canary.Status.State' --output text 2>"$aws_error_file")" &&
		runs_json="$(aws synthetics get-canary-runs --name "$canary_name" \
			--max-results 20 --output json 2>"$aws_error_file")"; then
		case "$canary_state" in
		RUNNING | STARTING | UPDATING | CREATING | READY) ;;
		*)
			echo "Error: canary ${canary_name} is ${canary_state}; it will not produce new runs" >&2
			exit 1
			;;
		esac

		# Oldest first, so that a later PASSED run wins over an earlier FAILED run.
		while IFS=$'\t' read -r run_id run_state run_started run_reason; do
			[[ -z $run_id ]] && continue
			run_started_epoch="$(date -d "$run_started" +%s)"
			((run_started_epoch >= started_after)) || continue

			case "$run_state" in
			PASSED)
				echo "OK: canary run ${run_id} started at ${run_started} PASSED"
				exit 0
				;;
			FAILED)
				last_failure="run ${run_id} started at ${run_started} FAILED: ${run_reason}"
				if [[ $reported_runs != *" ${run_id} "* ]]; then
					echo "Canary ${last_failure}"
					reported_runs+="${run_id} "
				fi
				;;
			esac
		done < <(echo "$runs_json" | jq -r '
			.CanaryRuns
			| sort_by(.Timeline.Started)
			| .[]
			| [.Id, .Status.State, .Timeline.Started, ((.Status.StateReason // "") | gsub("[\t\n]"; " ") | .[0:300])]
			| @tsv')
	else
		last_failure="AWS API error: $(tr '\n' ' ' <"$aws_error_file" | cut -c1-300)"
		echo "Warning: ${last_failure} (will retry)"
	fi

	# 最後の poll がタイムアウトちょうどに行われるよう、残り時間が interval より短ければ残り時間だけ待つ
	remaining=$((deadline - SECONDS))
	((remaining > 0)) || break
	sleep "$((remaining < interval_seconds ? remaining : interval_seconds))"
done

echo "Error: no run of canary ${canary_name} that started after the deploy PASSED within ${timeout_seconds}s. Last failure: ${last_failure:-none (no completed run)}" >&2
exit 1
