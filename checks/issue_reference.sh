#!/usr/bin/env bash
set -euo pipefail

# Validates that PR body or title references a GitHub issue.
# Inputs via env vars:
#   INPUT_PR_TITLE - PR title (optional)
#   INPUT_PR_BODY  - PR body (optional)

TITLE="${INPUT_PR_TITLE:-}"
BODY="${INPUT_PR_BODY:-}"
COMBINED="${TITLE} ${BODY}"

GITHUB_KEYWORDS="(close[sd]?|fix(e[sd])?|resolve[sd]?)"
GITHUB_PATTERN="${GITHUB_KEYWORDS}[[:space:]]+#[0-9]+"
HASH_PATTERN="#[0-9]+"
URL_PATTERN="https?://github\.com/[^/]+/[^/]+/issues/[0-9]+"

if echo "$COMBINED" | grep -qiE "$GITHUB_PATTERN"; then
    echo "pass"
    exit 0
fi

if echo "$COMBINED" | grep -qE "$HASH_PATTERN"; then
    echo "pass"
    exit 0
fi

if echo "$COMBINED" | grep -qE "$URL_PATTERN"; then
    echo "pass"
    exit 0
fi

echo "fail: no issue reference found (expected #123, Fixes #123, or GitHub issue URL)"
exit 1
