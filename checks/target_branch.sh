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
#   INPUT_ALLOW_STACKED_PRS      - "true" also allows a target branch that is the
#                                   head of another open PR in this PR's stack
#                                   (default: true)
#   INPUT_PR_NUMBER              - PR number, needed to look up the stack
#   GITHUB_REPOSITORY            - owner/repo, needed to look up the stack
#   GH_TOKEN                     - Token used by gh to read the stack

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib.sh"

TARGET="${INPUT_TARGET_BRANCH:-}"
require_pr_data "$TARGET" "target-branch"
ALLOWED="$(resolve_allowed_target_branches)"

# A PR is stacked when GitHub lists it in a stack where another open PR has
# the target branch as its head. Any lookup problem counts as "not stacked".
targets_branch_below_in_stack() {
    local pr_number="${INPUT_PR_NUMBER:-}" repository="${GITHUB_REPOSITORY:-}"
    [[ -n "$pr_number" && -n "$repository" ]] || return 1

    local stacks
    stacks="$(gh api -X GET "repos/${repository}/stacks" -f pull_request="$pr_number" \
        -H "X-GitHub-Api-Version: 2026-03-10" 2>/dev/null)" || return 1

    jq -e --arg target "$TARGET" --argjson pr "$pr_number" \
        'any(.[]?.pull_requests[]?; .number != $pr and .state == "open" and .head.ref == $target)' \
        <<<"$stacks" >/dev/null 2>&1
}

split_csv "$ALLOWED"

for branch in ${SPLIT_RESULT[@]+"${SPLIT_RESULT[@]}"}; do
    # shellcheck disable=SC2053 # unquoted RHS is intentional: allowed entries may be globs
    if [[ "$TARGET" == $branch ]]; then
        echo "pass"
        exit 0
    fi
done

if is_true "${INPUT_ALLOW_STACKED_PRS:-$DEFAULT_ALLOW_STACKED_PRS}" "allow-stacked-prs" \
    && targets_branch_below_in_stack; then
    echo "pass"
    exit 0
fi

echo "fail: target branch '$TARGET' not in allowed list: $ALLOWED"
exit 1
