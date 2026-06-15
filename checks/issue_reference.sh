#!/usr/bin/env bash
set -euo pipefail

# Validates that PR body or title references an issue. Supports GitHub issues
# (#123, issue URLs) and Azure Boards work items (AB#12345).
# Inputs via env vars:
#   INPUT_PR_TITLE                        - PR title (optional)
#   INPUT_PR_BODY                         - PR body (optional)
#   INPUT_ISSUE_REFERENCE_REQUIRE_KEYWORD - Only references preceded by a
#                                           closing keyword count, e.g.
#                                           "Fixes #123", "Closes AB#12345"
#                                           (default: false)

TITLE="${INPUT_PR_TITLE:-}"
BODY="${INPUT_PR_BODY:-}"
REQUIRE_KEYWORD="${INPUT_ISSUE_REFERENCE_REQUIRE_KEYWORD:-false}"
COMBINED="${TITLE} ${BODY}"

KEYWORDS="(close[sd]?|fix(e[sd])?|resolve[sd]?)"
REF_PATTERN="(AB)?#[0-9]+"
URL_PATTERN="https?://github\.com/[^/]+/[^/]+/issues/[0-9]+"
KEYWORD_PATTERN="${KEYWORDS}[[:space:]]+(${REF_PATTERN}|${URL_PATTERN})"

if printf '%s\n' "$COMBINED" | grep -qiE "$KEYWORD_PATTERN"; then
    echo "pass"
    exit 0
fi

if [[ "$REQUIRE_KEYWORD" == "true" ]]; then
    echo "fail: no keyword issue reference found (expected e.g. 'Fixes #123', 'Closes AB#12345')"
    exit 1
fi

if printf '%s\n' "$COMBINED" | grep -qiE "$REF_PATTERN"; then
    echo "pass"
    exit 0
fi

if printf '%s\n' "$COMBINED" | grep -qE "$URL_PATTERN"; then
    echo "pass"
    exit 0
fi

echo "fail: no issue reference found (expected #123, AB#12345, Fixes #123, or GitHub issue URL)"
exit 1
