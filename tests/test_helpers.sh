#!/usr/bin/env bash

TESTS_TOTAL=0
TESTS_PASSED=0
TESTS_FAILED=0

_run_script() {
    local script="$1"
    local env_args=()
    for v in $(compgen -v INPUT_); do
        env_args+=("$v=${!v}")
    done
    # Run with clean INPUT_ env: only vars from this test case, not leaked from prior ones
    env -i "${env_args[@]}" PATH="$PATH" HOME="$HOME" \
        GITHUB_STEP_SUMMARY="${GITHUB_STEP_SUMMARY:-/dev/null}" \
        GITHUB_OUTPUT="${GITHUB_OUTPUT:-/dev/null}" \
        bash "$script" 2>&1
}

assert_pass() {
    local description="$1"
    local script="$2"
    shift 2

    ((TESTS_TOTAL++))
    local output
    output=$(_run_script "$script")
    local rc=$?

    if [[ "$rc" -eq 0 ]]; then
        echo "  ✅ ${description}"
        ((TESTS_PASSED++))
    else
        echo "  ❌ ${description} (expected pass, got exit ${rc}: ${output})"
        ((TESTS_FAILED++))
    fi
}

assert_fail() {
    local description="$1"
    local script="$2"
    shift 2

    ((TESTS_TOTAL++))
    local output
    output=$(_run_script "$script")
    local rc=$?

    if [[ "$rc" -ne 0 ]]; then
        echo "  ✅ ${description}"
        ((TESTS_PASSED++))
    else
        echo "  ❌ ${description} (expected fail, got pass: ${output})"
        ((TESTS_FAILED++))
    fi
}

assert_output_contains() {
    local description="$1"
    local script="$2"
    local expected="$3"

    ((TESTS_TOTAL++))
    local output
    output=$(_run_script "$script") || true

    if echo "$output" | grep -qF "$expected"; then
        echo "  ✅ ${description}"
        ((TESTS_PASSED++))
    else
        echo "  ❌ ${description} (output missing '${expected}', got: ${output})"
        ((TESTS_FAILED++))
    fi
}

print_results() {
    local name="$1"
    echo ""
    echo "  ${name}: ${TESTS_PASSED}/${TESTS_TOTAL} passed"
    if [[ "$TESTS_FAILED" -gt 0 ]]; then
        return 1
    fi
    return 0
}
