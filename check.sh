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
    local subject="$1" value="$2" input_name="$3"
    local value_text skip_summary
    value_text="$(inert "$value")"
    skip_summary="## PR Requirements Check"$'\n\n'"Checks skipped: ${subject} \`${value_text}\` matched \`${input_name}\`."
    printf '%s\n' "$skip_summary" >> "${GITHUB_STEP_SUMMARY:-/dev/null}"
    set_output "summary" "$skip_summary"
    set_output "failed-checks" ""
    set_output "result" "pass"
    set_output "pass-count" "0"
    set_output "fail-count" "0"
    set_output "warn-count" "0"
    set_output "total-count" "0"
    set_output "skipped" "true"
    set_output "skip-reason" "${subject} ${value_text} matched ${input_name}"
    echo ""
    echo "PR Requirements: skipped (${subject} ${value_text} matched ${input_name})"
    exit 0
}

PR_AUTHOR="${INPUT_PR_AUTHOR:-}"
SKIP_ACTORS="${INPUT_SKIP_ACTORS:-}"
if [[ -n "$PR_AUTHOR" ]] && csv_contains_ignore_case "$PR_AUTHOR" "$SKIP_ACTORS"; then
    emit_skip "author" "$PR_AUTHOR" "skip-actors"
fi

PR_LABELS="${INPUT_LABELS:-}"
SKIP_LABELS="${INPUT_SKIP_LABELS:-}"
split_csv "$SKIP_LABELS"
skip_label_list=(${SPLIT_RESULT[@]+"${SPLIT_RESULT[@]}"})
for skip_label in ${skip_label_list[@]+"${skip_label_list[@]}"}; do
    if csv_contains_ignore_case "$skip_label" "$PR_LABELS"; then
        emit_skip "label" "$skip_label" "skip-labels"
    fi
done

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
    "INPUT_CHECK_RELEASE_NOTES|false|Release Notes|release_notes.sh"
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
            title_formats="${INPUT_TITLE_FORMATS:-$DEFAULT_TITLE_FORMATS}"
            title_types="${INPUT_TITLE_TYPES:-$DEFAULT_TITLE_TYPES}"
            echo "- **PR Title** — the title must match one of these formats: $(code "$title_formats" conventional)."
            if [[ ",$title_formats," == *",conventional,"* ]]; then
                echo "  - Allowed conventional types: $(code "$title_types" "feat, fix, ...")."
                if [[ "$(to_lower "${INPUT_TITLE_REQUIRE_SCOPE:-false}")" == "true" ]]; then
                    echo "  - A scope is required, e.g. \`feat(api): add retry logic\`."
                fi
                echo "  - ✅ \`feat: add retry logic\`"
                echo "  - ❌ \`added retry logic\`"
            fi
            if [[ -n "${INPUT_TITLE_MAX_LENGTH:-}" ]]; then
                echo "  - Keep the title at or below $(code "$INPUT_TITLE_MAX_LENGTH" -) characters."
            fi ;;
        "PR Description")
            desc_min="${INPUT_DESCRIPTION_MIN_LENGTH:-$DEFAULT_DESCRIPTION_MIN_LENGTH}"
            desc_sections="${INPUT_DESCRIPTION_REQUIRED_SECTIONS:-}"
            echo "- **PR Description** — write a description of at least $(code "$desc_min" 20) characters."
            if [[ -n "$desc_sections" ]]; then
                echo "  - Required sections: $(code "$desc_sections" -)."
            fi
            if [[ "$(to_lower "${INPUT_DESCRIPTION_IGNORE_COMMENTS:-false}")" == "true" ]]; then
                echo "  - Template comments (\`<!-- ... -->\`) do not count; replace them with your own text."
            fi
            if [[ "$(to_lower "${INPUT_DESCRIPTION_REQUIRE_SECTION_CONTENT:-false}")" == "true" ]]; then
                echo "  - Write some text under each required section heading."
            fi ;;
        "Issue Reference")
            issue_keyword="${INPUT_ISSUE_REFERENCE_REQUIRE_KEYWORD:-false}"
            if [[ "$(to_lower "$issue_keyword")" == "true" ]]; then
                echo "- **Issue Reference** — reference an issue with a keyword, e.g. \`Closes #123\` or \`Fixes AB#123\`."
            else
                echo "- **Issue Reference** — reference an issue in the description, e.g. \`#123\`."
            fi ;;
        "Branch Name")
            branch_pattern="${INPUT_BRANCH_PATTERN:-$DEFAULT_BRANCH_PATTERN}"
            echo "- **Branch Name** — the branch name must match $(code "$branch_pattern" -), e.g. \`feature/add-login\`."
            if [[ "$(to_lower "${INPUT_BRANCH_REQUIRE_TICKET:-false}")" == "true" ]]; then
                branch_ticket="${INPUT_BRANCH_TICKET_PATTERN:-$DEFAULT_BRANCH_TICKET_PATTERN}"
                echo "  - Must include a ticket after the prefix, matching $(code "$branch_ticket" -), e.g. \`feature/123-add-login\`."
            fi ;;
        "PR Size")
            max_files="${INPUT_MAX_FILES_CHANGED:-$DEFAULT_MAX_FILES_CHANGED}"
            echo "- **PR Size** — keep changed files at or below $(code "$max_files" 50); split larger changes into smaller PRs."
            if [[ -n "${INPUT_MAX_LINES_CHANGED:-}" ]]; then
                echo "  - Keep changed lines (additions + deletions) at or below $(code "$INPUT_MAX_LINES_CHANGED" -)."
            fi ;;
        "Label Presence")
            req_labels="${INPUT_REQUIRED_LABELS:-}"
            if [[ -n "$req_labels" ]]; then
                echo "- **Label Presence** — add the required label(s): $(code "$req_labels" -)."
            else
                echo "- **Label Presence** — add at least one label to the PR."
            fi ;;
        "Target Branch")
            targets="${INPUT_ALLOWED_TARGET_BRANCHES:-$DEFAULT_ALLOWED_TARGET_BRANCHES}"
            echo "- **Target Branch** — retarget the PR to an allowed branch: $(code "$targets" "main, master")." ;;
        "Release Notes")
            echo "- **Release Notes** — add a heading matching $(code "${INPUT_RELEASE_NOTES_TAG:-$DEFAULT_RELEASE_NOTES_TAG}" -) followed directly by a bullet list, e.g. \`- Added retry logic\`."
            if [[ -n "${INPUT_RELEASE_NOTES_SKIP_LABELS-$DEFAULT_RELEASE_NOTES_SKIP_LABELS}" ]]; then
                echo "  - If the change needs no release notes, add a label: $(code "${INPUT_RELEASE_NOTES_SKIP_LABELS-$DEFAULT_RELEASE_NOTES_SKIP_LABELS}" -)."
            fi ;;
        *)
            echo "- **$1** — see the check details above and the contributing guidelines." ;;
    esac
}

# ── Runner ───────────────────────────────────────────────────────────────────
declare -a CHECK_NAMES=()
declare -a CHECK_RESULTS=()
declare -a CHECK_MESSAGES=()
declare -a CHECK_IDS=()
FAIL_COUNT=0
PASS_COUNT=0
WARN_COUNT=0
WARN_CHECKS="${INPUT_WARN_CHECKS:-}"

# result is pass, fail (the PR breaks a rule), warn (a failure of a check
# listed in warn-checks, which does not block) or error (invalid configuration)
record_result() {
    local name="$1" result="$2" message="$3" check_id="${4:-}"
    CHECK_IDS+=("$check_id")
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
        record_result "$name" "error" "check script not found: $script" "$check_id"
        return
    fi

    local output exit_code
    output=$(bash "$script" 2>&1)
    exit_code=$?

    case "$exit_code" in
        0) record_result "$name" "pass" "$output" "$check_id" ;;
        "$CONFIG_ERROR_EXIT") record_result "$name" "error" "$output" "$check_id" ;;
        *)
            if csv_contains_ignore_case "$check_id" "$WARN_CHECKS"; then
                record_result "$name" "warn" "$output" "$check_id"
            else
                record_result "$name" "fail" "$output" "$check_id"
            fi ;;
    esac
}

# INPUT_CHECK_PR_SIZE -> check-pr-size
input_name_of() {
    printf '%s' "${1#INPUT_}" | tr '[:upper:]_' '[:lower:]-'
}

# INPUT_CHECK_PR_SIZE -> pr-size, the id used in warn-checks
check_id_of() {
    local input_name
    input_name="$(input_name_of "$1")"
    printf '%s' "${input_name#check-}"
}

known_check_ids=""
for entry in "${REGISTRY[@]}"; do
    known_check_ids+="$(check_id_of "${entry%%|*}"),"
done
split_csv "$WARN_CHECKS"
for warn_check in ${SPLIT_RESULT[@]+"${SPLIT_RESULT[@]}"}; do
    if ! csv_contains_ignore_case "$warn_check" "$known_check_ids"; then
        record_result "Warn Checks" "error" \
            "config error: unknown check '${warn_check}' in input 'warn-checks' (known: ${known_check_ids%,})"
    fi
done

for entry in "${REGISTRY[@]}"; do
    IFS='|' read -r env_var default display_name script_name <<< "$entry"
    toggle="${!env_var:-$default}"
    case "$(to_lower "$toggle")" in
        true) run_check "$display_name" "$script_name" "$(check_id_of "$env_var")" ;;
        false) ;;
        *) record_result "$display_name" "error" \
            "config error: input '$(input_name_of "$env_var")' must be true or false, got '${toggle}'" \
            "$(check_id_of "$env_var")" ;;
    esac
done

# ── Summary ──────────────────────────────────────────────────────────────────
TOTAL=$((PASS_COUNT + FAIL_COUNT + WARN_COUNT))

SUMMARY_MARKDOWN="$({
    echo "## PR Requirements Check"
    echo ""
    echo "| Check | Status | Details |"
    echo "|-------|--------|---------|"

    for i in "${!CHECK_NAMES[@]}"; do
        if [[ "${CHECK_RESULTS[$i]}" == "pass" ]]; then
            echo "| ${CHECK_NAMES[$i]} | ✅ Pass | - |"
        else
            case "${CHECK_RESULTS[$i]}" in
                error) status="⚠️ Error" ;;
                warn) status="🟡 Warning" ;;
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
    if [[ "$WARN_COUNT" -gt 0 ]]; then
        echo "(${WARN_COUNT} with warnings)"
    fi

    # ── How to fix (failures and warnings) ───────────────────────────────────
    if [[ $((FAIL_COUNT + WARN_COUNT)) -gt 0 ]]; then
        echo ""
        echo "### How to fix"
        echo ""
        if [[ "$FAIL_COUNT" -gt 0 ]]; then
            echo "The failed checks above must pass before this PR can merge."
        fi
        if [[ "$WARN_COUNT" -gt 0 ]]; then
            echo "Warnings do not block merging."
        fi
        echo ""
        for i in "${!CHECK_NAMES[@]}"; do
            case "${CHECK_RESULTS[$i]}" in
                fail|warn) remediation_for "${CHECK_NAMES[$i]}" ;;
                error) echo "- **${CHECK_NAMES[$i]}** — the action configuration in the workflow file is invalid; fix the input named in the details above." ;;
            esac
        done
    fi
})"
printf '%s\n' "$SUMMARY_MARKDOWN" >> "${GITHUB_STEP_SUMMARY:-/dev/null}"

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
set_output "skipped" "false"
set_output "skip-reason" ""

failed_check_ids=""
for i in "${!CHECK_NAMES[@]}"; do
    if [[ "${CHECK_RESULTS[$i]}" == "fail" || "${CHECK_RESULTS[$i]}" == "error" ]] && [[ -n "${CHECK_IDS[$i]}" ]]; then
        failed_check_ids+="${CHECK_IDS[$i]},"
    fi
done
set_output "failed-checks" "${failed_check_ids%,}"
set_output "summary" "$SUMMARY_MARKDOWN"

# ── Annotations ──────────────────────────────────────────────────────────────
# Shown in the PR checks UI. Values are escaped per the workflow command spec
# so PR-controlled text cannot end the command early.
escape_command_data() {
    local value="$1"
    value="${value//'%'/%25}"
    value="${value//$'\r'/%0D}"
    value="${value//$'\n'/%0A}"
    printf '%s' "$value"
}

escape_command_property() {
    local value
    value="$(escape_command_data "$1")"
    value="${value//:/%3A}"
    value="${value//,/%2C}"
    printf '%s' "$value"
}

if [[ "$(to_lower "${INPUT_ANNOTATIONS:-true}")" != "false" ]]; then
    for i in "${!CHECK_NAMES[@]}"; do
        case "${CHECK_RESULTS[$i]}" in
            fail|error) command="error" ;;
            warn) command="warning" ;;
            *) continue ;;
        esac
        echo "::${command} title=$(escape_command_property "${CHECK_NAMES[$i]}")::$(escape_command_data "${CHECK_MESSAGES[$i]#fail: }")"
    done
fi

# ── CLI output ───────────────────────────────────────────────────────────────
# Workflow commands are disabled while PR-controlled messages are printed.
stop_commands_token="check-pr-requirements-${RANDOM}${RANDOM}${RANDOM}"
echo "::stop-commands::${stop_commands_token}"
echo ""
echo "PR Requirements: ${PASS_COUNT}/${TOTAL} passed"
for i in "${!CHECK_NAMES[@]}"; do
    case "${CHECK_RESULTS[$i]}" in
        pass) echo "  ✅ ${CHECK_NAMES[$i]}" ;;
        fail) echo "  ❌ ${CHECK_NAMES[$i]}: ${CHECK_MESSAGES[$i]}" ;;
        warn) echo "  🟡 ${CHECK_NAMES[$i]}: ${CHECK_MESSAGES[$i]}" ;;
        error) echo "  ⚠️ ${CHECK_NAMES[$i]}: ${CHECK_MESSAGES[$i]}" ;;
    esac
done
echo "::${stop_commands_token}::"

if [[ "$FAIL_COUNT" -gt 0 ]]; then
    exit 1
fi
exit 0
