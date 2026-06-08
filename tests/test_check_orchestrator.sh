#!/usr/bin/env bash
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/test_helpers.sh"
CHECK="${SCRIPT_DIR}/../check.sh"

export GITHUB_STEP_SUMMARY="/dev/null"
export GITHUB_OUTPUT="/dev/null"

# Helper: sets INPUT_ vars, runs check.sh, cleans up
run_orchestrator() {
    local expected="$1"
    local description="$2"
    shift 2

    # Export all provided vars
    for assignment in "$@"; do
        export "$assignment"
    done

    if [[ "$expected" == "pass" ]]; then
        assert_pass "$description" "$CHECK"
    elif [[ "$expected" == "fail" ]]; then
        assert_fail "$description" "$CHECK"
    elif [[ "$expected" == "contains:"* ]]; then
        local needle="${expected#contains:}"
        assert_output_contains "$description" "$CHECK" "$needle"
    fi

    # Cleanup exported vars
    for assignment in "$@"; do
        unset "${assignment%%=*}"
    done
}

# ── Test Cases ───────────────────────────────────────────────────────────────

DEFAULTS=(
    "INPUT_CHECK_BRANCH_NAME=false"
    "INPUT_CHECK_PR_SIZE=false"
    "INPUT_CHECK_LABEL=false"
    "INPUT_CHECK_TARGET_BRANCH=false"
    "INPUT_TITLE_TYPES="
    "INPUT_TITLE_SCOPES="
    "INPUT_DESCRIPTION_MIN_LENGTH="
)

run_orchestrator pass "all default checks pass" \
    "INPUT_PR_TITLE=feat: add login #1" \
    "INPUT_PR_BODY=This is a valid description that references issue #42 for tracking" \
    "INPUT_CHECK_TITLE=true" "INPUT_CHECK_DESCRIPTION=true" "INPUT_CHECK_ISSUE_REFERENCE=true" \
    "${DEFAULTS[@]}"

run_orchestrator fail "fails when title invalid" \
    "INPUT_PR_TITLE=bad title" \
    "INPUT_PR_BODY=This is a valid description that references issue #42 for tracking" \
    "INPUT_CHECK_TITLE=true" "INPUT_CHECK_DESCRIPTION=true" "INPUT_CHECK_ISSUE_REFERENCE=true" \
    "${DEFAULTS[@]}"

run_orchestrator pass "all checks disabled = pass" \
    "INPUT_PR_TITLE=bad title" \
    "INPUT_PR_BODY=" \
    "INPUT_CHECK_TITLE=false" "INPUT_CHECK_DESCRIPTION=false" "INPUT_CHECK_ISSUE_REFERENCE=false" \
    "${DEFAULTS[@]}"

run_orchestrator "contains:PR Title" "output lists PR Title check" \
    "INPUT_PR_TITLE=feat: something #1" \
    "INPUT_PR_BODY=Valid body with enough content for the check" \
    "INPUT_CHECK_TITLE=true" "INPUT_CHECK_DESCRIPTION=true" "INPUT_CHECK_ISSUE_REFERENCE=true" \
    "${DEFAULTS[@]}"

run_orchestrator fail "multiple checks fail" \
    "INPUT_PR_TITLE=bad" \
    "INPUT_PR_BODY=" \
    "INPUT_CHECK_TITLE=true" "INPUT_CHECK_DESCRIPTION=true" "INPUT_CHECK_ISSUE_REFERENCE=true" \
    "${DEFAULTS[@]}"

run_orchestrator pass "optional checks enabled and pass" \
    "INPUT_PR_TITLE=feat: add feature #1" \
    "INPUT_PR_BODY=Valid description with enough content here" \
    "INPUT_CHECK_TITLE=true" "INPUT_CHECK_DESCRIPTION=true" "INPUT_CHECK_ISSUE_REFERENCE=true" \
    "INPUT_CHECK_BRANCH_NAME=true" "INPUT_PR_BRANCH=feature/add-login" \
    "INPUT_CHECK_TARGET_BRANCH=true" "INPUT_TARGET_BRANCH=main" \
    "INPUT_CHECK_PR_SIZE=true" "INPUT_FILES_CHANGED=5" "INPUT_MAX_FILES_CHANGED=" \
    "INPUT_CHECK_LABEL=false" \
    "INPUT_TITLE_TYPES=" "INPUT_TITLE_SCOPES=" "INPUT_DESCRIPTION_MIN_LENGTH=" \
    "INPUT_BRANCH_PATTERN=" "INPUT_ALLOWED_TARGET_BRANCHES="

print_results "check_orchestrator" || exit 1
