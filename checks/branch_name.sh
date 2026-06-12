#!/usr/bin/env bash
set -euo pipefail

# Validates PR source branch name against a pattern.
# Inputs via env vars:
#   INPUT_PR_BRANCH            - Branch name to validate (required)
#   INPUT_BRANCH_PATTERN       - Regex pattern (default: standard prefixes)
#   INPUT_BRANCH_REQUIRE_TICKET - Require ticket number after prefix, e.g.
#                                 feature/123-user-login (default: false)

BRANCH="${INPUT_PR_BRANCH:?PR branch name is required}"
PATTERN="${INPUT_BRANCH_PATTERN:-^(feature|bugfix|hotfix|release|support|chore|docs|ci|dependabot)/[a-zA-Z0-9._-]+$}"
REQUIRE_TICKET="${INPUT_BRANCH_REQUIRE_TICKET:-false}"

if [[ ! "$BRANCH" =~ $PATTERN ]]; then
    echo "fail: branch name '$BRANCH' does not match pattern '$PATTERN'"
    exit 1
fi

TICKET_PATTERN='^[^/]+/[0-9]+-'
if [[ "$REQUIRE_TICKET" == "true" ]] && [[ ! "$BRANCH" =~ $TICKET_PATTERN ]]; then
    echo "fail: branch name '$BRANCH' must include a ticket number after the prefix (e.g. feature/123-user-login)"
    exit 1
fi

echo "pass"
exit 0
