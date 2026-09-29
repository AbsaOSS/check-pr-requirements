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

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib.sh"

BRANCH="${INPUT_PR_BRANCH:-}"
require_pr_data "$BRANCH" "pr-branch"
REQUIRE_TICKET="${INPUT_BRANCH_REQUIRE_TICKET:-false}"

PATTERN="${INPUT_BRANCH_PATTERN:-$DEFAULT_BRANCH_PATTERN}"
TICKET_PATTERN="${INPUT_BRANCH_TICKET_PATTERN:-$DEFAULT_BRANCH_TICKET_PATTERN}"
require_valid_regex "$PATTERN" "branch-pattern"
require_valid_regex "$TICKET_PATTERN" "branch-ticket-pattern"

if [[ ! "$BRANCH" =~ $PATTERN ]]; then
    echo "fail: branch name '$BRANCH' does not match pattern '$PATTERN'"
    exit 1
fi

if is_true "$REQUIRE_TICKET" "branch-require-ticket" && [[ ! "$BRANCH" =~ $TICKET_PATTERN ]]; then
    echo "fail: branch name '$BRANCH' must include a ticket after the prefix (expected pattern '$TICKET_PATTERN', e.g. feature/123-user-login)"
    exit 1
fi

echo "pass"
exit 0
