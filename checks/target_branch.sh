#!/usr/bin/env bash
set -euo pipefail

# Validates that PR targets an allowed branch.
# Inputs via env vars:
#   INPUT_TARGET_BRANCH          - PR target branch (required)
#   INPUT_ALLOWED_TARGET_BRANCHES - Comma-separated allowed branches (default: "main,master")

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib.sh"

TARGET="${INPUT_TARGET_BRANCH:?Target branch is required}"
ALLOWED="${INPUT_ALLOWED_TARGET_BRANCHES:-main,master}"

split_csv "$ALLOWED"

for branch in ${SPLIT_RESULT[@]+"${SPLIT_RESULT[@]}"}; do
    if [[ "$TARGET" == "$branch" ]]; then
        echo "pass"
        exit 0
    fi
done

echo "fail: target branch '$TARGET' not in allowed list: $ALLOWED"
exit 1
