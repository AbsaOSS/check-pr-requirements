#!/usr/bin/env bash
set -euo pipefail

# Validates that PR targets an allowed branch.
# Inputs via env vars:
#   INPUT_TARGET_BRANCH          - PR target branch (required)
#   INPUT_ALLOWED_TARGET_BRANCHES - Comma-separated allowed branches; glob
#                                   patterns supported, e.g. "main,support/*"
#                                   (default: the repository's default branch)
#   INPUT_REPO_DEFAULT_BRANCH    - Repository default branch; used when no
#                                   allowed list is given (fallback: "main,master")
#   INPUT_ALLOW_STACKED_PRS      - "true" also allows a target branch matching
#                                   branch-pattern (default: false)
#   INPUT_BRANCH_PATTERN         - Regex used for stacked PR targets

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib.sh"

TARGET="${INPUT_TARGET_BRANCH:-}"
require_pr_data "$TARGET" "target-branch"
ALLOWED="$(resolve_allowed_target_branches)"

split_csv "$ALLOWED"

for branch in ${SPLIT_RESULT[@]+"${SPLIT_RESULT[@]}"}; do
    # shellcheck disable=SC2053 # unquoted RHS is intentional: allowed entries may be globs
    if [[ "$TARGET" == $branch ]]; then
        echo "pass"
        exit 0
    fi
done

if is_true "${INPUT_ALLOW_STACKED_PRS:-false}" "allow-stacked-prs"; then
    PATTERN="${INPUT_BRANCH_PATTERN:-$DEFAULT_BRANCH_PATTERN}"
    require_valid_regex "$PATTERN" "branch-pattern"
    if [[ "$TARGET" =~ $PATTERN ]]; then
        echo "pass"
        exit 0
    fi
fi

echo "fail: target branch '$TARGET' not in allowed list: $ALLOWED"
exit 1
