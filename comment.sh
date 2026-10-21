#!/usr/bin/env bash
set -euo pipefail

# Keeps a single PR comment with the check summary while checks fail and
# deletes it once they pass. Needs the gh CLI and a token that can write
# pull request comments.
# Inputs via env vars:
#   GH_TOKEN            - Token used by gh
#   GITHUB_REPOSITORY   - owner/repo
#   INPUT_PR_NUMBER     - Pull request number
#   INPUT_RESULT        - pass or fail
#   INPUT_SUMMARY       - Markdown summary to post

COMMENT_MARKER="<!-- check-pr-requirements -->"

REPOSITORY="${GITHUB_REPOSITORY:?GITHUB_REPOSITORY is required}"
PR_NUMBER="${INPUT_PR_NUMBER:?input 'pr-number' is required for comment-on-failure}"
RESULT="${INPUT_RESULT:-}"
SUMMARY="${INPUT_SUMMARY:-}"

# Fills MARKER_COMMENT_IDS with the ids of our comments, oldest first
load_marker_comment_ids() {
    MARKER_COMMENT_IDS=()
    local ids id
    ids="$(gh api --paginate "repos/${REPOSITORY}/issues/${PR_NUMBER}/comments" \
        --jq ".[] | select(.body | startswith(\"${COMMENT_MARKER}\")) | .id")"
    while IFS= read -r id; do
        if [[ -n "$id" ]]; then
            MARKER_COMMENT_IDS+=("$id")
        fi
    done <<< "$ids"
}

# A concurrent run may have deleted the comment already, so a failed delete is
# not an error.
delete_comment() {
    gh api -X DELETE "repos/${REPOSITORY}/issues/comments/$1" >/dev/null || true
}

# Keeps the oldest marker comment and deletes the rest, so runs that raced
# past the lookup converge on a single comment.
delete_duplicates() {
    local i
    for ((i = 1; i < ${#MARKER_COMMENT_IDS[@]}; i++)); do
        delete_comment "${MARKER_COMMENT_IDS[$i]}"
    done
}

load_marker_comment_ids

if [[ "$RESULT" == "pass" ]]; then
    for id in ${MARKER_COMMENT_IDS[@]+"${MARKER_COMMENT_IDS[@]}"}; do
        delete_comment "$id"
    done
    exit 0
fi

comment_body="${COMMENT_MARKER}"$'\n'"${SUMMARY}"
if [[ ${#MARKER_COMMENT_IDS[@]} -gt 0 ]]; then
    gh api -X PATCH "repos/${REPOSITORY}/issues/comments/${MARKER_COMMENT_IDS[0]}" -f body="$comment_body" >/dev/null
    delete_duplicates
else
    gh api -X POST "repos/${REPOSITORY}/issues/${PR_NUMBER}/comments" -f body="$comment_body" >/dev/null
    load_marker_comment_ids
    delete_duplicates
fi
