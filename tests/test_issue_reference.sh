#!/usr/bin/env bash
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/test_helpers.sh"
CHECK="${SCRIPT_DIR}/../checks/issue_reference.sh"

# ── Pass cases ───────────────────────────────────────────────────────────────

INPUT_PR_BODY="" \
INPUT_PR_TITLE="feat: add feature #123" \
    assert_pass "hash ref in title" "$CHECK"

INPUT_PR_TITLE="" \
INPUT_PR_BODY="Fixes #42" \
    assert_pass "Fixes keyword" "$CHECK"

INPUT_PR_TITLE="" \
INPUT_PR_BODY="closes #99" \
    assert_pass "closes keyword lowercase" "$CHECK"

INPUT_PR_TITLE="" \
INPUT_PR_BODY="Resolves #100" \
    assert_pass "Resolves keyword" "$CHECK"

INPUT_PR_TITLE="" \
INPUT_PR_BODY="See https://github.com/org/repo/issues/55" \
    assert_pass "GitHub issue URL" "$CHECK"

INPUT_PR_TITLE="" \
INPUT_PR_BODY="Related to #1 and #2" \
    assert_pass "multiple refs" "$CHECK"

# ── Fail cases ───────────────────────────────────────────────────────────────

INPUT_PR_TITLE="feat: add login" INPUT_PR_BODY="No issue here" \
    assert_fail "no reference" "$CHECK"

INPUT_PR_TITLE="" INPUT_PR_BODY="" \
    assert_fail "empty inputs" "$CHECK"

INPUT_PR_TITLE="add feature" INPUT_PR_BODY="This is about numbers like 42" \
    assert_fail "number without hash" "$CHECK"

# ── Edge cases ───────────────────────────────────────────────────────────────

INPUT_PR_TITLE="" \
INPUT_PR_BODY="$(printf 'First line\nFixes #42\nLast line')" \
    assert_pass "issue ref on middle line" "$CHECK"

INPUT_PR_TITLE="feat: add feature" \
INPUT_PR_BODY="Ref #0" \
    assert_pass "issue number zero" "$CHECK"

INPUT_PR_TITLE="" \
INPUT_PR_BODY="fixed #42" \
    assert_pass "fixed keyword" "$CHECK"

INPUT_PR_TITLE="" \
INPUT_PR_BODY="closed #42" \
    assert_pass "closed keyword" "$CHECK"

# ── Azure Boards references ──────────────────────────────────────────────────

INPUT_PR_TITLE="" \
INPUT_PR_BODY="Close AB#12345" \
    assert_pass "Azure Boards keyword reference" "$CHECK"

INPUT_PR_TITLE="" \
INPUT_PR_BODY="Related to AB#12345" \
    assert_pass "Azure Boards bare reference" "$CHECK"

# ── Keyword requirement ──────────────────────────────────────────────────────

INPUT_ISSUE_REFERENCE_REQUIRE_KEYWORD="true" \
INPUT_PR_TITLE="" INPUT_PR_BODY="Fixes #42" \
    assert_pass "keyword required: Fixes #42" "$CHECK"

INPUT_ISSUE_REFERENCE_REQUIRE_KEYWORD="true" \
INPUT_PR_TITLE="" INPUT_PR_BODY="Closes AB#12345" \
    assert_pass "keyword required: Closes AB#12345" "$CHECK"

INPUT_ISSUE_REFERENCE_REQUIRE_KEYWORD="true" \
INPUT_PR_TITLE="" INPUT_PR_BODY="Resolves https://github.com/org/repo/issues/55" \
    assert_pass "keyword required: keyword with issue URL" "$CHECK"

INPUT_ISSUE_REFERENCE_REQUIRE_KEYWORD="true" \
INPUT_PR_TITLE="" INPUT_PR_BODY="Related to #42" \
    assert_fail "keyword required: bare hash reference rejected" "$CHECK"

INPUT_ISSUE_REFERENCE_REQUIRE_KEYWORD="true" \
INPUT_PR_TITLE="" INPUT_PR_BODY="See https://github.com/org/repo/issues/55" \
    assert_fail "keyword required: bare URL rejected" "$CHECK"

print_results "issue_reference" || exit 1
