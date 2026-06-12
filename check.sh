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
    "INPUT_CHECK_TITLE|true|PR Title|title_format.sh"
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

run_check() {
    local name="$1"
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

    CHECK_NAMES+=("$name")

    if [[ "$exit_code" -eq 0 ]]; then
        CHECK_RESULTS+=("pass")
        CHECK_MESSAGES+=("$output")
        ((PASS_COUNT++))
    else
        CHECK_RESULTS+=("fail")
        CHECK_MESSAGES+=("$output")
        ((FAIL_COUNT++))
    fi
}

for entry in "${REGISTRY[@]}"; do
    IFS='|' read -r env_var default display_name script_name <<< "$entry"
    enabled="${!env_var:-$default}"
    if [[ "$enabled" == "true" ]]; then
        run_check "$display_name" "$script_name"
    fi
done

# ── Summary ──────────────────────────────────────────────────────────────────
TOTAL=$((PASS_COUNT + FAIL_COUNT))

{
    echo "## PR Requirements Check"
    echo ""
    echo "| Check | Status | Details |"
    echo "|-------|--------|---------|"

    for i in "${!CHECK_NAMES[@]}"; do
        if [[ "${CHECK_RESULTS[$i]}" == "pass" ]]; then
            echo "| ${CHECK_NAMES[$i]} | ✅ Pass | - |"
        else
            # Render PR-controlled text as an inert code span: strip backticks,
            # flatten newlines, escape table pipes
            detail="${CHECK_MESSAGES[$i]#fail: }"
            detail=$(printf '%s' "$detail" | tr '\n' ' ' | tr -d '`' | sed 's/|/\\|/g')
            if [[ -z "$detail" ]]; then
                detail="-"
            else
                detail="\`${detail}\`"
            fi
            echo "| ${CHECK_NAMES[$i]} | ❌ Fail | ${detail} |"
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
set_output "total-count" "$TOTAL"

# CLI output
echo ""
echo "PR Requirements: ${PASS_COUNT}/${TOTAL} passed"
for i in "${!CHECK_NAMES[@]}"; do
    if [[ "${CHECK_RESULTS[$i]}" == "pass" ]]; then
        echo "  ✅ ${CHECK_NAMES[$i]}"
    else
        echo "  ❌ ${CHECK_NAMES[$i]}: ${CHECK_MESSAGES[$i]}"
    fi
done

if [[ "$FAIL_COUNT" -gt 0 ]]; then
    exit 1
fi
exit 0
