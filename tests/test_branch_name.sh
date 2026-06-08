#!/usr/bin/env bash
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/test_helpers.sh"
CHECK="${SCRIPT_DIR}/../checks/branch_name.sh"

# ── Pass cases ───────────────────────────────────────────────────────────────

INPUT_BRANCH_PATTERN="" \
INPUT_PR_BRANCH="feature/add-login" \
    assert_pass "feature branch" "$CHECK"

INPUT_BRANCH_PATTERN="" \
INPUT_PR_BRANCH="bugfix/fix-auth" \
    assert_pass "bugfix branch" "$CHECK"

INPUT_BRANCH_PATTERN="" \
INPUT_PR_BRANCH="hotfix/critical-fix" \
    assert_pass "hotfix branch" "$CHECK"

INPUT_BRANCH_PATTERN="" \
INPUT_PR_BRANCH="release/v1.2.0" \
    assert_pass "release branch" "$CHECK"

INPUT_BRANCH_PATTERN="" \
INPUT_PR_BRANCH="chore/update-deps" \
    assert_pass "chore branch" "$CHECK"

INPUT_BRANCH_PATTERN="" \
INPUT_PR_BRANCH="dependabot/npm-updates" \
    assert_pass "dependabot branch" "$CHECK"

# ── Fail cases ───────────────────────────────────────────────────────────────

INPUT_BRANCH_PATTERN="" \
INPUT_PR_BRANCH="my-branch" \
    assert_fail "no prefix" "$CHECK"

INPUT_BRANCH_PATTERN="" \
INPUT_PR_BRANCH="FEATURE/something" \
    assert_fail "uppercase prefix" "$CHECK"

INPUT_BRANCH_PATTERN="" \
INPUT_PR_BRANCH="feature/" \
    assert_fail "empty name after prefix" "$CHECK"

# ── Custom pattern ───────────────────────────────────────────────────────────

INPUT_PR_BRANCH="PROJ-123-add-thing" INPUT_BRANCH_PATTERN="^[A-Z]+-[0-9]+-.*$" \
    assert_pass "custom JIRA pattern" "$CHECK"

INPUT_PR_BRANCH="feature/add-thing" INPUT_BRANCH_PATTERN="^[A-Z]+-[0-9]+-.*$" \
    assert_fail "default name vs custom pattern" "$CHECK"

print_results "branch_name" || exit 1
