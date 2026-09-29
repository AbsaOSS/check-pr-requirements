#!/usr/bin/env bash
set -uo pipefail

# Guards against drift between action.yml input defaults and the defaults the
# scripts fall back to when run outside the action (checks/defaults.sh and the
# check.sh toggle registry).

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/test_helpers.sh"
ROOT_DIR="${SCRIPT_DIR}/.."
source "${ROOT_DIR}/checks/defaults.sh"

action_yml_default() {
    local input_name="$1"
    awk -v input="  ${input_name}:" '
        $0 == input { in_input = 1; next }
        in_input && /^    default:/ {
            sub(/^    default: /, "")
            gsub(/^"|"$/, "")
            print
            exit
        }
        in_input && /^  [^ ]/ { exit }
    ' "${ROOT_DIR}/action.yml"
}

assert_same_default() {
    local input_name="$1" script_default="$2"
    local action_default
    action_default="$(action_yml_default "$input_name")"

    ((TESTS_TOTAL++))
    if [[ "$action_default" == "$script_default" ]]; then
        echo "  ✅ ${input_name}"
        ((TESTS_PASSED++))
    else
        echo "  ❌ ${input_name}: action.yml '${action_default}' != script '${script_default}'"
        ((TESTS_FAILED++))
    fi
}

assert_same_default "title-formats" "$DEFAULT_TITLE_FORMATS"
assert_same_default "title-types" "$DEFAULT_TITLE_TYPES"
assert_same_default "description-min-length" "$DEFAULT_DESCRIPTION_MIN_LENGTH"
assert_same_default "branch-pattern" "$DEFAULT_BRANCH_PATTERN"
assert_same_default "branch-ticket-pattern" "$DEFAULT_BRANCH_TICKET_PATTERN"
assert_same_default "max-files-changed" "$DEFAULT_MAX_FILES_CHANGED"
assert_same_default "allowed-target-branches" "$DEFAULT_ALLOWED_TARGET_BRANCHES"

# Toggle defaults in the check.sh registry, e.g. "INPUT_CHECK_TITLE|true|..."
while IFS='|' read -r env_var toggle_default _; do
    input_name="$(printf '%s' "${env_var#INPUT_}" | tr '[:upper:]_' '[:lower:]-')"
    assert_same_default "$input_name" "$toggle_default"
done < <(grep -oE '"INPUT_CHECK_[A-Z_]+\|[a-z]+\|' "${ROOT_DIR}/check.sh" | tr -d '"')

print_results "defaults" || exit 1
