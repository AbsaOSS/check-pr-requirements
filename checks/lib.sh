#!/usr/bin/env bash

# Shared helpers for check scripts.
# Usage: source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

source "$(dirname "${BASH_SOURCE[0]}")/defaults.sh"

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

# Fail the check with a clear message when PR data needed by it is missing,
# e.g. when the workflow does not run on a pull_request event.
require_pr_data() {
    local value="$1" input_name="$2"
    if [[ -z "$value" ]]; then
        echo "fail: input '${input_name}' is empty (run on a pull_request event or pass it explicitly)"
        exit 1
    fi
}

# Exit code a check uses when the workflow configuration is invalid, so the
# summary blames the configuration rather than the PR.
CONFIG_ERROR_EXIT=2

config_error() {
    echo "config error: $1"
    exit "$CONFIG_ERROR_EXIT"
}

# Succeed when a boolean input is true in any letter case. Call it directly
# (not in a subshell) so an invalid value can end the check.
is_true() {
    local value="$1" input_name="$2"
    case "$(to_lower "$value")" in
        true) return 0 ;;
        false) return 1 ;;
        *) config_error "input '${input_name}' must be true or false, got '${value}'" ;;
    esac
}

require_whole_number() {
    local value="$1" input_name="$2"
    if ! [[ "$value" =~ ^[0-9]+$ ]]; then
        config_error "input '${input_name}' must be a whole number, got '${value}'"
    fi
}

require_valid_regex() {
    local pattern="$1" input_name="$2"
    local match_status=0
    # shellcheck disable=SC2319 # the [[ ]] status is the point: 2 means an invalid regex
    [[ "" =~ $pattern ]] || match_status=$?
    if [[ "$match_status" -eq 2 ]]; then
        config_error "input '${input_name}' is not a valid regular expression: '${pattern}'"
    fi
}
