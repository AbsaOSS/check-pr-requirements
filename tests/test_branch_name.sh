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

INPUT_BRANCH_PATTERN="" \
INPUT_PR_BRANCH="support/1.0.4" \
    assert_pass "support branch" "$CHECK"

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

# ── Ticket number requirement ────────────────────────────────────────────────

INPUT_BRANCH_PATTERN="" INPUT_BRANCH_REQUIRE_TICKET="true" \
INPUT_PR_BRANCH="feature/123-user-login" \
    assert_pass "ticket required and present" "$CHECK"

INPUT_BRANCH_PATTERN="" INPUT_BRANCH_REQUIRE_TICKET="true" \
INPUT_PR_BRANCH="feature/user-login" \
    assert_fail "ticket required but missing" "$CHECK"

INPUT_BRANCH_PATTERN="" INPUT_BRANCH_REQUIRE_TICKET="true" \
INPUT_PR_BRANCH="bugfix/124-login-error" \
    assert_pass "ticket required on bugfix branch" "$CHECK"

INPUT_BRANCH_PATTERN="" INPUT_BRANCH_REQUIRE_TICKET="false" \
INPUT_PR_BRANCH="feature/user-login" \
    assert_pass "ticket not required" "$CHECK"

# ── branch-prefixes override (#26) ───────────────────────────────────────────

INPUT_BRANCH_PREFIXES="feature,bugfix" \
INPUT_PR_BRANCH="feature/add-login" \
    assert_pass "prefixes: allowed prefix passes" "$CHECK"

INPUT_BRANCH_PREFIXES="feature,bugfix" \
INPUT_PR_BRANCH="hotfix/oops" \
    assert_fail "prefixes: prefix not in list fails" "$CHECK"

# Whitespace around prefixes is trimmed
INPUT_BRANCH_PREFIXES=" feature , epic " \
INPUT_PR_BRANCH="epic/big-thing" \
    assert_pass "prefixes: whitespace trimmed" "$CHECK"

# branch-prefixes takes precedence over branch-pattern
INPUT_BRANCH_PREFIXES="wip" INPUT_BRANCH_PATTERN="^never-matches$" \
INPUT_PR_BRANCH="wip/experiment" \
    assert_pass "prefixes: precedence over branch-pattern" "$CHECK"

# ── branch-ticket-pattern override (#27) ─────────────────────────────────────

INPUT_BRANCH_REQUIRE_TICKET="true" \
INPUT_BRANCH_PREFIXES="feature" \
INPUT_BRANCH_TICKET_PATTERN="^[^/]+/[A-Z]+-[0-9]+-" \
INPUT_PR_BRANCH="feature/PROJ-123-user-login" \
    assert_pass "ticket pattern: non-numeric scheme passes" "$CHECK"

INPUT_BRANCH_REQUIRE_TICKET="true" \
INPUT_BRANCH_PREFIXES="feature" \
INPUT_BRANCH_TICKET_PATTERN="^[^/]+/[A-Z]+-[0-9]+-" \
INPUT_PR_BRANCH="feature/123-user-login" \
    assert_fail "ticket pattern: numeric fails custom scheme" "$CHECK"

INPUT_BRANCH_REQUIRE_TICKET="true" \
INPUT_BRANCH_PREFIXES="feature" \
INPUT_BRANCH_TICKET_PATTERN="" \
INPUT_PR_BRANCH="feature/123-user-login" \
    assert_pass "ticket pattern: default numeric still works" "$CHECK"

print_results "branch_name" || exit 1
