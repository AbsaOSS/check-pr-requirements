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

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib.sh"

TITLE="${INPUT_PR_TITLE:?PR title is required}"
FORMATS="${INPUT_TITLE_FORMATS:-conventional}"
TYPES="${INPUT_TITLE_TYPES:-feat,fix,docs,style,refactor,perf,test,build,ci,chore,revert}"
SCOPES="${INPUT_TITLE_SCOPES:-}"
CUSTOM_PATTERN="${INPUT_TITLE_PATTERN:-}"

# Conventional commits: parse the title once with a fixed pattern, then compare
# the captured type/scope against the allowed lists as plain strings. User
# input never becomes part of a regex.
matches_conventional() {
    local pattern='^([^()!:[:space:]]+)(\(([^)]+)\))?(!)?: .+'
    if [[ ! "$TITLE" =~ $pattern ]]; then
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
    echo "fail: no title formats configured"
    exit 1
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
                echo "fail: title format 'custom' requires title-pattern to be set"
                exit 1
            fi
            if matches_custom; then
                echo "pass"
                exit 0
            fi
            ;;
        *)
            echo "fail: unknown title format '$format' (allowed: conventional, issue-number, custom)"
            exit 1
            ;;
    esac
done

echo "fail: title '$TITLE' does not match any allowed format: ${FORMAT_LIST[*]}"
exit 1
