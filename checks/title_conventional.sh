#!/usr/bin/env bash
set -euo pipefail

# Validates PR title against conventional commits format.
# Inputs via env vars:
#   INPUT_PR_TITLE       - PR title to validate (required)
#   INPUT_TITLE_TYPES    - Comma-separated allowed types (default: standard set)
#   INPUT_TITLE_SCOPES   - Comma-separated allowed scopes (empty = any)

TITLE="${INPUT_PR_TITLE:?PR title is required}"
TYPES="${INPUT_TITLE_TYPES:-feat,fix,docs,style,refactor,perf,test,build,ci,chore,revert}"
SCOPES="${INPUT_TITLE_SCOPES:-}"

IFS=',' read -ra TYPE_ARRAY <<< "$TYPES"
TYPES_PATTERN=$(IFS='|'; echo "${TYPE_ARRAY[*]}")

if [[ -n "$SCOPES" ]]; then
    IFS=',' read -ra SCOPE_ARRAY <<< "$SCOPES"
    SCOPES_PATTERN=$(IFS='|'; echo "${SCOPE_ARRAY[*]}")
    PATTERN="^(${TYPES_PATTERN})(\((${SCOPES_PATTERN})\))?!?: .+"
else
    PATTERN="^(${TYPES_PATTERN})(\(.+\))?!?: .+"
fi

if [[ "$TITLE" =~ $PATTERN ]]; then
    echo "pass"
    exit 0
else
    echo "fail: title '$TITLE' does not match conventional commits format: type(scope)!: description"
    exit 1
fi
