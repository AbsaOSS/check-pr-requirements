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
