#!/usr/bin/env bash
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/test_helpers.sh"
CHECK="${SCRIPT_DIR}/../checks/title_conventional.sh"

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

    # Custom scopes
    "pass|scope in allowed list|feat(api): something||api,web"
    "fail|scope not in allowed list|feat(db): something||api,web"
    "pass|no scope when scopes restricted|feat: something||api,web"
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

print_results "title_conventional" || exit 1
