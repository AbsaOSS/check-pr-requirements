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

INPUT_FILES_CHANGED="" INPUT_MAX_FILES_CHANGED="" \
    assert_output_contains "missing files-changed names the input" "$CHECK" "input 'files-changed' is empty"

# ── Line limit ───────────────────────────────────────────────────────────────

INPUT_FILES_CHANGED="3" INPUT_ADDITIONS="4000" INPUT_DELETIONS="1000" \
    assert_pass "lines ignored without max-lines-changed" "$CHECK"

INPUT_FILES_CHANGED="3" INPUT_ADDITIONS="300" INPUT_DELETIONS="200" INPUT_MAX_LINES_CHANGED="500" \
    assert_pass "lines exactly at limit" "$CHECK"

INPUT_FILES_CHANGED="3" INPUT_ADDITIONS="301" INPUT_DELETIONS="200" INPUT_MAX_LINES_CHANGED="500" \
    assert_output_contains "lines over limit" "$CHECK" "PR changes 501 lines (maximum 500)"

INPUT_FILES_CHANGED="60" INPUT_ADDITIONS="600" INPUT_DELETIONS="0" INPUT_MAX_LINES_CHANGED="500" \
    assert_output_contains "both limits reported" "$CHECK" "60 files (maximum 50); PR changes 600 lines"

INPUT_FILES_CHANGED="3" INPUT_MAX_LINES_CHANGED="500" \
    assert_output_contains "missing additions names the input" "$CHECK" "input 'additions' is empty"

INPUT_FILES_CHANGED="3" INPUT_ADDITIONS="1" INPUT_DELETIONS="1" INPUT_MAX_LINES_CHANGED="lots" \
    assert_output_contains "non-numeric line limit is a config error" "$CHECK" "config error: input 'max-lines-changed'"

print_results "pr_size" || exit 1
