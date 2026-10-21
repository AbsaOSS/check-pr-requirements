#!/usr/bin/env bash
set -euo pipefail

# Validates PR description presence, minimum length, and required sections.
# Inputs via env vars:
#   INPUT_PR_BODY                             - PR body to check (required)
#   INPUT_DESCRIPTION_MIN_LENGTH              - Minimum character count (default: 20)
#   INPUT_DESCRIPTION_REQUIRED_SECTIONS       - Comma-separated headings that must
#                                               appear in the body (empty = none)
#   INPUT_DESCRIPTION_IGNORE_COMMENTS         - Drop <!-- --> comments (e.g. PR
#                                               template hints) before checking
#                                               (default: false)
#   INPUT_DESCRIPTION_REQUIRE_SECTION_CONTENT - Each required section must be a
#                                               heading line with text under it
#                                               (default: false)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib.sh"

BODY="${INPUT_PR_BODY:-}"
MIN_LENGTH="${INPUT_DESCRIPTION_MIN_LENGTH:-$DEFAULT_DESCRIPTION_MIN_LENGTH}"
IGNORE_COMMENTS="${INPUT_DESCRIPTION_IGNORE_COMMENTS:-false}"
REQUIRE_SECTION_CONTENT="${INPUT_DESCRIPTION_REQUIRE_SECTION_CONTENT:-false}"

require_whole_number "$MIN_LENGTH" "description-min-length"

# An unclosed comment hides the rest of the body, as it does when rendered.
strip_html_comments() {
    local remaining="$1" kept=""
    while [[ "$remaining" == *"<!--"* ]]; do
        kept+="${remaining%%<!--*}"
        remaining="${remaining#*<!--}"
        if [[ "$remaining" == *"-->"* ]]; then
            remaining="${remaining#*-->}"
        else
            remaining=""
        fi
    done
    printf '%s' "${kept}${remaining}"
}

heading_level() {
    local line="$1"
    if [[ "$line" =~ ^(#{1,6})[[:space:]] ]]; then
        echo "${#BASH_REMATCH[1]}"
    else
        echo 0
    fi
}

# Succeed when a line equal to the heading (ignoring case and surrounding
# whitespace) is followed by non-blank text before the next heading of the
# same or a higher level. Comments never count as content.
section_has_content() {
    local heading="$1"
    local wanted_heading section_level=0 in_section=false line line_level
    wanted_heading="$(to_lower "$(trim "$heading")")"

    while IFS= read -r line; do
        line="${line%$'\r'}"
        if [[ "$in_section" == "true" ]]; then
            line_level="$(heading_level "$line")"
            if [[ "$line_level" -gt 0 && ( "$section_level" -eq 0 || "$line_level" -le "$section_level" ) ]]; then
                return 1
            fi
            if [[ -n "$(trim "$line")" ]]; then
                return 0
            fi
        elif [[ "$(to_lower "$(trim "$line")")" == "$wanted_heading" ]]; then
            in_section=true
            section_level="$(heading_level "$wanted_heading")"
        fi
    done <<< "$(strip_html_comments "$BODY")"
    return 1
}

if is_true "$IGNORE_COMMENTS" "description-ignore-comments"; then
    BODY="$(strip_html_comments "$BODY")"
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
    EMPTY_SECTIONS=()
    for section in ${SPLIT_RESULT[@]+"${SPLIT_RESULT[@]}"}; do
        if ! printf '%s\n' "$BODY" | grep -qF "$section"; then
            MISSING_SECTIONS+=("$section")
        elif is_true "$REQUIRE_SECTION_CONTENT" "description-require-section-content" \
            && ! section_has_content "$section"; then
            EMPTY_SECTIONS+=("$section")
        fi
    done
    if [[ ${#MISSING_SECTIONS[@]} -gt 0 ]]; then
        echo "fail: PR description missing required sections: ${MISSING_SECTIONS[*]}"
        exit 1
    fi
    if [[ ${#EMPTY_SECTIONS[@]} -gt 0 ]]; then
        echo "fail: PR description sections without content: ${EMPTY_SECTIONS[*]}"
        exit 1
    fi
fi

echo "pass"
exit 0
