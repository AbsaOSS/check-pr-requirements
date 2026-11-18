#!/usr/bin/env bash
set -euo pipefail

# Reports the result of the AbsaOSS/release-notes-presence-check step, which
# runs before check.sh, so release notes share the summary table, counts and
# "How to fix" with the other checks.
# Inputs via env vars:
#   INPUT_RELEASE_NOTES_OUTCOME - Outcome of that step: success, failure or
#                                 skipped/empty when it did not run

OUTCOME="${INPUT_RELEASE_NOTES_OUTCOME:-}"

case "$OUTCOME" in
    success)
        echo "pass"
        exit 0
        ;;
    failure)
        echo "fail: release notes are missing, not a bullet list, or a placeholder (see the release notes step log)"
        exit 1
        ;;
    *)
        echo "fail: release notes result unavailable (the release notes step did not run)"
        exit 1
        ;;
esac
