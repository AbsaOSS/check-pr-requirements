#!/usr/bin/env bash
set -euo pipefail

# Validates PR title against conventional commits format.
# Inputs via env vars:
#   INPUT_PR_TITLE       - PR title to validate (required)
#   INPUT_TITLE_TYPES    - Comma-separated allowed types (default: standard set)
#   INPUT_TITLE_SCOPES   - Comma-separated allowed scopes (empty = any)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib.sh"

TITLE="${INPUT_PR_TITLE:?PR title is required}"
TYPES="${INPUT_TITLE_TYPES:-feat,fix,docs,style,refactor,perf,test,build,ci,chore,revert}"
SCOPES="${INPUT_TITLE_SCOPES:-}"

# Parse the title once with a fixed pattern, then compare the captured
# type/scope against the allowed lists as plain strings. User input never
# becomes part of a regex.
TITLE_PATTERN='^([^()!:[:space:]]+)(\(([^)]+)\))?(!)?: .+'

if [[ ! "$TITLE" =~ $TITLE_PATTERN ]]; then
    echo "fail: title '$TITLE' does not match conventional commits format: type(scope)!: description"
    exit 1
fi

TITLE_TYPE="${BASH_REMATCH[1]}"
TITLE_SCOPE="${BASH_REMATCH[3]:-}"

split_csv "$TYPES"
TYPE_OK=false
for t in ${SPLIT_RESULT[@]+"${SPLIT_RESULT[@]}"}; do
    if [[ "$TITLE_TYPE" == "$t" ]]; then
        TYPE_OK=true
        break
    fi
done

if [[ "$TYPE_OK" != "true" ]]; then
    echo "fail: title type '$TITLE_TYPE' not in allowed types: $TYPES"
    exit 1
fi

if [[ -n "$SCOPES" && -n "$TITLE_SCOPE" ]]; then
    split_csv "$SCOPES"
    SCOPE_OK=false
    for s in ${SPLIT_RESULT[@]+"${SPLIT_RESULT[@]}"}; do
        if [[ "$TITLE_SCOPE" == "$s" ]]; then
            SCOPE_OK=true
            break
        fi
    done

    if [[ "$SCOPE_OK" != "true" ]]; then
        echo "fail: title scope '$TITLE_SCOPE' not in allowed scopes: $SCOPES"
        exit 1
    fi
fi

echo "pass"
exit 0
