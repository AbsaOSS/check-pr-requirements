#!/usr/bin/env bash
set -euo pipefail

# Validates PR source branch name against a pattern.
# Inputs via env vars:
#   INPUT_PR_BRANCH             - Branch name to validate (required)
#   INPUT_BRANCH_PATTERN        - Full regex override (default: standard prefixes)
#   INPUT_BRANCH_REQUIRE_TICKET - Require ticket after prefix (default: false)
#   INPUT_BRANCH_TICKET_PATTERN - Regex the branch must match when a ticket is
#                                 required (default: ^[^/]+/[0-9]+- , i.e. a
#                                 numeric ticket like feature/123-user-login)

DEFAULT_PATTERN='^(feature|bugfix|hotfix|release|support|chore|docs|ci|dependabot)/[a-zA-Z0-9._/-]+$'

BRANCH="${INPUT_PR_BRANCH:?PR branch name is required}"
REQUIRE_TICKET="${INPUT_BRANCH_REQUIRE_TICKET:-false}"

PATTERN="${INPUT_BRANCH_PATTERN:-$DEFAULT_PATTERN}"

if [[ ! "$BRANCH" =~ $PATTERN ]]; then
    echo "fail: branch name '$BRANCH' does not match pattern '$PATTERN'"
    exit 1
fi

TICKET_PATTERN="${INPUT_BRANCH_TICKET_PATTERN:-^[^/]+/[0-9]+-}"
if [[ "$REQUIRE_TICKET" == "true" ]] && [[ ! "$BRANCH" =~ $TICKET_PATTERN ]]; then
    echo "fail: branch name '$BRANCH' must include a ticket after the prefix (expected pattern '$TICKET_PATTERN', e.g. feature/123-user-login)"
    exit 1
fi

echo "pass"
exit 0
