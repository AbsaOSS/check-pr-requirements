#!/usr/bin/env bash
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TESTS_DIR="$SCRIPT_DIR"

TOTAL=0
PASSED=0
FAILED=0
ERRORS=()

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
        return
    fi

    echo ""
    echo "━━━ ${test_file} ━━━"
    bash "$path"
}

for test_file in "${TEST_FILES[@]}"; do
    run_test_file "$test_file"
done

echo ""
echo "═══════════════════════════════════════"
echo "Test run complete"
