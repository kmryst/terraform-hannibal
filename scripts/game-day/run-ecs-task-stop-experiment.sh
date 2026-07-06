#!/usr/bin/env bash

set -euo pipefail

usage() {
	cat <<'EOF'
Usage:
  run-ecs-task-stop-experiment.sh [--template-id <FIS experiment template ID>] [--yes]

Description:
  Starts the AWS FIS Game Day experiment that force-stops one running
  nestjs-hannibal-3-cluster ECS task (aws:ecs:stop-task, COUNT(1) selection),
  then polls until the experiment reaches a terminal state.

  This script does NOT trigger destroy.yml or any GitHub Actions workflow.
  destroy remains a human decision, run manually after the exercise.

Options:
  --template-id  FIS experiment template ID. If omitted, resolved from
                 `terraform -chdir=terraform/service output -raw fis_experiment_template_id`.
  --yes          Skip the interactive confirmation prompt.
  -h, --help     Show this help.

Requirements:
  - AWS credentials with fis:StartExperiment / fis:GetExperiment
    (HannibalCICDRole-Dev or equivalent; the experiment itself runs as
    HannibalFISRole-Dev, which the caller does not need to assume directly)
  - The dev environment must already be deployed (terraform/service applied),
    otherwise the experiment template / target ECS service does not exist.

After the experiment finishes, record the result using
docs/operations/game-day-exercise-template.md and follow the verification
checklist in docs/operations/runbook.md (Game Day演習).
EOF
}

PROJECT_NAME="nestjs-hannibal-3"
REGION="ap-northeast-1"
TEMPLATE_ID=""
ASSUME_YES=false

while [ $# -gt 0 ]; do
	case "$1" in
	--template-id)
		TEMPLATE_ID="$2"
		shift 2
		;;
	--yes)
		ASSUME_YES=true
		shift
		;;
	-h | --help)
		usage
		exit 0
		;;
	*)
		echo "Unknown argument: $1" >&2
		usage
		exit 1
		;;
	esac
done

if [ -z "$TEMPLATE_ID" ]; then
	echo "No --template-id given. Resolving from terraform/service output..."
	TEMPLATE_ID="$(terraform -chdir=terraform/service output -raw fis_experiment_template_id)"
fi

if [ -z "$TEMPLATE_ID" ]; then
	echo "Error: could not resolve an FIS experiment template ID." >&2
	exit 1
fi

echo "Project:      $PROJECT_NAME"
echo "Region:       $REGION"
echo "Template ID:  $TEMPLATE_ID"
echo
echo "This will force-stop one running ECS task in ${PROJECT_NAME}-cluster."
echo "The SLO error-rate fast-burn alarm is wired as an automatic stop condition."

if [ "$ASSUME_YES" != true ]; then
	read -r -p "Proceed with starting the FIS experiment? [y/N] " REPLY
	case "$REPLY" in
	[yY] | [yY][eE][sS]) ;;
	*)
		echo "Aborted."
		exit 1
		;;
	esac
fi

START_TIME=$(date -u +%Y-%m-%dT%H:%M:%SZ)
echo "Starting experiment at ${START_TIME}..."

EXPERIMENT_ID=$(aws fis start-experiment \
	--experiment-template-id "$TEMPLATE_ID" \
	--region "$REGION" \
	--tags "Name=${PROJECT_NAME}-game-day-ecs-task-stop" \
	--query 'experiment.id' \
	--output text)

echo "Experiment started: $EXPERIMENT_ID"
echo "Polling until the experiment reaches a terminal state..."

while true; do
	STATUS=$(aws fis get-experiment \
		--id "$EXPERIMENT_ID" \
		--region "$REGION" \
		--query 'experiment.state.status' \
		--output text)
	echo "  status: $STATUS"
	case "$STATUS" in
	completed | stopped | failed)
		break
		;;
	esac
	sleep 5
done

END_TIME=$(date -u +%Y-%m-%dT%H:%M:%SZ)

echo
echo "Experiment finished with status: $STATUS"
echo "Start: $START_TIME"
echo "End:   $END_TIME"
echo
echo "Next steps:"
echo "  1. Check ECS service recovery:"
echo "     aws ecs describe-services --cluster ${PROJECT_NAME}-cluster --services ${PROJECT_NAME}-api-service --region $REGION"
echo "  2. Check whether the SLO burn-rate alarms fired:"
echo "     aws cloudwatch describe-alarms --alarm-name-prefix ${PROJECT_NAME}-slo --region $REGION"
echo "  3. Fill out docs/operations/game-day-exercise-template.md with the recovery time and alarm results."
echo "  4. destroy is a separate, human-triggered step (destroy.yml). This script does not run it."
