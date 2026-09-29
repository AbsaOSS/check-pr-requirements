#!/usr/bin/env bash
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/test_helpers.sh"
CHECK="${SCRIPT_DIR}/../checks/title_format.sh"

# ── Test Cases ───────────────────────────────────────────────────────────────
# Format: expected|description|title|types_override|scopes_override
CASES=(
    # Valid titles (default config)
    "pass|simple feat|feat: add login page||"
    "pass|fix with scope|fix(auth): resolve token expiry||"
    "pass|breaking change|feat!: breaking change||"
    "pass|breaking with scope|feat(api)!: breaking with scope||"
    "pass|docs type|docs: update README||"
    "pass|chore type|chore: bump dependencies||"
    "pass|refactor with scope|refactor(core): simplify parser||"
    "pass|build type|build: update Dockerfile||"
    "pass|ci type|ci: add workflow||"
    "pass|perf type|perf: optimize query||"
    "pass|test type|test: add unit tests||"
    "pass|revert type|revert: undo last commit||"

    # Invalid titles (default config)
    "fail|missing type prefix|Add login page||"
    "fail|missing description|feat:||"
    "fail|missing space after colon|feat:missing space||"
    "fail|invalid type|feature: add thing||"
    "fail|empty title|||"
    "fail|only whitespace|   ||"
    "fail|uppercase type|Feat: something||"
    "fail|trailing type|something feat: desc||"

    # Custom types
    "fail|feat not in custom types|feat: something|fix,docs|"
    "pass|fix in custom types|fix: something|fix,docs|"
    "pass|docs in custom types|docs: something|fix,docs|"

    # Regex metacharacters in types/scopes
    "fail|type with regex dot|feat: something|fe.t|"
    "fail|type with regex star|feat: something|feat.*|"
    "pass|legit type not affected by escaping|feat: something|feat|"

    # Special characters in title
    "pass|title with unicode emoji|feat: add login page||"
    "pass|title with backticks|feat: add \`foo\` helper||"

    # Custom scopes
    "pass|scope in allowed list|feat(api): something||api,web"
    "fail|scope not in allowed list|feat(db): something||api,web"
    "pass|no scope when scopes restricted|feat: something||api,web"
    "pass|types list with whitespace|fix: something|fix, docs|"
    "pass|scopes list with whitespace|feat(web): something||api, web"
    "fail|empty scope parens|feat(): something||"
)

# ── Runner ───────────────────────────────────────────────────────────────────
for case_entry in "${CASES[@]}"; do
    IFS='|' read -r expected description title types scopes <<< "$case_entry"

    if [[ "$expected" == "pass" ]]; then
        INPUT_PR_TITLE="$title" INPUT_TITLE_TYPES="$types" INPUT_TITLE_SCOPES="$scopes" \
            assert_pass "$description" "$CHECK"
    else
        INPUT_PR_TITLE="$title" INPUT_TITLE_TYPES="$types" INPUT_TITLE_SCOPES="$scopes" \
            assert_fail "$description" "$CHECK"
    fi
done

# ── Title formats ────────────────────────────────────────────────────────────

INPUT_TITLE_FORMATS="issue-number" INPUT_PR_TITLE="#123: Fix login error" \
    assert_pass "issue-number hash format" "$CHECK"

INPUT_TITLE_FORMATS="issue-number" INPUT_PR_TITLE="123 - Fix login error" \
    assert_pass "issue-number dash format" "$CHECK"

INPUT_TITLE_FORMATS="issue-number" INPUT_PR_TITLE="feat: add login" \
    assert_fail "conventional title rejected by issue-number format" "$CHECK"

INPUT_TITLE_FORMATS="issue-number" INPUT_PR_TITLE="#123:no space" \
    assert_fail "issue-number without space after colon" "$CHECK"

INPUT_TITLE_FORMATS="conventional,issue-number" INPUT_PR_TITLE="#123: Fix login" \
    assert_pass "multi-format: issue-number side matches" "$CHECK"

INPUT_TITLE_FORMATS="conventional,issue-number" INPUT_PR_TITLE="feat: add login" \
    assert_pass "multi-format: conventional side matches" "$CHECK"

INPUT_TITLE_FORMATS="conventional,issue-number" INPUT_PR_TITLE="random title" \
    assert_fail "multi-format: neither matches" "$CHECK"

INPUT_TITLE_FORMATS="custom" INPUT_TITLE_PATTERN="^JIRA-[0-9]+ .+" \
INPUT_PR_TITLE="JIRA-42 fix the thing" \
    assert_pass "custom pattern matches" "$CHECK"

INPUT_TITLE_FORMATS="custom" INPUT_TITLE_PATTERN="^JIRA-[0-9]+ .+" \
INPUT_PR_TITLE="fix the thing" \
    assert_fail "custom pattern does not match" "$CHECK"

INPUT_TITLE_FORMATS="custom" INPUT_TITLE_PATTERN="" \
INPUT_PR_TITLE="anything" \
    assert_fail "custom format without title-pattern" "$CHECK"

INPUT_TITLE_FORMATS="bogus" INPUT_PR_TITLE="feat: add login" \
    assert_fail "unknown format name" "$CHECK"

INPUT_TITLE_FORMATS="" INPUT_PR_TITLE="feat: add login" \
    assert_pass "empty formats falls back to conventional default" "$CHECK"

# ── Configuration errors ─────────────────────────────────────────────────────

INPUT_PR_TITLE="[PROJ-1] Title" INPUT_TITLE_FORMATS="custom" INPUT_TITLE_PATTERN="([" \
    assert_output_contains "invalid custom regex is a config error" "$CHECK" "config error: input 'title-pattern'"

INPUT_PR_TITLE="feat: add login" INPUT_TITLE_FORMATS="semantic" \
    assert_output_contains "unknown format is a config error" "$CHECK" "config error: unknown title format 'semantic'"

# ── Scope requirement and length limit ───────────────────────────────────────

INPUT_PR_TITLE="feat: add login" INPUT_TITLE_REQUIRE_SCOPE="true" \
    assert_output_contains "missing scope explained" "$CHECK" "a scope is required"

INPUT_PR_TITLE="feat(auth): add login" INPUT_TITLE_REQUIRE_SCOPE="true" \
    assert_pass "scope present when required" "$CHECK"

INPUT_PR_TITLE="feat: add login" INPUT_TITLE_REQUIRE_SCOPE="false" \
    assert_pass "scope optional by default" "$CHECK"

INPUT_PR_TITLE="feat: add a very long login flow description" INPUT_TITLE_MAX_LENGTH="20" \
    assert_output_contains "title over max length" "$CHECK" "maximum 20"

INPUT_PR_TITLE="feat: add login" INPUT_TITLE_MAX_LENGTH="15" \
    assert_pass "title exactly at max length" "$CHECK"

INPUT_PR_TITLE="feat: add login" INPUT_TITLE_MAX_LENGTH="x" \
    assert_output_contains "non-numeric max length is a config error" "$CHECK" "config error: input 'title-max-length'"

# ── Specific failure reasons ─────────────────────────────────────────────────

INPUT_PR_TITLE="Feat: add login" \
    assert_output_contains "wrong-case type explained" "$CHECK" "type 'Feat' is not allowed"

INPUT_PR_TITLE="feat(web): add login" INPUT_TITLE_SCOPES="api,ui" \
    assert_output_contains "disallowed scope explained" "$CHECK" "scope 'web' is not allowed"

INPUT_PR_TITLE="add login" \
    assert_output_contains "non-conventional shape explained" "$CHECK" "expected 'type(scope): description'"

print_results "title_format" || exit 1
