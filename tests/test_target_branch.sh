#!/usr/bin/env bash
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/test_helpers.sh"
CHECK="${SCRIPT_DIR}/../checks/target_branch.sh"

# ── Pass cases ───────────────────────────────────────────────────────────────

INPUT_ALLOWED_TARGET_BRANCHES="" \
INPUT_TARGET_BRANCH="main" \
    assert_pass "targets main" "$CHECK"

INPUT_ALLOWED_TARGET_BRANCHES="" \
INPUT_TARGET_BRANCH="master" \
    assert_pass "targets master" "$CHECK"

INPUT_TARGET_BRANCH="develop" INPUT_ALLOWED_TARGET_BRANCHES="main,develop" \
    assert_pass "custom allowed branch" "$CHECK"

INPUT_TARGET_BRANCH="develop" INPUT_ALLOWED_TARGET_BRANCHES=" main , develop " \
    assert_pass "allowed list with surrounding whitespace" "$CHECK"

INPUT_TARGET_BRANCH="develop" INPUT_ALLOWED_TARGET_BRANCHES="" INPUT_REPO_DEFAULT_BRANCH="develop" \
    assert_pass "empty allowed list falls back to repository default branch" "$CHECK"

INPUT_TARGET_BRANCH="develop" INPUT_ALLOWED_TARGET_BRANCHES="main" INPUT_REPO_DEFAULT_BRANCH="develop" \
    assert_fail "explicit allowed list wins over repository default branch" "$CHECK"

INPUT_TARGET_BRANCH="main" INPUT_ALLOWED_TARGET_BRANCHES="" INPUT_REPO_DEFAULT_BRANCH="develop" \
    assert_fail "repository default branch replaces main,master" "$CHECK"

# ── Fail cases ───────────────────────────────────────────────────────────────

INPUT_ALLOWED_TARGET_BRANCHES="" \
INPUT_TARGET_BRANCH="develop" \
    assert_fail "targets develop (not allowed by default)" "$CHECK"

INPUT_ALLOWED_TARGET_BRANCHES="" \
INPUT_TARGET_BRANCH="feature/something" \
    assert_fail "targets feature branch" "$CHECK"

INPUT_TARGET_BRANCH="main" INPUT_ALLOWED_TARGET_BRANCHES="develop,staging" \
    assert_fail "main not in custom list" "$CHECK"

# ── Glob patterns ────────────────────────────────────────────────────────────

INPUT_TARGET_BRANCH="support/1.0.4" INPUT_ALLOWED_TARGET_BRANCHES="main,support/*" \
    assert_pass "glob matches support branch" "$CHECK"

INPUT_TARGET_BRANCH="release/v2.0" INPUT_ALLOWED_TARGET_BRANCHES="main,release/*" \
    assert_pass "glob matches release branch" "$CHECK"

INPUT_TARGET_BRANCH="develop" INPUT_ALLOWED_TARGET_BRANCHES="main,support/*" \
    assert_fail "glob does not match unrelated branch" "$CHECK"

INPUT_TARGET_BRANCH="support" INPUT_ALLOWED_TARGET_BRANCHES="support/*" \
    assert_fail "glob requires the slash" "$CHECK"

# ── Stacked PRs ──────────────────────────────────────────────────────────────

# A fake gh answering the stacks lookup with INPUT_STUB_STACKS_RESPONSE (exit 1 when unset).
STUB_DIR="$(mktemp -d)"
cat > "${STUB_DIR}/gh" <<'STUB'
#!/usr/bin/env bash
[[ -n "${INPUT_STUB_STACKS_RESPONSE:-}" ]] || exit 1
echo "$INPUT_STUB_STACKS_RESPONSE"
STUB
chmod +x "${STUB_DIR}/gh"
PATH="${STUB_DIR}:$PATH"

STACK_WITH_LAYER_BELOW='[{"pull_requests":[
  {"number":10,"state":"open","head":{"ref":"feature/layer-1"}},
  {"number":11,"state":"open","head":{"ref":"feature/layer-2"}}]}]'

stacked_pr() {
    INPUT_TARGET_BRANCH="feature/layer-1" INPUT_PR_NUMBER="11" GITHUB_REPOSITORY="org/repo" "$@"
}

INPUT_STUB_STACKS_RESPONSE="$STACK_WITH_LAYER_BELOW" stacked_pr \
    assert_pass "PR targeting the head of the open PR below it in its stack" "$CHECK"

INPUT_STUB_STACKS_RESPONSE="$STACK_WITH_LAYER_BELOW" INPUT_ALLOW_STACKED_PRS="false" stacked_pr \
    assert_fail "stacked PRs disabled rejects the layer below" "$CHECK"

INPUT_STUB_STACKS_RESPONSE="[]" stacked_pr \
    assert_fail "PR not in any stack is rejected" "$CHECK"

INPUT_STUB_STACKS_RESPONSE="$STACK_WITH_LAYER_BELOW" INPUT_TARGET_BRANCH="develop" INPUT_PR_NUMBER="11" GITHUB_REPOSITORY="org/repo" \
    assert_fail "stacked PR targeting a branch outside its stack is rejected" "$CHECK"

INPUT_STUB_STACKS_RESPONSE='[{"pull_requests":[{"number":10,"state":"closed","head":{"ref":"feature/layer-1"}},{"number":11,"state":"open","head":{"ref":"feature/layer-2"}}]}]' stacked_pr \
    assert_fail "closed PR below does not count" "$CHECK"

INPUT_STUB_STACKS_RESPONSE='[{"pull_requests":[{"number":11,"state":"open","head":{"ref":"feature/layer-1"}}]}]' stacked_pr \
    assert_fail "PR's own head does not count as the layer below" "$CHECK"

stacked_pr \
    assert_fail "failed stacks lookup is rejected" "$CHECK"

INPUT_TARGET_BRANCH="feature/layer-1" GITHUB_REPOSITORY="org/repo" INPUT_STUB_STACKS_RESPONSE="$STACK_WITH_LAYER_BELOW" \
    assert_fail "missing PR number is rejected" "$CHECK"

print_results "target_branch" || exit 1
