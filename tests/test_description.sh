#!/usr/bin/env bash
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/test_helpers.sh"
CHECK="${SCRIPT_DIR}/../checks/description.sh"

# ── Pass cases ───────────────────────────────────────────────────────────────

INPUT_DESCRIPTION_MIN_LENGTH="" \
INPUT_PR_BODY="This is a valid PR description with enough content." \
    assert_pass "valid description" "$CHECK"

INPUT_PR_BODY="Short but enough text here" INPUT_DESCRIPTION_MIN_LENGTH="10" \
    assert_pass "meets custom min length" "$CHECK"

INPUT_DESCRIPTION_MIN_LENGTH="" \
INPUT_PR_BODY="$(printf '%0.s-' {1..100})" \
    assert_pass "long description" "$CHECK"

# ── Fail cases ───────────────────────────────────────────────────────────────

INPUT_DESCRIPTION_MIN_LENGTH="" \
INPUT_PR_BODY="" \
    assert_fail "empty body" "$CHECK"

INPUT_DESCRIPTION_MIN_LENGTH="" \
INPUT_PR_BODY="Too short" \
    assert_fail "below default min length" "$CHECK"

INPUT_PR_BODY="abc" INPUT_DESCRIPTION_MIN_LENGTH="10" \
    assert_fail "below custom min length" "$CHECK"

INPUT_DESCRIPTION_MIN_LENGTH="" \
INPUT_PR_BODY="   " \
    assert_fail "whitespace only" "$CHECK"

# ── Edge cases ───────────────────────────────────────────────────────────────

INPUT_DESCRIPTION_MIN_LENGTH="" \
INPUT_PR_BODY="$(printf '\n\n\n\n')" \
    assert_fail "only newlines" "$CHECK"

INPUT_DESCRIPTION_MIN_LENGTH="" \
INPUT_PR_BODY="$(printf '\n\n\nActual content here that is long enough\n\n')" \
    assert_pass "content with surrounding newlines" "$CHECK"

INPUT_DESCRIPTION_MIN_LENGTH="" \
INPUT_PR_BODY="This has pipes | in | it and that is fine for description" \
    assert_pass "body with pipe characters" "$CHECK"

INPUT_DESCRIPTION_MIN_LENGTH="1" \
INPUT_PR_BODY="x" \
    assert_pass "minimum length of 1" "$CHECK"

INPUT_DESCRIPTION_MIN_LENGTH="1" \
INPUT_PR_BODY="-n" \
    assert_pass "body that looks like an echo flag" "$CHECK"

INPUT_DESCRIPTION_MIN_LENGTH="6" \
INPUT_PR_BODY="$(printf '\n\n\nshort\n\n')" \
    assert_fail "surrounding newlines do not count toward length" "$CHECK"

print_results "description" || exit 1
