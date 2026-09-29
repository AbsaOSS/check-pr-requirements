#!/usr/bin/env bash
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHECKS_DIR="${SCRIPT_DIR}/checks"
source "${CHECKS_DIR}/lib.sh"

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

# ── Bypass ────────────────────────────────────────────────────────────────────
# Skip all checks when the PR author matches skip-actors, or the PR carries any
# label in skip-labels. Intended for bot PRs (e.g. Dependabot) or manually
# labelled exemptions. Emits a passing summary/outputs and exits.
inert() { printf '%s' "$1" | tr '\n' ' ' | tr -d '`'; }

emit_skip() {
    local reason="$1"
    {
        echo "## PR Requirements Check"
        echo ""
        echo "Checks skipped: ${reason}."
    } >> "${GITHUB_STEP_SUMMARY:-/dev/null}"
    set_output "result" "pass"
    set_output "pass-count" "0"
    set_output "fail-count" "0"
    set_output "warn-count" "0"
    set_output "total-count" "0"
    echo ""
    echo "PR Requirements: skipped (${reason})"
    exit 0
}

PR_AUTHOR="${INPUT_PR_AUTHOR:-}"
SKIP_ACTORS="${INPUT_SKIP_ACTORS:-}"
if [[ -n "$PR_AUTHOR" && -n "$SKIP_ACTORS" ]]; then
    split_csv "$SKIP_ACTORS"
    for actor in ${SPLIT_RESULT[@]+"${SPLIT_RESULT[@]}"}; do
        if [[ "$PR_AUTHOR" == "$actor" ]]; then
            emit_skip "author \`$(inert "$PR_AUTHOR")\` matched \`skip-actors\`"
        fi
    done
fi

PR_LABELS="${INPUT_LABELS:-}"
SKIP_LABELS="${INPUT_SKIP_LABELS:-}"
if [[ -n "$PR_LABELS" && -n "$SKIP_LABELS" ]]; then
    split_csv "$PR_LABELS"
    labels_arr=(${SPLIT_RESULT[@]+"${SPLIT_RESULT[@]}"})
    split_csv "$SKIP_LABELS"
    for skip in ${SPLIT_RESULT[@]+"${SPLIT_RESULT[@]}"}; do
        for lbl in ${labels_arr[@]+"${labels_arr[@]}"}; do
            if [[ "$lbl" == "$skip" ]]; then
                emit_skip "label \`$(inert "$skip")\` matched \`skip-labels\`"
            fi
        done
    done
fi

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
            branch_pattern="${INPUT_BRANCH_PATTERN:-^(feature|bugfix|hotfix|release|support|chore|docs|ci|dependabot)/[a-zA-Z0-9._/-]+\$}"
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
        "Warn Checks")
            echo "- **Warn Checks** — list only known check ids in \`warn-checks\`: ${KNOWN_IDS[*]}." ;;
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
WARN_COUNT=0
# Action-level config errors (not tied to an executed check): fail the job
# but stay out of pass/fail/total counts
CONFIG_ERROR_COUNT=0

lower() { printf '%s' "$1" | tr '[:upper:]' '[:lower:]'; }

# Check id derived from the registry toggle, e.g. INPUT_CHECK_PR_SIZE -> pr-size
check_id_for() { lower "${1#INPUT_CHECK_}" | tr '_' '-'; }

# Return 0 when $1 equals any of the remaining arguments.
contains() {
    local needle="$1" item
    shift
    for item in "$@"; do
        [[ "$item" == "$needle" ]] && return 0
    done
    return 1
}

declare -a KNOWN_IDS=()
for entry in "${REGISTRY[@]}"; do
    IFS='|' read -r env_var _ _ _ <<< "$entry"
    KNOWN_IDS+=("$(check_id_for "$env_var")")
done

declare -a WARN_IDS=()
split_csv "${INPUT_WARN_CHECKS:-}"
for warn_check in ${SPLIT_RESULT[@]+"${SPLIT_RESULT[@]}"}; do
    WARN_IDS+=("$(lower "$warn_check")")
done

record_result() {
    local name="$1" result="$2" message="$3"
    CHECK_NAMES+=("$name")
    CHECK_RESULTS+=("$result")
    CHECK_MESSAGES+=("$message")
    case "$result" in
        pass) ((PASS_COUNT++)) ;;
        warn) ((WARN_COUNT++)) ;;
        config-error) ((CONFIG_ERROR_COUNT++)) ;;
        *) ((FAIL_COUNT++)) ;;
    esac
}

run_check() {
    local name="$1" check_id="$3"
    local script="${CHECKS_DIR}/$2"

    if [[ ! -f "$script" ]]; then
        record_result "$name" "error" "check script not found: $script"
        return
    fi

    local output exit_code
    output=$(bash "$script" 2>&1)
    exit_code=$?

    # Exit 2 is a configuration error: never downgraded to a warning
    if [[ "$exit_code" -eq 0 ]]; then
        record_result "$name" "pass" "$output"
    elif [[ "$exit_code" -eq 2 ]]; then
        record_result "$name" "error" "$output"
    elif contains "$check_id" ${WARN_IDS[@]+"${WARN_IDS[@]}"}; then
        record_result "$name" "warn" "$output"
    else
        record_result "$name" "fail" "$output"
    fi
}

for warn_check in ${WARN_IDS[@]+"${WARN_IDS[@]}"}; do
    if ! contains "$warn_check" "${KNOWN_IDS[@]}"; then
        record_result "Warn Checks" "config-error" "config error: unknown check '${warn_check}' in input 'warn-checks'"
    fi
done

for idx in "${!REGISTRY[@]}"; do
    IFS='|' read -r env_var default display_name script_name <<< "${REGISTRY[$idx]}"
    enabled="${!env_var:-$default}"
    if [[ "$enabled" == "true" ]]; then
        run_check "$display_name" "$script_name" "${KNOWN_IDS[$idx]}"
    fi
done

# ── Summary ──────────────────────────────────────────────────────────────────
TOTAL=$((PASS_COUNT + FAIL_COUNT + WARN_COUNT))
BLOCKING_COUNT=$((FAIL_COUNT + CONFIG_ERROR_COUNT))

RESULT_EXTRA=""
if [[ "$WARN_COUNT" -gt 0 ]]; then
    RESULT_EXTRA+=", ${WARN_COUNT} with warnings"
fi
if [[ "$CONFIG_ERROR_COUNT" -gt 0 ]]; then
    RESULT_EXTRA+=", ${CONFIG_ERROR_COUNT} configuration error(s)"
fi

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
                error|config-error) status="⚠️ Error" ;;
                *) status="❌ Fail" ;;
            esac
            # Render PR-controlled text as an inert code span: strip backticks,
            # flatten newlines, escape table pipes
            detail="${CHECK_MESSAGES[$i]#fail: }"
            detail="${detail#error: }"
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
    echo "**Result:** ${PASS_COUNT}/${TOTAL} checks passed${RESULT_EXTRA}"

    # ── How to fix (failures only) ───────────────────────────────────────────
    if [[ "$BLOCKING_COUNT" -gt 0 ]]; then
        echo ""
        echo "### How to fix"
        echo ""
        echo "The checks above must pass before this PR can merge."
        echo ""
        for i in "${!CHECK_NAMES[@]}"; do
            if [[ "${CHECK_RESULTS[$i]}" != "pass" && "${CHECK_RESULTS[$i]}" != "warn" ]]; then
                remediation_for "${CHECK_NAMES[$i]}"
            fi
        done
    fi
} >> "${GITHUB_STEP_SUMMARY:-/dev/null}"

if [[ "$BLOCKING_COUNT" -eq 0 ]]; then
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
echo "PR Requirements: ${PASS_COUNT}/${TOTAL} passed${RESULT_EXTRA}"
for i in "${!CHECK_NAMES[@]}"; do
    if [[ "${CHECK_RESULTS[$i]}" == "pass" ]]; then
        echo "  ✅ ${CHECK_NAMES[$i]}"
    else
        case "${CHECK_RESULTS[$i]}" in
            warn)
                echo "  🟡 ${CHECK_NAMES[$i]}: ${CHECK_MESSAGES[$i]}"
                warn_msg="${CHECK_NAMES[$i]}: ${CHECK_MESSAGES[$i]#fail: }"
                warn_msg="${warn_msg//'%'/%25}"
                warn_msg="${warn_msg//$'\r'/%0D}"
                warn_msg="${warn_msg//$'\n'/%0A}"
                echo "::warning::${warn_msg}" ;;
            error|config-error) echo "  ⚠️ ${CHECK_NAMES[$i]}: ${CHECK_MESSAGES[$i]}" ;;
            *) echo "  ❌ ${CHECK_NAMES[$i]}: ${CHECK_MESSAGES[$i]}" ;;
        esac
    fi
done

if [[ "$BLOCKING_COUNT" -gt 0 ]]; then
    exit 1
fi
exit 0
