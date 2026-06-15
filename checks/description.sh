#!/usr/bin/env bash
set -euo pipefail

# Validates PR description presence, minimum length, and required sections.
# Inputs via env vars:
#   INPUT_PR_BODY                       - PR body to check (required)
#   INPUT_DESCRIPTION_MIN_LENGTH        - Minimum character count (default: 20)
#   INPUT_DESCRIPTION_REQUIRED_SECTIONS - Comma-separated headings that must
#                                         appear in the body (empty = none)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib.sh"

BODY="${INPUT_PR_BODY:-}"
MIN_LENGTH="${INPUT_DESCRIPTION_MIN_LENGTH:-20}"

if ! [[ "$MIN_LENGTH" =~ ^[0-9]+$ ]]; then
    echo "fail: invalid min length '$MIN_LENGTH'"
    exit 1
fi

if [[ -z "$BODY" ]]; then
    echo "fail: PR description is empty"
    exit 1
fi

# Trim the body as a whole string; echo/sed would trim per line and
# misinterpret bodies starting with -n/-e as echo flags.
STRIPPED="$(trim "$BODY")"
LENGTH=${#STRIPPED}

if [[ "$LENGTH" -lt "$MIN_LENGTH" ]]; then
    echo "fail: PR description too short ($LENGTH chars, minimum $MIN_LENGTH)"
    exit 1
fi

REQUIRED_SECTIONS="${INPUT_DESCRIPTION_REQUIRED_SECTIONS:-}"
if [[ -n "$REQUIRED_SECTIONS" ]]; then
    split_csv "$REQUIRED_SECTIONS"
    MISSING_SECTIONS=()
    for section in ${SPLIT_RESULT[@]+"${SPLIT_RESULT[@]}"}; do
        if ! printf '%s\n' "$BODY" | grep -qF "$section"; then
            MISSING_SECTIONS+=("$section")
        fi
    done
    if [[ ${#MISSING_SECTIONS[@]} -gt 0 ]]; then
        echo "fail: PR description missing required sections: ${MISSING_SECTIONS[*]}"
        exit 1
    fi
fi

echo "pass"
exit 0
