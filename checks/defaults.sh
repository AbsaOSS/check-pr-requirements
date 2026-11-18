#!/usr/bin/env bash
# shellcheck disable=SC2034 # consumed by scripts that source this file

# Defaults for configuration inputs, shared by the checks and the summary.
# Must match the input defaults in action.yml (enforced by tests/test_defaults.sh).

DEFAULT_TITLE_FORMATS="conventional"
DEFAULT_TITLE_TYPES="feat,fix,docs,style,refactor,perf,test,build,ci,chore,revert"
DEFAULT_DESCRIPTION_MIN_LENGTH="20"
DEFAULT_BRANCH_PATTERN='^(feature|bugfix|hotfix|release|support|chore|docs|ci|dependabot)/[a-zA-Z0-9._/-]+$'
DEFAULT_BRANCH_TICKET_PATTERN='^[^/]+/[0-9]+-'
DEFAULT_MAX_FILES_CHANGED="50"
DEFAULT_ALLOWED_TARGET_BRANCHES="main,master"
DEFAULT_RELEASE_NOTES_TAG='## [Rr]elease [Nn]otes'
DEFAULT_RELEASE_NOTES_SKIP_LABELS="no RN"
