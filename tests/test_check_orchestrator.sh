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

# ── Summary / output sanitization ───────────────────────────────────────────

run_sanitization_case() {
    local description="$1" check_fn="$2"

    ((TESTS_TOTAL++))
    local summary_file output_file
    summary_file="$(mktemp)"
    output_file="$(mktemp)"

    env -i PATH="$PATH" HOME="$HOME" \
        GITHUB_STEP_SUMMARY="$summary_file" GITHUB_OUTPUT="$output_file" \
        INPUT_PR_TITLE='bad `title` with [link](https://evil.example) and |pipe' \
        INPUT_CHECK_TITLE=true INPUT_CHECK_DESCRIPTION=false \
        INPUT_CHECK_ISSUE_REFERENCE=false INPUT_CHECK_BRANCH_NAME=false \
        INPUT_CHECK_PR_SIZE=false INPUT_CHECK_LABEL=false \
        INPUT_CHECK_TARGET_BRANCH=false \
        bash "$CHECK" >/dev/null 2>&1

    if "$check_fn" "$summary_file" "$output_file"; then
        echo "  ✅ ${description}"
        ((TESTS_PASSED++))
    else
        echo "  ❌ ${description}"
        ((TESTS_FAILED++))
    fi
    rm -f "$summary_file" "$output_file"
}

check_pipes_escaped() {
    grep -qF 'and \|pipe' "$1"
}

check_backticks_stripped() {
    ! grep -qF '`title`' "$1"
}

check_detail_is_code_span() {
    grep -qF '❌ Fail | `' "$1"
}

check_output_delimiter() {
    grep -qE '^result<<ghadelimiter_[0-9]+$' "$2" && grep -qx 'fail' "$2"
}

run_sanitization_case "summary escapes table pipes" check_pipes_escaped
run_sanitization_case "summary strips backticks from details" check_backticks_stripped
run_sanitization_case "summary wraps details in code span" check_detail_is_code_span
run_sanitization_case "GITHUB_OUTPUT uses random delimiter heredoc" check_output_delimiter

print_results "check_orchestrator" || exit 1
