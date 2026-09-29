#!/usr/bin/env bash
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/test_helpers.sh"
COMMENT_SCRIPT="${SCRIPT_DIR}/../comment.sh"

# A fake gh that records its arguments and answers the comment lookup with
# EXISTING_COMMENT_ID (empty = no comment yet).
STUB_DIR="$(mktemp -d)"
cat > "${STUB_DIR}/gh" <<'STUB'
#!/usr/bin/env bash
echo "$*" >> "$GH_CALLS_LOG"
if [[ "$*" == *"--paginate"* && -n "${EXISTING_COMMENT_ID:-}" ]]; then
    echo "$EXISTING_COMMENT_ID"
fi
STUB
chmod +x "${STUB_DIR}/gh"

run_comment_case() {
    local description="$1" result="$2" existing_comment_id="$3" expected_call="$4"

    ((TESTS_TOTAL++))
    local calls_log
    calls_log="$(mktemp)"
    env -i PATH="${STUB_DIR}:$PATH" HOME="$HOME" GH_CALLS_LOG="$calls_log" \
        EXISTING_COMMENT_ID="$existing_comment_id" GITHUB_REPOSITORY="org/repo" \
        INPUT_PR_NUMBER="7" INPUT_RESULT="$result" INPUT_SUMMARY="## PR Requirements Check" \
        bash "$COMMENT_SCRIPT" >/dev/null 2>&1

    if [[ -z "$expected_call" ]] && [[ $(wc -l < "$calls_log") -eq 1 ]]; then
        echo "  ✅ ${description}"
        ((TESTS_PASSED++))
    elif [[ -n "$expected_call" ]] && grep -qF -- "$expected_call" "$calls_log"; then
        echo "  ✅ ${description}"
        ((TESTS_PASSED++))
    else
        echo "  ❌ ${description} (gh calls: $(tr '\n' ';' < "$calls_log"))"
        ((TESTS_FAILED++))
    fi
    rm -f "$calls_log"
}

run_comment_case "failure without comment creates one" fail "" \
    "api -X POST repos/org/repo/issues/7/comments -f body=<!-- check-pr-requirements -->"
run_comment_case "failure with comment updates it" fail "42" \
    "api -X PATCH repos/org/repo/issues/comments/42"
run_comment_case "pass with comment deletes it" pass "42" \
    "api -X DELETE repos/org/repo/issues/comments/42"
run_comment_case "pass without comment only looks it up" pass "" ""

rm -rf "$STUB_DIR"
print_results "comment" || exit 1
