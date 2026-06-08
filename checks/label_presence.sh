#!/usr/bin/env bash
set -euo pipefail

# Validates that PR has required labels.
# Inputs via env vars:
#   INPUT_LABELS          - Comma-separated list of PR labels (required)
#   INPUT_REQUIRED_LABELS - Comma-separated required labels (empty = at least one label)

LABELS="${INPUT_LABELS:-}"
REQUIRED="${INPUT_REQUIRED_LABELS:-}"

if [[ -z "$LABELS" ]]; then
    echo "fail: PR has no labels"
    exit 1
fi

if [[ -z "$REQUIRED" ]]; then
    echo "pass"
    exit 0
fi

IFS=',' read -ra REQUIRED_ARRAY <<< "$REQUIRED"
IFS=',' read -ra LABEL_ARRAY <<< "$LABELS"

MISSING=()
for req in "${REQUIRED_ARRAY[@]}"; do
    req_trimmed=$(echo "$req" | xargs)
    FOUND=false
    for label in "${LABEL_ARRAY[@]}"; do
        label_trimmed=$(echo "$label" | xargs)
        if [[ "$label_trimmed" == "$req_trimmed" ]]; then
            FOUND=true
            break
        fi
    done
    if [[ "$FOUND" == "false" ]]; then
        MISSING+=("$req_trimmed")
    fi
done

if [[ ${#MISSING[@]} -gt 0 ]]; then
    echo "fail: missing required labels: ${MISSING[*]}"
    exit 1
fi

echo "pass"
exit 0
