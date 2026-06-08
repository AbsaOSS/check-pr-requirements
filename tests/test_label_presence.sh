#!/usr/bin/env bash
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/test_helpers.sh"
CHECK="${SCRIPT_DIR}/../checks/label_presence.sh"

# ── Pass cases ───────────────────────────────────────────────────────────────

INPUT_REQUIRED_LABELS="" \
INPUT_LABELS="bug" \
    assert_pass "has one label" "$CHECK"

INPUT_REQUIRED_LABELS="" \
INPUT_LABELS="bug,enhancement" \
    assert_pass "has multiple labels" "$CHECK"

INPUT_LABELS="bug,enhancement" INPUT_REQUIRED_LABELS="bug" \
    assert_pass "has required label" "$CHECK"

INPUT_LABELS="bug,enhancement,docs" INPUT_REQUIRED_LABELS="bug,docs" \
    assert_pass "has all required labels" "$CHECK"

# ── Fail cases ───────────────────────────────────────────────────────────────

INPUT_REQUIRED_LABELS="" \
INPUT_LABELS="" \
    assert_fail "no labels" "$CHECK"

INPUT_LABELS="bug" INPUT_REQUIRED_LABELS="enhancement" \
    assert_fail "missing required label" "$CHECK"

INPUT_LABELS="bug" INPUT_REQUIRED_LABELS="bug,enhancement" \
    assert_fail "missing one of required" "$CHECK"

print_results "label_presence" || exit 1
