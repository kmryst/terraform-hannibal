#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  cleanup-merged-pr-branch.sh <PR number>

Description:
  Cleans up the local and remote head branch for a GitHub PR after the PR is
  confirmed as MERGED on GitHub.

Safety:
  - Does nothing when the PR is not MERGED.
  - Refuses to delete main/master or an empty branch name.
  - Refuses to run with a dirty worktree.
  - Switches to the PR base branch and pulls it with --ff-only before cleanup.

Example:
  ./scripts/github/cleanup-merged-pr-branch.sh 135
EOF
}

die() {
  printf 'Error: %s\n' "$1" >&2
  exit 1
}

run() {
  printf '+'
  printf ' %q' "$@"
  printf '\n'
  "$@"
}

local_branch_exists() {
  git show-ref --verify --quiet "refs/heads/$1"
}

remote_branch_exists() {
  git ls-remote --exit-code --heads origin "$1" >/dev/null 2>&1
}

if [[ $# -ne 1 ]]; then
  usage
  exit 1
fi

if [[ "$1" == "-h" || "$1" == "--help" ]]; then
  usage
  exit 0
fi

pr_number="$1"

[[ "$pr_number" =~ ^[0-9]+$ ]] || die "PR number must be numeric"
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || die "Not inside a git repository"

if [[ -n "$(git status --porcelain)" ]]; then
  die "Working tree must be clean before cleanup"
fi

pr_info="$(gh pr view "$pr_number" \
  --json state,mergedAt,headRefName,baseRefName \
  --jq '[.state, (.mergedAt // ""), .headRefName, .baseRefName] | @tsv')"

IFS=$'\t' read -r pr_state merged_at head_branch base_branch <<<"$pr_info"

if [[ "$pr_state" != "MERGED" ]]; then
  printf 'PR #%s is %s, not MERGED. Nothing to cleanup.\n' "$pr_number" "$pr_state"
  exit 0
fi

[[ -n "$head_branch" ]] || die "PR head branch is empty"
[[ "$head_branch" != "main" && "$head_branch" != "master" ]] || die "Refusing to delete protected branch: $head_branch"
[[ "$head_branch" != -* ]] || die "Refusing to delete branch starting with '-': $head_branch"
git check-ref-format --branch "$head_branch" >/dev/null || die "Invalid branch name: $head_branch"

if [[ -z "$base_branch" ]]; then
  base_branch="main"
fi

[[ "$head_branch" != "$base_branch" ]] || die "Refusing to delete PR base branch: $base_branch"

printf 'PR #%s is MERGED at %s.\n' "$pr_number" "$merged_at"
printf 'Cleanup target branch: %s\n' "$head_branch"
printf 'Base branch to update: %s\n' "$base_branch"

current_branch="$(git branch --show-current)"

if [[ "$current_branch" != "$base_branch" ]]; then
  run git switch "$base_branch"
fi

run git pull --ff-only origin "$base_branch"

if local_branch_exists "$head_branch"; then
  run git branch -D "$head_branch"
else
  printf 'Local branch %s does not exist. Skipping local cleanup.\n' "$head_branch"
fi

if remote_branch_exists "$head_branch"; then
  run git push origin --delete "$head_branch"
else
  printf 'Remote branch origin/%s does not exist. Skipping remote cleanup.\n' "$head_branch"
fi

printf 'Cleanup complete for PR #%s.\n' "$pr_number"
