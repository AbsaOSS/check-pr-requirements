#!/usr/bin/env bash
set -euo pipefail

# Validates that PR targets an allowed branch.
# Inputs via env vars:
#   INPUT_TARGET_BRANCH          - PR target branch (required)
#   INPUT_ALLOWED_TARGET_BRANCHES - Comma-separated allowed branches (default: "main,master")

TARGET="${INPUT_TARGET_BRANCH:?Target branch is required}"
ALLOWED="${INPUT_ALLOWED_TARGET_BRANCHES:-main,master}"

IFS=',' read -ra ALLOWED_ARRAY <<< "$ALLOWED"

for branch in "${ALLOWED_ARRAY[@]}"; do
    branch_trimmed=$(echo "$branch" | xargs)
    if [[ "$TARGET" == "$branch_trimmed" ]]; then
        echo "pass"
        exit 0
    fi
done

echo "fail: target branch '$TARGET' not in allowed list: $ALLOWED"
exit 1
