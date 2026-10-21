#!/usr/bin/env bash
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/test_helpers.sh"
CHECK="${SCRIPT_DIR}/../checks/release_notes.sh"

INPUT_RELEASE_NOTES_OUTCOME="success" \
    assert_pass "successful release notes step" "$CHECK"

INPUT_RELEASE_NOTES_OUTCOME="failure" \
    assert_output_contains "failed release notes step" "$CHECK" "release notes are missing"

INPUT_RELEASE_NOTES_OUTCOME="" \
    assert_output_contains "release notes step did not run" "$CHECK" "result unavailable"

print_results "release_notes" || exit 1
