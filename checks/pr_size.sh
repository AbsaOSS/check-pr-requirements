#!/usr/bin/env bash
set -euo pipefail

# Validates PR size does not exceed file count limit.
# Inputs via env vars:
#   INPUT_FILES_CHANGED    - Number of files changed (required)
#   INPUT_MAX_FILES_CHANGED - Maximum allowed (default: 50)

FILES="${INPUT_FILES_CHANGED:?Files changed count is required}"
MAX="${INPUT_MAX_FILES_CHANGED:-50}"

if ! [[ "$FILES" =~ ^[0-9]+$ ]]; then
    echo "fail: invalid files changed count '$FILES'"
    exit 1
fi

if ! [[ "$MAX" =~ ^[0-9]+$ ]]; then
    echo "fail: invalid max files changed '$MAX'"
    exit 1
fi

if [[ "$FILES" -gt "$MAX" ]]; then
    echo "fail: PR changes $FILES files (maximum $MAX)"
    exit 1
fi

echo "pass"
exit 0
