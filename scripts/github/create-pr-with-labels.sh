#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  create-pr-with-labels.sh \
    --title "PR title" \
    --body-file path/to/body.md \
    --issue 123 \
    --type type:infra \
    --area area:ci-cd \
    --risk risk:low \
    --cost cost:none \
    [--area area:docs] \
    [--base main] \
    [--head my-branch]

Required:
  --title       PR title
  --body-file   Markdown body file passed to gh pr create
  --issue       Linked issue number appended as Closes #<number>
  --type        Exactly one type:* label
  --area        One or more area:* labels
  --risk        Exactly one risk:* label
  --cost        Exactly one cost:* label

Optional:
  --base        Base branch (default: main)
  --head        Head branch (default: current branch)

Notes:
  - Repeat --area for multiple area labels.
  - The script appends Closes #<issue> to the PR body automatically.
  - The script creates the PR first, then applies labels with gh issue edit.
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
base_branch="main"
head_branch=""
linked_issue=""
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
    --issue)
      [[ $# -ge 2 ]] || die "--issue requires a value"
      linked_issue="$2"
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
    --base)
      [[ $# -ge 2 ]] || die "--base requires a value"
      base_branch="$2"
      shift 2
      ;;
    --head)
      [[ $# -ge 2 ]] || die "--head requires a value"
      head_branch="$2"
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
[[ -n "$linked_issue" ]] || die "--issue is required"
[[ -n "$type_label" ]] || die "--type is required"
[[ ${#area_labels[@]} -ge 1 ]] || die "At least one --area is required"
[[ -n "$risk_label" ]] || die "--risk is required"
[[ -n "$cost_label" ]] || die "--cost is required"

[[ "$linked_issue" =~ ^[0-9]+$ ]] || die "--issue must be a numeric issue number"
require_prefix "$type_label" "type:"
require_prefix "$risk_label" "risk:"
require_prefix "$cost_label" "cost:"
for area_label in "${area_labels[@]}"; do
  require_prefix "$area_label" "area:"
done

tmp_body="$(mktemp)"
trap 'rm -f "$tmp_body"' EXIT

cat "$body_file" > "$tmp_body"
printf '\n\nCloses #%s\n' "$linked_issue" >> "$tmp_body"

create_args=(
  pr create
  --title "$title"
  --body-file "$tmp_body"
  --base "$base_branch"
)

if [[ -n "$head_branch" ]]; then
  create_args+=(--head "$head_branch")
fi

pr_url=$(gh "${create_args[@]}")
pr_number="${pr_url##*/}"

edit_args=(
  issue edit "$pr_number"
  --add-label "$type_label"
  --add-label "$risk_label"
  --add-label "$cost_label"
)

for area_label in "${area_labels[@]}"; do
  edit_args+=(--add-label "$area_label")
done

gh "${edit_args[@]}"

printf 'Created PR #%s\n%s\n' "$pr_number" "$pr_url"
