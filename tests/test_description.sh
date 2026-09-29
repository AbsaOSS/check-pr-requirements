#!/usr/bin/env bash
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/test_helpers.sh"
CHECK="${SCRIPT_DIR}/../checks/description.sh"

# ── Pass cases ───────────────────────────────────────────────────────────────

INPUT_DESCRIPTION_MIN_LENGTH="" \
INPUT_PR_BODY="This is a valid PR description with enough content." \
    assert_pass "valid description" "$CHECK"

INPUT_PR_BODY="Short but enough text here" INPUT_DESCRIPTION_MIN_LENGTH="10" \
    assert_pass "meets custom min length" "$CHECK"

INPUT_DESCRIPTION_MIN_LENGTH="" \
INPUT_PR_BODY="$(printf '%0.s-' {1..100})" \
    assert_pass "long description" "$CHECK"

# ── Fail cases ───────────────────────────────────────────────────────────────

INPUT_DESCRIPTION_MIN_LENGTH="" \
INPUT_PR_BODY="" \
    assert_fail "empty body" "$CHECK"

INPUT_DESCRIPTION_MIN_LENGTH="" \
INPUT_PR_BODY="Too short" \
    assert_fail "below default min length" "$CHECK"

INPUT_PR_BODY="abc" INPUT_DESCRIPTION_MIN_LENGTH="10" \
    assert_fail "below custom min length" "$CHECK"

INPUT_DESCRIPTION_MIN_LENGTH="" \
INPUT_PR_BODY="   " \
    assert_fail "whitespace only" "$CHECK"

# ── Edge cases ───────────────────────────────────────────────────────────────

INPUT_DESCRIPTION_MIN_LENGTH="" \
INPUT_PR_BODY="$(printf '\n\n\n\n')" \
    assert_fail "only newlines" "$CHECK"

INPUT_DESCRIPTION_MIN_LENGTH="" \
INPUT_PR_BODY="$(printf '\n\n\nActual content here that is long enough\n\n')" \
    assert_pass "content with surrounding newlines" "$CHECK"

INPUT_DESCRIPTION_MIN_LENGTH="" \
INPUT_PR_BODY="This has pipes | in | it and that is fine for description" \
    assert_pass "body with pipe characters" "$CHECK"

INPUT_DESCRIPTION_MIN_LENGTH="1" \
INPUT_PR_BODY="x" \
    assert_pass "minimum length of 1" "$CHECK"

INPUT_DESCRIPTION_MIN_LENGTH="1" \
INPUT_PR_BODY="-n" \
    assert_pass "body that looks like an echo flag" "$CHECK"

INPUT_DESCRIPTION_MIN_LENGTH="6" \
INPUT_PR_BODY="$(printf '\n\n\nshort\n\n')" \
    assert_fail "surrounding newlines do not count toward length" "$CHECK"

# ── Required sections ────────────────────────────────────────────────────────

INPUT_DESCRIPTION_MIN_LENGTH="" \
INPUT_DESCRIPTION_REQUIRED_SECTIONS="## Overview,## Release Notes" \
INPUT_PR_BODY="$(printf '## Overview\nSome change description here\n## Release Notes\n- Fixed a thing')" \
    assert_pass "all required sections present" "$CHECK"

INPUT_DESCRIPTION_MIN_LENGTH="" \
INPUT_DESCRIPTION_REQUIRED_SECTIONS="## Overview,## Release Notes" \
INPUT_PR_BODY="$(printf '## Overview\nSome change description, no release notes section')" \
    assert_fail "missing one required section" "$CHECK"

INPUT_DESCRIPTION_MIN_LENGTH="" \
INPUT_DESCRIPTION_REQUIRED_SECTIONS="" \
INPUT_PR_BODY="Long enough body without any sections at all" \
    assert_pass "no sections required" "$CHECK"

# ── Configuration errors ─────────────────────────────────────────────────────

INPUT_PR_BODY="A valid description body here" INPUT_DESCRIPTION_MIN_LENGTH="abc" \
    assert_output_contains "invalid min length is a config error" "$CHECK" "config error: input 'description-min-length'"

# ── PR template awareness ────────────────────────────────────────────────────

TEMPLATE=$'## Overview\n<!-- Describe your change here please -->\n\n## Release Notes\n<!-- - Added X -->\n'

INPUT_PR_BODY="$TEMPLATE" INPUT_DESCRIPTION_REQUIRED_SECTIONS="## Overview,## Release Notes" \
    assert_pass "untouched template passes by default (backward compatible)" "$CHECK"

INPUT_PR_BODY="$TEMPLATE" INPUT_DESCRIPTION_MIN_LENGTH="40" \
    assert_pass "template comments count toward length by default" "$CHECK"

INPUT_PR_BODY="$TEMPLATE" INPUT_DESCRIPTION_MIN_LENGTH="40" INPUT_DESCRIPTION_IGNORE_COMMENTS="true" \
    assert_output_contains "comments do not count toward length" "$CHECK" "too short"

INPUT_PR_BODY="$TEMPLATE" INPUT_DESCRIPTION_REQUIRED_SECTIONS="## Overview,## Release Notes" \
INPUT_DESCRIPTION_REQUIRE_SECTION_CONTENT="true" \
    assert_output_contains "empty template sections are reported" "$CHECK" "sections without content: ## Overview ## Release Notes"

INPUT_PR_BODY=$'## Overview\nAdds the login flow.\n\n## Release Notes\n### Added\n- Login\n' \
INPUT_DESCRIPTION_REQUIRED_SECTIONS="## Overview,## Release Notes" \
INPUT_DESCRIPTION_REQUIRE_SECTION_CONTENT="true" \
    assert_pass "filled sections, sub-heading counts as content" "$CHECK"

INPUT_PR_BODY=$'## overview\r\nAdds the login flow for users.\r\n' \
INPUT_DESCRIPTION_REQUIRED_SECTIONS="## Overview" INPUT_DESCRIPTION_REQUIRE_SECTION_CONTENT="true" \
    assert_output_contains "presence match stays case-sensitive" "$CHECK" "missing required sections"

INPUT_PR_BODY=$'See ## Release Notes below\n## Release Notes\n' \
INPUT_DESCRIPTION_REQUIRED_SECTIONS="## Release Notes" INPUT_DESCRIPTION_REQUIRE_SECTION_CONTENT="true" \
    assert_output_contains "mention in text is not a filled section" "$CHECK" "sections without content"

INPUT_PR_BODY=$'### Release Notes\nSome text that is long enough\n' \
INPUT_DESCRIPTION_REQUIRED_SECTIONS="## Release Notes" INPUT_DESCRIPTION_REQUIRE_SECTION_CONTENT="true" \
    assert_output_contains "deeper heading is not the required heading" "$CHECK" "sections without content"

INPUT_PR_BODY=$'Real text before <!-- unclosed comment hides the rest' INPUT_DESCRIPTION_IGNORE_COMMENTS="true" \
INPUT_DESCRIPTION_MIN_LENGTH="10" \
    assert_pass "unclosed comment hides only what follows it" "$CHECK"

print_results "description" || exit 1
