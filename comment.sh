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

existing_comment_id="$(gh api --paginate "repos/${REPOSITORY}/issues/${PR_NUMBER}/comments" \
    --jq ".[] | select(.body | startswith(\"${COMMENT_MARKER}\")) | .id" | sed -n 1p)"

if [[ "$RESULT" == "pass" ]]; then
    if [[ -n "$existing_comment_id" ]]; then
        gh api -X DELETE "repos/${REPOSITORY}/issues/comments/${existing_comment_id}" >/dev/null
    fi
    exit 0
fi

comment_body="${COMMENT_MARKER}"$'\n'"${SUMMARY}"
if [[ -n "$existing_comment_id" ]]; then
    gh api -X PATCH "repos/${REPOSITORY}/issues/comments/${existing_comment_id}" -f body="$comment_body" >/dev/null
else
    gh api -X POST "repos/${REPOSITORY}/issues/${PR_NUMBER}/comments" -f body="$comment_body" >/dev/null
fi
