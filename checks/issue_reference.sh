#!/usr/bin/env bash
set -euo pipefail

# Validates that PR body or title references an issue. Supports GitHub issues
# (#123, owner/repo#123, issue URLs) and Azure Boards work items (AB#12345).
# Inputs via env vars:
#   INPUT_PR_TITLE                        - PR title (optional)
#   INPUT_PR_BODY                         - PR body (optional)
#   INPUT_ISSUE_REFERENCE_REQUIRE_KEYWORD - Only references preceded by a
#                                           closing keyword count, e.g.
#                                           "Fixes #123", "Closes AB#12345".
#                                           Only the body is searched, as
#                                           GitHub ignores keywords in titles
#                                           (default: false)

TITLE="${INPUT_PR_TITLE:-}"
BODY="${INPUT_PR_BODY:-}"
REQUIRE_KEYWORD="${INPUT_ISSUE_REFERENCE_REQUIRE_KEYWORD:-false}"

WORD_START="(^|[^[:alnum:]_])"
REF_START="(^|[^[:alnum:]_./#&-])"
REF_END="([^[:alnum:]_]|$)"
KEYWORDS="(close[sd]?|fix(e[sd])?|resolve[sd]?)"
REF="(AB#|[[:alnum:]_.-]+/[[:alnum:]_.-]+#|#)[0-9]+"
ISSUE_URL="https?://github\.com/[^/]+/[^/]+/issues/[0-9]+"

KEYWORD_PATTERN="${WORD_START}${KEYWORDS}[[:space:]]+(${REF}|${ISSUE_URL})${REF_END}"
BARE_REF_PATTERN="${REF_START}${REF}${REF_END}"

contains() {
    printf '%s\n' "$1" | grep -qiE "$2"
}

if contains "$BODY" "$KEYWORD_PATTERN"; then
    echo "pass"
    exit 0
fi

if [[ "$REQUIRE_KEYWORD" == "true" ]]; then
    echo "fail: no keyword issue reference found in the description (expected e.g. 'Fixes #123', 'Closes AB#12345')"
    exit 1
fi

TITLE_AND_BODY="${TITLE}"$'\n'"${BODY}"
if contains "$TITLE_AND_BODY" "$BARE_REF_PATTERN" || contains "$TITLE_AND_BODY" "$ISSUE_URL"; then
    echo "pass"
    exit 0
fi

echo "fail: no issue reference found (expected #123, AB#12345, Fixes #123, or GitHub issue URL)"
exit 1
