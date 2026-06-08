#!/usr/bin/env bash
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/test_helpers.sh"
CHECK="${SCRIPT_DIR}/../checks/target_branch.sh"

# ── Pass cases ───────────────────────────────────────────────────────────────

INPUT_ALLOWED_TARGET_BRANCHES="" \
INPUT_TARGET_BRANCH="main" \
    assert_pass "targets main" "$CHECK"

INPUT_ALLOWED_TARGET_BRANCHES="" \
INPUT_TARGET_BRANCH="master" \
    assert_pass "targets master" "$CHECK"

INPUT_TARGET_BRANCH="develop" INPUT_ALLOWED_TARGET_BRANCHES="main,develop" \
    assert_pass "custom allowed branch" "$CHECK"

# ── Fail cases ───────────────────────────────────────────────────────────────

INPUT_ALLOWED_TARGET_BRANCHES="" \
INPUT_TARGET_BRANCH="develop" \
    assert_fail "targets develop (not allowed by default)" "$CHECK"

INPUT_ALLOWED_TARGET_BRANCHES="" \
INPUT_TARGET_BRANCH="feature/something" \
    assert_fail "targets feature branch" "$CHECK"

INPUT_TARGET_BRANCH="main" INPUT_ALLOWED_TARGET_BRANCHES="develop,staging" \
    assert_fail "main not in custom list" "$CHECK"

print_results "target_branch" || exit 1
