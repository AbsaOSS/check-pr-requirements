#!/usr/bin/env bash
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHECKS_DIR="${SCRIPT_DIR}/checks"

set_output() {
    local name="$1" value="$2"
    local delimiter="ghadelimiter_${RANDOM}${RANDOM}${RANDOM}"
    # Regenerate on the off chance the value contains the delimiter line
    while [[ "$value" == *"$delimiter"* ]]; do
        delimiter="ghadelimiter_${RANDOM}${RANDOM}${RANDOM}"
    done
    {
        echo "${name}<<${delimiter}"
        echo "${value}"
        echo "${delimiter}"
    } >> "${GITHUB_OUTPUT:-/dev/null}"
}

# ── Check Registry ──────────────────────────────────────────────────────────
# Format: "env_toggle|default|display_name|script_name"
# To add a new check: append an entry here and create the script in checks/
REGISTRY=(
    "INPUT_CHECK_TITLE|true|PR Title (Conventional Commits)|title_conventional.sh"
    "INPUT_CHECK_DESCRIPTION|true|PR Description|description.sh"
    "INPUT_CHECK_ISSUE_REFERENCE|true|Issue Reference|issue_reference.sh"
    "INPUT_CHECK_BRANCH_NAME|false|Branch Name|branch_name.sh"
    "INPUT_CHECK_PR_SIZE|false|PR Size|pr_size.sh"
    "INPUT_CHECK_LABEL|false|Label Presence|label_presence.sh"
    "INPUT_CHECK_TARGET_BRANCH|false|Target Branch|target_branch.sh"
)

# ── Runner ───────────────────────────────────────────────────────────────────
declare -a CHECK_NAMES=()
declare -a CHECK_RESULTS=()
declare -a CHECK_MESSAGES=()
FAIL_COUNT=0
PASS_COUNT=0
WARN_COUNT=0
WARN_CHECKS="${INPUT_WARN_CHECKS:-}"

csv_contains_ignore_case() {
    local needle="$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')" item
    while IFS= read -r item; do
        item="$(printf '%s' "$item" | tr -d '[:space:]' | tr '[:upper:]' '[:lower:]')"
        [[ "$item" == "$needle" ]] && return 0
    done < <(printf '%s\n' "$2" | tr ',' '\n')
    return 1
}

record_result() {
    local name="$1" result="$2" message="$3"
    CHECK_NAMES+=("$name")
    CHECK_RESULTS+=("$result")
    CHECK_MESSAGES+=("$message")
    case "$result" in
        pass) ((PASS_COUNT++)) ;;
        warn) ((WARN_COUNT++)) ;;
        *) ((FAIL_COUNT++)) ;;
    esac
}

run_check() {
    local name="$1" check_id="$3"
    local script="${CHECKS_DIR}/$2"

    if [[ ! -f "$script" ]]; then
        CHECK_NAMES+=("$name")
        CHECK_RESULTS+=("error")
        CHECK_MESSAGES+=("check script not found: $script")
        ((FAIL_COUNT++))
        return
    fi

    local output exit_code
    output=$(bash "$script" 2>&1)
    exit_code=$?

    if [[ "$exit_code" -eq 0 ]]; then
        record_result "$name" "pass" "$output"
    elif csv_contains_ignore_case "$check_id" "$WARN_CHECKS"; then
        record_result "$name" "warn" "$output"
    else
        record_result "$name" "fail" "$output"
    fi
}

known_check_ids=""
for entry in "${REGISTRY[@]}"; do
    IFS='|' read -r env_var _ _ _ <<< "$entry"
    known_check_ids+="${env_var#INPUT_CHECK_},"
done
for warn_check in $(printf '%s' "$WARN_CHECKS" | tr ',' ' '); do
    if ! csv_contains_ignore_case "$warn_check" "$known_check_ids"; then
        record_result "Warn Checks" "error" "config error: unknown check '${warn_check}' in input 'warn-checks'"
    fi
done

for entry in "${REGISTRY[@]}"; do
    IFS='|' read -r env_var default display_name script_name <<< "$entry"
    enabled="${!env_var:-$default}"
    if [[ "$enabled" == "true" ]]; then
        check_id="$(printf '%s' "${env_var#INPUT_CHECK_}" | tr '[:upper:]' '[:lower:]' | tr '_' '-')"
        run_check "$display_name" "$script_name" "$check_id"
    fi
done

# ── Summary ──────────────────────────────────────────────────────────────────
TOTAL=$((PASS_COUNT + FAIL_COUNT + WARN_COUNT))

{
    echo "## PR Requirements Check"
    echo ""
    echo "| Check | Status | Details |"
    echo "|-------|--------|---------|"

    for i in "${!CHECK_NAMES[@]}"; do
        if [[ "${CHECK_RESULTS[$i]}" == "pass" ]]; then
            echo "| ${CHECK_NAMES[$i]} | ✅ Pass | - |"
        else
            case "${CHECK_RESULTS[$i]}" in
                warn) status="🟡 Warning" ;;
                error) status="⚠️ Error" ;;
                *) status="❌ Fail" ;;
            esac
            # Render PR-controlled text as an inert code span: strip backticks,
            # flatten newlines, escape table pipes
            detail="${CHECK_MESSAGES[$i]#fail: }"
            detail=$(printf '%s' "$detail" | tr '\n' ' ' | tr -d '`' | sed 's/|/\\|/g')
            if [[ -z "$detail" ]]; then
                detail="-"
            else
                detail="\`${detail}\`"
            fi
            echo "| ${CHECK_NAMES[$i]} | ${status} | ${detail} |"
        fi
    done

    echo ""
    echo "**Result:** ${PASS_COUNT}/${TOTAL} checks passed"
} >> "${GITHUB_STEP_SUMMARY:-/dev/null}"

if [[ "$FAIL_COUNT" -eq 0 ]]; then
    RESULT="pass"
else
    RESULT="fail"
fi
set_output "result" "$RESULT"
set_output "pass-count" "$PASS_COUNT"
set_output "fail-count" "$FAIL_COUNT"
set_output "warn-count" "$WARN_COUNT"
set_output "total-count" "$TOTAL"

# CLI output
echo ""
echo "PR Requirements: ${PASS_COUNT}/${TOTAL} passed"
for i in "${!CHECK_NAMES[@]}"; do
    if [[ "${CHECK_RESULTS[$i]}" == "pass" ]]; then
        echo "  ✅ ${CHECK_NAMES[$i]}"
    else
        case "${CHECK_RESULTS[$i]}" in
            warn) echo "  🟡 ${CHECK_NAMES[$i]}: ${CHECK_MESSAGES[$i]}" ;;
            error) echo "  ⚠️ ${CHECK_NAMES[$i]}: ${CHECK_MESSAGES[$i]}" ;;
            *) echo "  ❌ ${CHECK_NAMES[$i]}: ${CHECK_MESSAGES[$i]}" ;;
        esac
    fi
done

if [[ "$FAIL_COUNT" -gt 0 ]]; then
    exit 1
fi
exit 0
