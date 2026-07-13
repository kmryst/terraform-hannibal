#!/usr/bin/env bash

set -euo pipefail

usage() {
	cat <<'EOF'
Usage:
  sync-labels.sh [--file .github/labels.yml] [--repo owner/repo] [--dry-run]

Description:
  Creates or updates GitHub labels from .github/labels.yml.

Safety:
  - Uses `gh label create --force`, so existing labels are updated.
  - Does not delete labels that are absent from the file.
  - Supports the simple labels.yml format used in this repository.

Examples:
  ./scripts/github/sync-labels.sh
  ./scripts/github/sync-labels.sh --dry-run
  ./scripts/github/sync-labels.sh --repo kmryst/terraform-hannibal
EOF
}

die() {
	printf 'Error: %s\n' "$1" >&2
	exit 1
}

labels_file=".github/labels.yml"
repo=""
dry_run="false"

while [[ $# -gt 0 ]]; do
	case "$1" in
	--file)
		[[ $# -ge 2 ]] || die "--file requires a value"
		labels_file="$2"
		shift 2
		;;
	--repo)
		[[ $# -ge 2 ]] || die "--repo requires a value"
		repo="$2"
		shift 2
		;;
	--dry-run)
		dry_run="true"
		shift
		;;
	--help | -h)
		usage
		exit 0
		;;
	*)
		die "Unknown argument: $1"
		;;
	esac
done

[[ -f $labels_file ]] || die "Labels file not found: $labels_file"
command -v gh >/dev/null 2>&1 || die "gh CLI is required"
command -v python3 >/dev/null 2>&1 || die "python3 is required"

repo_args=()
if [[ -n $repo ]]; then
	repo_args=(-R "$repo")
fi

parse_labels() {
	python3 - "$labels_file" <<'PY'
import re
import sys

path = sys.argv[1]
labels = []
current = None

start_re = re.compile(r'^\s*-\s+name:\s*"([^"]+)"\s*(#.*)?$')
prop_re = re.compile(r'^\s+(color|description):\s*"([^"]*)"\s*(#.*)?$')

with open(path, encoding="utf-8") as f:
    for line_number, raw_line in enumerate(f, start=1):
        line = raw_line.rstrip("\n")
        stripped = line.strip()
        if not stripped or stripped.startswith("#"):
            continue

        start_match = start_re.match(line)
        if start_match:
            if current is not None:
                labels.append(current)
            current = {"name": start_match.group(1), "line": line_number}
            continue

        prop_match = prop_re.match(line)
        if prop_match and current is not None:
            current[prop_match.group(1)] = prop_match.group(2)
            continue

        raise SystemExit(f"Unsupported labels.yml syntax at line {line_number}: {line}")

if current is not None:
    labels.append(current)

for label in labels:
    missing = [key for key in ("name", "color", "description") if key not in label]
    if missing:
        raise SystemExit(
            f"Label starting at line {label['line']} is missing: {', '.join(missing)}"
        )
    print(f"{label['name']}\t{label['color']}\t{label['description']}")
PY
}

count=0
while IFS=$'\t' read -r name color description; do
	[[ -n $name ]] || continue
	count=$((count + 1))

	command_args=(
		gh label create "$name"
		--color "$color"
		--description "$description"
		--force
	)
	if [[ ${#repo_args[@]} -gt 0 ]]; then
		command_args+=("${repo_args[@]}")
	fi

	if [[ $dry_run == "true" ]]; then
		printf '+'
		printf ' %q' "${command_args[@]}"
		printf '\n'
	else
		"${command_args[@]}"
	fi
done < <(parse_labels)

if [[ $dry_run == "true" ]]; then
	printf 'Dry run complete. %d labels would be created or updated.\n' "$count"
else
	printf 'Synced %d labels from %s.\n' "$count" "$labels_file"
fi
