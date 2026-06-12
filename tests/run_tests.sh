#!/usr/bin/env bash
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TESTS_DIR="$SCRIPT_DIR"

FAILED_FILES=()

# ── Test Registry ────────────────────────────────────────────────────────────
# To add tests for a new check: create test_<name>.sh and append here
TEST_FILES=(
    "test_title_conventional.sh"
    "test_description.sh"
    "test_issue_reference.sh"
    "test_branch_name.sh"
    "test_pr_size.sh"
    "test_label_presence.sh"
    "test_target_branch.sh"
    "test_check_orchestrator.sh"
)

run_test_file() {
    local test_file="$1"
    local path="${TESTS_DIR}/${test_file}"

    if [[ ! -f "$path" ]]; then
        echo "  ⚠️  Test file not found: ${test_file}"
        FAILED_FILES+=("${test_file} (not found)")
        return
    fi

    echo ""
    echo "━━━ ${test_file} ━━━"
    if ! bash "$path"; then
        FAILED_FILES+=("$test_file")
    fi
}

for test_file in "${TEST_FILES[@]}"; do
    run_test_file "$test_file"
done

echo ""
echo "═══════════════════════════════════════"
if [[ ${#FAILED_FILES[@]} -gt 0 ]]; then
    echo "Test run FAILED: ${FAILED_FILES[*]}"
    exit 1
fi
echo "Test run complete: all test files passed"
