#!/usr/bin/env bash
set -euo pipefail

# Validates PR title against one or more allowed formats.
# Inputs via env vars:
#   INPUT_PR_TITLE      - PR title to validate (required)
#   INPUT_TITLE_FORMATS - Comma-separated allowed formats, pass if any matches
#                         (conventional, issue-number, custom; default: conventional)
#   INPUT_TITLE_TYPES   - conventional: comma-separated allowed types (default: standard set)
#   INPUT_TITLE_SCOPES  - conventional: comma-separated allowed scopes (empty = any)
#   INPUT_TITLE_PATTERN - custom: regex the title must match
#   INPUT_TITLE_REQUIRE_SCOPE - conventional: a scope is mandatory (default: false)
#   INPUT_TITLE_MAX_LENGTH    - maximum title length for every format (empty = unlimited)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib.sh"

TITLE="${INPUT_PR_TITLE:-}"
require_pr_data "$TITLE" "pr-title"
FORMATS="${INPUT_TITLE_FORMATS:-$DEFAULT_TITLE_FORMATS}"
TYPES="${INPUT_TITLE_TYPES:-$DEFAULT_TITLE_TYPES}"
SCOPES="${INPUT_TITLE_SCOPES:-}"
CUSTOM_PATTERN="${INPUT_TITLE_PATTERN:-}"
REQUIRE_SCOPE="${INPUT_TITLE_REQUIRE_SCOPE:-false}"
MAX_LENGTH="${INPUT_TITLE_MAX_LENGTH:-}"

# Why the title is not a valid conventional title, shown when no format matches
CONVENTIONAL_MISMATCH=""

if [[ -n "$MAX_LENGTH" ]]; then
    require_whole_number "$MAX_LENGTH" "title-max-length"
    if [[ ${#TITLE} -gt "$MAX_LENGTH" ]]; then
        echo "fail: title is ${#TITLE} characters (maximum $MAX_LENGTH)"
        exit 1
    fi
fi

# Conventional commits: parse the title once with a fixed pattern, then compare
# the captured type/scope against the allowed lists as plain strings. User
# input never becomes part of a regex.
matches_conventional() {
    local pattern='^([^()!:[:space:]]+)(\(([^)]+)\))?(!)?: .+'
    if [[ ! "$TITLE" =~ $pattern ]]; then
        CONVENTIONAL_MISMATCH="expected 'type(scope): description'"
        return 1
    fi

    local title_type="${BASH_REMATCH[1]}"
    local title_scope="${BASH_REMATCH[3]:-}"

    local found=false t
    split_csv "$TYPES"
    for t in ${SPLIT_RESULT[@]+"${SPLIT_RESULT[@]}"}; do
        if [[ "$title_type" == "$t" ]]; then
            found=true
            break
        fi
    done
    if [[ "$found" != "true" ]]; then
        CONVENTIONAL_MISMATCH="type '$title_type' is not allowed (allowed: $TYPES)"
        return 1
    fi

    if [[ -z "$title_scope" ]] && is_true "$REQUIRE_SCOPE" "title-require-scope"; then
        CONVENTIONAL_MISMATCH="a scope is required, e.g. '$title_type(api): ...'"
        return 1
    fi

    if [[ -n "$SCOPES" && -n "$title_scope" ]]; then
        found=false
        local s
        split_csv "$SCOPES"
        for s in ${SPLIT_RESULT[@]+"${SPLIT_RESULT[@]}"}; do
            if [[ "$title_scope" == "$s" ]]; then
                found=true
                break
            fi
        done
        if [[ "$found" != "true" ]]; then
            CONVENTIONAL_MISMATCH="scope '$title_scope' is not allowed (allowed: $SCOPES)"
            return 1
        fi
    fi

    return 0
}

# Issue-number prefix: "#123: Title" (recommended) or "123 - Title" (accepted)
matches_issue_number() {
    local hash_pattern='^#[0-9]+: .+'
    local dash_pattern='^[0-9]+ - .+'
    [[ "$TITLE" =~ $hash_pattern || "$TITLE" =~ $dash_pattern ]]
}

matches_custom() {
    [[ "$TITLE" =~ $CUSTOM_PATTERN ]]
}

split_csv "$FORMATS"
FORMAT_LIST=(${SPLIT_RESULT[@]+"${SPLIT_RESULT[@]}"})

if [[ ${#FORMAT_LIST[@]} -eq 0 ]]; then
    config_error "input 'title-formats' is empty"
fi

for format in "${FORMAT_LIST[@]}"; do
    case "$format" in
        conventional)
            if matches_conventional; then
                echo "pass"
                exit 0
            fi
            ;;
        issue-number)
            if matches_issue_number; then
                echo "pass"
                exit 0
            fi
            ;;
        custom)
            if [[ -z "$CUSTOM_PATTERN" ]]; then
                config_error "title format 'custom' requires input 'title-pattern' to be set"
            fi
            require_valid_regex "$CUSTOM_PATTERN" "title-pattern"
            if matches_custom; then
                echo "pass"
                exit 0
            fi
            ;;
        *)
            config_error "unknown title format '$format' in input 'title-formats' (allowed: conventional, issue-number, custom)"
            ;;
    esac
done

if [[ -n "$CONVENTIONAL_MISMATCH" ]]; then
    echo "fail: title '$TITLE' does not match any allowed format: ${FORMAT_LIST[*]} (conventional: $CONVENTIONAL_MISMATCH)"
else
    echo "fail: title '$TITLE' does not match any allowed format: ${FORMAT_LIST[*]}"
fi
exit 1
