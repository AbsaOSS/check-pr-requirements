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
        export "${assignment?}"
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

# ── Actor and label bypass ───────────────────────────────────────────────────

# Author in skip-actors → all checks skipped, pass despite an invalid title/body
run_orchestrator pass "skip-actors bypasses checks for matching author" \
    "INPUT_PR_TITLE=Bump actions/checkout from 3 to 4" \
    "INPUT_PR_BODY=" \
    "INPUT_PR_AUTHOR=dependabot[bot]" "INPUT_SKIP_ACTORS=dependabot[bot]" \
    "INPUT_CHECK_TITLE=true" "INPUT_CHECK_DESCRIPTION=true" "INPUT_CHECK_ISSUE_REFERENCE=true" \
    "${DEFAULTS[@]}"

# Author not in skip-actors → checks run normally and fail
run_orchestrator fail "non-matching author is not bypassed" \
    "INPUT_PR_TITLE=Bump actions/checkout from 3 to 4" \
    "INPUT_PR_BODY=" \
    "INPUT_PR_AUTHOR=some-human" "INPUT_SKIP_ACTORS=dependabot[bot]" \
    "INPUT_CHECK_TITLE=true" "INPUT_CHECK_DESCRIPTION=true" "INPUT_CHECK_ISSUE_REFERENCE=true" \
    "${DEFAULTS[@]}"

# Empty skip-actors → no bypass, checks run normally and fail
run_orchestrator fail "empty skip-actors disables bypass" \
    "INPUT_PR_TITLE=Bump actions/checkout from 3 to 4" \
    "INPUT_PR_BODY=" \
    "INPUT_PR_AUTHOR=dependabot[bot]" "INPUT_SKIP_ACTORS=" \
    "INPUT_CHECK_TITLE=true" "INPUT_CHECK_DESCRIPTION=true" "INPUT_CHECK_ISSUE_REFERENCE=true" \
    "${DEFAULTS[@]}"

# Multiple actors, matches a later entry (with surrounding whitespace)
run_orchestrator pass "skip-actors matches later CSV entry with spaces" \
    "INPUT_PR_TITLE=Bump actions/checkout from 3 to 4" \
    "INPUT_PR_BODY=" \
    "INPUT_PR_AUTHOR=renovate[bot]" "INPUT_SKIP_ACTORS=dependabot[bot], renovate[bot]" \
    "INPUT_CHECK_TITLE=true" "INPUT_CHECK_DESCRIPTION=true" "INPUT_CHECK_ISSUE_REFERENCE=true" \
    "${DEFAULTS[@]}"

# A PR label in skip-labels → all checks skipped despite an invalid title/body
run_orchestrator pass "skip-labels bypasses checks for matching label" \
    "INPUT_PR_TITLE=Bump actions/checkout from 3 to 4" \
    "INPUT_PR_BODY=" \
    "INPUT_LABELS=automated, skip-checks" "INPUT_SKIP_LABELS=skip-checks" \
    "INPUT_CHECK_TITLE=true" "INPUT_CHECK_DESCRIPTION=true" "INPUT_CHECK_ISSUE_REFERENCE=true" \
    "${DEFAULTS[@]}"

# PR label not in skip-labels → checks run normally and fail
run_orchestrator fail "non-matching label is not bypassed" \
    "INPUT_PR_TITLE=Bump actions/checkout from 3 to 4" \
    "INPUT_PR_BODY=" \
    "INPUT_LABELS=bug,enhancement" "INPUT_SKIP_LABELS=skip-checks" \
    "INPUT_CHECK_TITLE=true" "INPUT_CHECK_DESCRIPTION=true" "INPUT_CHECK_ISSUE_REFERENCE=true" \
    "${DEFAULTS[@]}"

# Empty skip-labels → no label bypass, checks run normally and fail
run_orchestrator fail "empty skip-labels disables label bypass" \
    "INPUT_PR_TITLE=Bump actions/checkout from 3 to 4" \
    "INPUT_PR_BODY=" \
    "INPUT_LABELS=skip-checks" "INPUT_SKIP_LABELS=" \
    "INPUT_CHECK_TITLE=true" "INPUT_CHECK_DESCRIPTION=true" "INPUT_CHECK_ISSUE_REFERENCE=true" \
    "${DEFAULTS[@]}"

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

# ── "How to fix" guidance ────────────────────────────────────────────────────
# Runs check.sh with a fully controlled env, writes the summary to a temp file,
# then asserts on its contents via the provided predicate.
run_summary_case() {
    local description="$1" check_fn="$2"
    shift 2

    ((TESTS_TOTAL++))
    local summary_file output_file
    summary_file="$(mktemp)"
    output_file="$(mktemp)"

    env -i PATH="$PATH" HOME="$HOME" \
        GITHUB_STEP_SUMMARY="$summary_file" GITHUB_OUTPUT="$output_file" \
        "$@" \
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

has_how_to_fix()   { grep -qF '### How to fix' "$1"; }
no_how_to_fix()    { ! grep -qF '### How to fix' "$1"; }
has_title_tip()    { grep -qF '**PR Title**' "$1"; }
# Tip reflects the configured input, not a hardcoded string
has_configured_types() { grep -qF 'wibble,wobble' "$1"; }
has_target_tip()   { grep -qF 'develop' "$1"; }

# Failing title check → guidance present and reflects configured title-types
run_summary_case "failure renders How to fix" has_how_to_fix \
    INPUT_PR_TITLE='added retry logic' \
    INPUT_CHECK_TITLE=true INPUT_CHECK_DESCRIPTION=false \
    INPUT_CHECK_ISSUE_REFERENCE=false INPUT_CHECK_BRANCH_NAME=false \
    INPUT_CHECK_PR_SIZE=false INPUT_CHECK_LABEL=false INPUT_CHECK_TARGET_BRANCH=false

run_summary_case "failure lists failed check tip" has_title_tip \
    INPUT_PR_TITLE='added retry logic' \
    INPUT_CHECK_TITLE=true INPUT_CHECK_DESCRIPTION=false \
    INPUT_CHECK_ISSUE_REFERENCE=false INPUT_CHECK_BRANCH_NAME=false \
    INPUT_CHECK_PR_SIZE=false INPUT_CHECK_LABEL=false INPUT_CHECK_TARGET_BRANCH=false

run_summary_case "tip reflects configured title-types" has_configured_types \
    INPUT_PR_TITLE='added retry logic' INPUT_TITLE_TYPES='wibble,wobble' \
    INPUT_CHECK_TITLE=true INPUT_CHECK_DESCRIPTION=false \
    INPUT_CHECK_ISSUE_REFERENCE=false INPUT_CHECK_BRANCH_NAME=false \
    INPUT_CHECK_PR_SIZE=false INPUT_CHECK_LABEL=false INPUT_CHECK_TARGET_BRANCH=false

run_summary_case "target-branch tip reflects allowed branches" has_target_tip \
    INPUT_PR_TITLE='feat: ok #1' INPUT_TARGET_BRANCH='feature/x' \
    INPUT_ALLOWED_TARGET_BRANCHES='develop' \
    INPUT_CHECK_TITLE=false INPUT_CHECK_DESCRIPTION=false \
    INPUT_CHECK_ISSUE_REFERENCE=false INPUT_CHECK_BRANCH_NAME=false \
    INPUT_CHECK_PR_SIZE=false INPUT_CHECK_LABEL=false INPUT_CHECK_TARGET_BRANCH=true

# Passing run → no guidance block
run_summary_case "passing run omits How to fix" no_how_to_fix \
    INPUT_PR_TITLE='feat: add login #1' \
    INPUT_PR_BODY='This is a valid description that references issue #42 for tracking' \
    INPUT_CHECK_TITLE=true INPUT_CHECK_DESCRIPTION=true \
    INPUT_CHECK_ISSUE_REFERENCE=true INPUT_CHECK_BRANCH_NAME=false \
    INPUT_CHECK_PR_SIZE=false INPUT_CHECK_LABEL=false INPUT_CHECK_TARGET_BRANCH=false \
    INPUT_TITLE_TYPES= INPUT_TITLE_SCOPES= INPUT_DESCRIPTION_MIN_LENGTH=

# ── Bypass outputs ───────────────────────────────────────────────────────────

# Predicates receive (summary_file, output_file) from run_summary_case
output_has() {
    local name="$1" expected_value="$2" output_file="$4"
    grep -A1 -E "^${name}<<" "$output_file" | grep -qx "$expected_value"
}
skipped_true()      { output_has skipped true "$@"; }
skipped_false()     { output_has skipped false "$@"; }
skip_reason_actor() { output_has skip-reason 'author dependabot\[bot\] matched skip-actors' "$@"; }
skip_reason_label() { output_has skip-reason 'label skip-checks matched skip-labels' "$@"; }

run_summary_case "bypassed run sets skipped=true" skipped_true     INPUT_PR_TITLE='Bump x' INPUT_PR_AUTHOR='dependabot[bot]' INPUT_SKIP_ACTORS='dependabot[bot]'

run_summary_case "actor bypass sets skip-reason" skip_reason_actor     INPUT_PR_TITLE='Bump x' INPUT_PR_AUTHOR='dependabot[bot]' INPUT_SKIP_ACTORS='dependabot[bot]'

run_summary_case "label bypass sets skip-reason" skip_reason_label     INPUT_PR_TITLE='Bump x' INPUT_LABELS='bug,skip-checks' INPUT_SKIP_LABELS='skip-checks'

run_summary_case "normal run sets skipped=false" skipped_false     INPUT_PR_TITLE='feat: add login #1' INPUT_CHECK_DESCRIPTION=false INPUT_CHECK_ISSUE_REFERENCE=false

print_results "check_orchestrator" || exit 1
