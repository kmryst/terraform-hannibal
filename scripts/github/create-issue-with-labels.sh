#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  create-issue-with-labels.sh \
    --title "Issue title" \
    --body-file path/to/body.md \
    --type type:docs \
    --area area:docs \
    --risk risk:low \
    --cost cost:none

Required:
  --title       Issue title
  --body-file   Markdown body file passed to gh issue create
  --type        Exactly one type:* label
  --area        One or more area:* labels
  --risk        Exactly one risk:* label
  --cost        Exactly one cost:* label

Notes:
  - Repeat --area for multiple area labels.
  - The script creates the issue first, then applies labels with gh issue edit.
EOF
}

die() {
  printf 'Error: %s\n' "$1" >&2
  exit 1
}

require_prefix() {
  local value="$1"
  local prefix="$2"

  if [[ "$value" != "$prefix"* ]]; then
    die "Expected label '$value' to start with '$prefix'"
  fi
}

title=""
body_file=""
type_label=""
risk_label=""
cost_label=""
declare -a area_labels=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --title)
      [[ $# -ge 2 ]] || die "--title requires a value"
      title="$2"
      shift 2
      ;;
    --body-file)
      [[ $# -ge 2 ]] || die "--body-file requires a value"
      body_file="$2"
      shift 2
      ;;
    --type)
      [[ $# -ge 2 ]] || die "--type requires a value"
      type_label="$2"
      shift 2
      ;;
    --area)
      [[ $# -ge 2 ]] || die "--area requires a value"
      area_labels+=("$2")
      shift 2
      ;;
    --risk)
      [[ $# -ge 2 ]] || die "--risk requires a value"
      risk_label="$2"
      shift 2
      ;;
    --cost)
      [[ $# -ge 2 ]] || die "--cost requires a value"
      cost_label="$2"
      shift 2
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      die "Unknown argument: $1"
      ;;
  esac
done

[[ -n "$title" ]] || die "--title is required"
[[ -n "$body_file" ]] || die "--body-file is required"
[[ -f "$body_file" ]] || die "Body file not found: $body_file"
[[ -n "$type_label" ]] || die "--type is required"
[[ ${#area_labels[@]} -ge 1 ]] || die "At least one --area is required"
[[ -n "$risk_label" ]] || die "--risk is required"
[[ -n "$cost_label" ]] || die "--cost is required"

require_prefix "$type_label" "type:"
require_prefix "$risk_label" "risk:"
require_prefix "$cost_label" "cost:"
for area_label in "${area_labels[@]}"; do
  require_prefix "$area_label" "area:"
done

issue_url=$(
  gh issue create \
    --title "$title" \
    --body-file "$body_file"
)

issue_number="${issue_url##*/}"

edit_args=(
  issue edit "$issue_number"
  --add-label "$type_label"
  --add-label "$risk_label"
  --add-label "$cost_label"
)

for area_label in "${area_labels[@]}"; do
  edit_args+=(--add-label "$area_label")
done

gh "${edit_args[@]}"

printf 'Created issue #%s\n%s\n' "$issue_number" "$issue_url"
