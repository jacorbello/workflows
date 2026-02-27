#!/usr/bin/env bash
set -euo pipefail

# Substitutes {{VAR}} placeholders in workflow.json with values from .env
# Usage: ./scripts/prepare-workflow.sh <workflow-dir>
# Output: <workflow-dir>/workflow.local.json

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 <workflow-dir>" >&2
  echo "Example: $0 n8n/cal-prospects" >&2
  exit 1
fi

WORKFLOW_DIR="$1"
ENV_FILE="$WORKFLOW_DIR/.env"
INPUT="$WORKFLOW_DIR/workflow.json"
OUTPUT="$WORKFLOW_DIR/workflow.local.json"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "Error: $ENV_FILE not found" >&2
  exit 1
fi

if [[ ! -f "$INPUT" ]]; then
  echo "Error: $INPUT not found" >&2
  exit 1
fi

# Read workflow
content=$(<"$INPUT")

# Read .env and substitute each {{VAR}} placeholder
while IFS='=' read -r key value; do
  [[ -z "$key" || "$key" =~ ^# ]] && continue
  content="${content//\{\{$key\}\}/$value}"
done < "$ENV_FILE"

# Check for any remaining unsubstituted placeholders
remaining=$(grep -oP '\{\{[A-Z_]+\}\}' <<< "$content" || true)
if [[ -n "$remaining" ]]; then
  echo "Warning: unresolved placeholders:" >&2
  echo "$remaining" >&2
fi

printf '%s\n' "$content" > "$OUTPUT"
echo "Wrote $OUTPUT"
