#!/usr/bin/env bash

# Shared helpers for check scripts.
# Usage: source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

# Trim leading and trailing whitespace from $1, print result.
trim() {
    local s="$1"
    s="${s#"${s%%[![:space:]]*}"}"
    s="${s%"${s##*[![:space:]]}"}"
    printf '%s' "$s"
}

# Split comma-separated $1 into trimmed, non-empty elements stored in the
# global array SPLIT_RESULT. Globals instead of namerefs so this works on
# bash 3.2 (macOS default).
split_csv() {
    SPLIT_RESULT=()
    local -a raw=()
    IFS=',' read -ra raw <<< "$1"
    local item trimmed
    for item in ${raw[@]+"${raw[@]}"}; do
        trimmed="$(trim "$item")"
        if [[ -n "$trimmed" ]]; then
            SPLIT_RESULT+=("$trimmed")
        fi
    done
}

to_lower() {
    printf '%s' "$1" | tr '[:upper:]' '[:lower:]'
}

# Succeed when $1 equals any entry of comma-separated $2, ignoring case
# (GitHub label names and logins are case-insensitive).
csv_contains_ignore_case() {
    local needle entry
    needle="$(to_lower "$1")"
    split_csv "$2"
    for entry in ${SPLIT_RESULT[@]+"${SPLIT_RESULT[@]}"}; do
        if [[ "$(to_lower "$entry")" == "$needle" ]]; then
            return 0
        fi
    done
    return 1
}
