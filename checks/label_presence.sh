#!/usr/bin/env bash
set -euo pipefail

# Validates that PR has required labels.
# Inputs via env vars:
#   INPUT_LABELS          - Comma-separated list of PR labels (required)
#   INPUT_REQUIRED_LABELS - Comma-separated required labels (empty = at least one label)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib.sh"

LABELS="${INPUT_LABELS:-}"
REQUIRED="${INPUT_REQUIRED_LABELS:-}"

if [[ -z "$LABELS" ]]; then
    echo "fail: PR has no labels"
    exit 1
fi

if [[ -z "$REQUIRED" ]]; then
    echo "pass"
    exit 0
fi

split_csv "$REQUIRED"
REQUIRED_ARRAY=(${SPLIT_RESULT[@]+"${SPLIT_RESULT[@]}"})

MISSING=()
for req in ${REQUIRED_ARRAY[@]+"${REQUIRED_ARRAY[@]}"}; do
    if ! csv_contains_ignore_case "$req" "$LABELS"; then
        MISSING+=("$req")
    fi
done

if [[ ${#MISSING[@]} -gt 0 ]]; then
    echo "fail: missing required labels: ${MISSING[*]}"
    exit 1
fi

echo "pass"
exit 0
