#!/usr/bin/env bash
set -euo pipefail

# Validates PR size does not exceed the file count and, optionally, line
# count limits.
# Inputs via env vars:
#   INPUT_FILES_CHANGED     - Number of files changed (required)
#   INPUT_MAX_FILES_CHANGED - Maximum files allowed (default: 50)
#   INPUT_ADDITIONS         - Lines added (required when max-lines-changed is set)
#   INPUT_DELETIONS         - Lines deleted (required when max-lines-changed is set)
#   INPUT_MAX_LINES_CHANGED - Maximum added + deleted lines (empty = no limit)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib.sh"

FILES="${INPUT_FILES_CHANGED:-}"
require_pr_data "$FILES" "files-changed"
MAX="${INPUT_MAX_FILES_CHANGED:-$DEFAULT_MAX_FILES_CHANGED}"
MAX_LINES="${INPUT_MAX_LINES_CHANGED:-}"

if ! [[ "$FILES" =~ ^[0-9]+$ ]]; then
    echo "fail: invalid files changed count '$FILES'"
    exit 1
fi

require_whole_number "$MAX" "max-files-changed"

EXCEEDED_LIMITS=()
if [[ "$FILES" -gt "$MAX" ]]; then
    EXCEEDED_LIMITS+=("PR changes $FILES files (maximum $MAX)")
fi

if [[ -n "$MAX_LINES" ]]; then
    require_whole_number "$MAX_LINES" "max-lines-changed"
    ADDITIONS="${INPUT_ADDITIONS:-}"
    DELETIONS="${INPUT_DELETIONS:-}"
    require_pr_data "$ADDITIONS" "additions"
    require_pr_data "$DELETIONS" "deletions"
    if ! [[ "$ADDITIONS" =~ ^[0-9]+$ && "$DELETIONS" =~ ^[0-9]+$ ]]; then
        echo "fail: invalid line counts (additions '$ADDITIONS', deletions '$DELETIONS')"
        exit 1
    fi
    LINES_CHANGED=$((ADDITIONS + DELETIONS))
    if [[ "$LINES_CHANGED" -gt "$MAX_LINES" ]]; then
        EXCEEDED_LIMITS+=("PR changes $LINES_CHANGED lines (maximum $MAX_LINES)")
    fi
fi

if [[ ${#EXCEEDED_LIMITS[@]} -gt 0 ]]; then
    printf -v exceeded_text '%s; ' "${EXCEEDED_LIMITS[@]}"
    echo "fail: ${exceeded_text%; }"
    exit 1
fi

echo "pass"
exit 0
