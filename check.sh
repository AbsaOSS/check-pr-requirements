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

# ── Remediation tips ──────────────────────────────────────────────────────────
# Per-check "how to fix" guidance, keyed by display name. Tips are built from the
# same configuration inputs the checks use, so guidance stays accurate as rules
# change. Config values are rendered as inert code spans (backticks/newlines
# stripped) to keep the summary safe.
code() {
    # Render "$1" as an inert inline code span; fall back to "$2" when empty.
    local value="$1"
    value=$(printf '%s' "$value" | tr '\n' ' ' | tr -d '`')
    if [[ -z "$value" ]]; then
        value="$2"
    fi
    printf '`%s`' "$value"
}

remediation_for() {
    local title_formats title_types desc_min desc_sections issue_keyword
    local branch_pattern branch_ticket max_files req_labels targets

    case "$1" in
        "PR Title")
            title_formats="${INPUT_TITLE_FORMATS:-conventional}"
            title_types="${INPUT_TITLE_TYPES:-feat,fix,docs,style,refactor,perf,test,build,ci,chore,revert}"
            echo "- **PR Title** — the title must match one of these formats: $(code "$title_formats" conventional)."
            if [[ ",$title_formats," == *",conventional,"* ]]; then
                echo "  - Allowed conventional types: $(code "$title_types" "feat, fix, ...")."
                echo "  - ✅ \`feat: add retry logic\`"
                echo "  - ❌ \`added retry logic\`"
            fi ;;
        "PR Description")
            desc_min="${INPUT_DESCRIPTION_MIN_LENGTH:-20}"
            desc_sections="${INPUT_DESCRIPTION_REQUIRED_SECTIONS:-}"
            echo "- **PR Description** — write a description of at least $(code "$desc_min" 20) characters."
            if [[ -n "$desc_sections" ]]; then
                echo "  - Required sections: $(code "$desc_sections" -)."
            fi ;;
        "Issue Reference")
            issue_keyword="${INPUT_ISSUE_REFERENCE_REQUIRE_KEYWORD:-false}"
            if [[ "$issue_keyword" == "true" ]]; then
                echo "- **Issue Reference** — reference an issue with a keyword, e.g. \`Closes #123\` or \`Fixes AB#123\`."
            else
                echo "- **Issue Reference** — reference an issue in the description, e.g. \`#123\`."
            fi ;;
        "Branch Name")
            branch_pattern="${INPUT_BRANCH_PATTERN:-^(feature|bugfix|hotfix|release|support|chore|docs|ci|dependabot)/[a-zA-Z0-9._-]+\$}"
            echo "- **Branch Name** — the branch name must match $(code "$branch_pattern" -), e.g. \`feature/add-login\`."
            if [[ "${INPUT_BRANCH_REQUIRE_TICKET:-false}" == "true" ]]; then
                branch_ticket="${INPUT_BRANCH_TICKET_PATTERN:-^[^/]+/[0-9]+-}"
                echo "  - Must include a ticket after the prefix, matching $(code "$branch_ticket" -), e.g. \`feature/123-add-login\`."
            fi ;;
        "PR Size")
            max_files="${INPUT_MAX_FILES_CHANGED:-50}"
            echo "- **PR Size** — keep changed files at or below $(code "$max_files" 50); split larger changes into smaller PRs." ;;
        "Label Presence")
            req_labels="${INPUT_REQUIRED_LABELS:-}"
            if [[ -n "$req_labels" ]]; then
                echo "- **Label Presence** — add the required label(s): $(code "$req_labels" -)."
            else
                echo "- **Label Presence** — add at least one label to the PR."
            fi ;;
        "Target Branch")
            targets="${INPUT_ALLOWED_TARGET_BRANCHES:-main,master}"
            echo "- **Target Branch** — retarget the PR to an allowed branch: $(code "$targets" "main, master")." ;;
        *)
            echo "- **$1** — see the check details above and the contributing guidelines." ;;
    esac
}

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

    # ── How to fix (failures only) ───────────────────────────────────────────
    if [[ "$FAIL_COUNT" -gt 0 ]]; then
        echo ""
        echo "### How to fix"
        echo ""
        echo "The checks above must pass before this PR can merge."
        echo ""
        for i in "${!CHECK_NAMES[@]}"; do
            if [[ "${CHECK_RESULTS[$i]}" != "pass" ]]; then
                remediation_for "${CHECK_NAMES[$i]}"
            fi
        done
    fi
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
