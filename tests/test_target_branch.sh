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

INPUT_TARGET_BRANCH="develop" INPUT_ALLOWED_TARGET_BRANCHES=" main , develop " \
    assert_pass "allowed list with surrounding whitespace" "$CHECK"

# ── Fail cases ───────────────────────────────────────────────────────────────

INPUT_ALLOWED_TARGET_BRANCHES="" \
INPUT_TARGET_BRANCH="develop" \
    assert_fail "targets develop (not allowed by default)" "$CHECK"

INPUT_ALLOWED_TARGET_BRANCHES="" \
INPUT_TARGET_BRANCH="feature/something" \
    assert_fail "targets feature branch" "$CHECK"

INPUT_TARGET_BRANCH="main" INPUT_ALLOWED_TARGET_BRANCHES="develop,staging" \
    assert_fail "main not in custom list" "$CHECK"

# ── Glob patterns ────────────────────────────────────────────────────────────

INPUT_TARGET_BRANCH="support/1.0.4" INPUT_ALLOWED_TARGET_BRANCHES="main,support/*" \
    assert_pass "glob matches support branch" "$CHECK"

INPUT_TARGET_BRANCH="release/v2.0" INPUT_ALLOWED_TARGET_BRANCHES="main,release/*" \
    assert_pass "glob matches release branch" "$CHECK"

INPUT_TARGET_BRANCH="develop" INPUT_ALLOWED_TARGET_BRANCHES="main,support/*" \
    assert_fail "glob does not match unrelated branch" "$CHECK"

INPUT_TARGET_BRANCH="support" INPUT_ALLOWED_TARGET_BRANCHES="support/*" \
    assert_fail "glob requires the slash" "$CHECK"

print_results "target_branch" || exit 1
