#!/usr/bin/env bash
set -euo pipefail

# Validates PR source branch name against a pattern.
# Inputs via env vars:
#   INPUT_PR_BRANCH     - Branch name to validate (required)
#   INPUT_BRANCH_PATTERN - Regex pattern (default: standard prefixes)

BRANCH="${INPUT_PR_BRANCH:?PR branch name is required}"
PATTERN="${INPUT_BRANCH_PATTERN:-^(feature|bugfix|hotfix|release|chore|docs|ci|dependabot)/[a-zA-Z0-9._-]+$}"

if [[ "$BRANCH" =~ $PATTERN ]]; then
    echo "pass"
    exit 0
else
    echo "fail: branch name '$BRANCH' does not match pattern '$PATTERN'"
    exit 1
fi
