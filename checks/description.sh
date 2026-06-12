#!/usr/bin/env bash
set -euo pipefail

# Validates PR description presence and minimum length.
# Inputs via env vars:
#   INPUT_PR_BODY               - PR body to check (required)
#   INPUT_DESCRIPTION_MIN_LENGTH - Minimum character count (default: 20)

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

echo "pass"
exit 0
