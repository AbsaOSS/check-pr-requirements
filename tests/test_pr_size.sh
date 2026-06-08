#!/usr/bin/env bash
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/test_helpers.sh"
CHECK="${SCRIPT_DIR}/../checks/pr_size.sh"

# ── Pass cases ───────────────────────────────────────────────────────────────

INPUT_MAX_FILES_CHANGED="" \
INPUT_FILES_CHANGED="5" \
    assert_pass "small PR" "$CHECK"

INPUT_MAX_FILES_CHANGED="" \
INPUT_FILES_CHANGED="50" \
    assert_pass "exactly at limit" "$CHECK"

INPUT_FILES_CHANGED="10" INPUT_MAX_FILES_CHANGED="100" \
    assert_pass "custom limit" "$CHECK"

INPUT_MAX_FILES_CHANGED="" \
INPUT_FILES_CHANGED="0" \
    assert_pass "zero files" "$CHECK"

# ── Fail cases ───────────────────────────────────────────────────────────────

INPUT_MAX_FILES_CHANGED="" \
INPUT_FILES_CHANGED="51" \
    assert_fail "over default limit" "$CHECK"

INPUT_FILES_CHANGED="11" INPUT_MAX_FILES_CHANGED="10" \
    assert_fail "over custom limit" "$CHECK"

INPUT_MAX_FILES_CHANGED="" \
INPUT_FILES_CHANGED="999" \
    assert_fail "way over limit" "$CHECK"

print_results "pr_size" || exit 1
