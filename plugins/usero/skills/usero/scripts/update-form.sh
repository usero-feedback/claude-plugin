#!/usr/bin/env bash
set -euo pipefail

# Update a form
# Usage: ./update-form.sh <clientId> <formId> <json-data>
# Example: ./update-form.sh abc123 form456 '{"title":"New Title","published":false}'

# Source API key from ~/.zshrc if not already in environment
if [[ -z "${USERO_API_KEY:-}" && -f ~/.zshrc ]]; then
  USERO_API_KEY=$(sed -n "s/^export USERO_API_KEY=[\"']*\([^\"']*\)[\"']*/\1/p" ~/.zshrc | head -1)
fi

if [[ -z "${USERO_API_KEY:-}" ]]; then
  echo "Error: USERO_API_KEY not found in environment or ~/.zshrc"
  exit 1
fi

BASE_URL="${USERO_API_BASE_URL:-https://usero.io/api/v1}"
CLIENT_ID="${1:?Error: Client ID required}"
FORM_ID="${2:?Error: Form ID required}"
JSON_DATA="${3:?Error: JSON data required (e.g. '{\"title\":\"New Title\"}')}"

# Validate JSON
if ! echo "$JSON_DATA" | jq . > /dev/null 2>&1; then
  echo "Error: Invalid JSON data"
  exit 1
fi

RESPONSE=$(curl -s -w "\n%{http_code}" -X PUT "$BASE_URL/clients/$CLIENT_ID/forms/$FORM_ID" \
  -H "Authorization: Bearer $USERO_API_KEY" \
  -H "Content-Type: application/json" \
  -d "$JSON_DATA")

HTTP_CODE=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | sed '$d')

if [[ "$HTTP_CODE" -ge 200 && "$HTTP_CODE" -lt 300 ]]; then
  echo "$BODY" | jq .
else
  echo "Error ($HTTP_CODE):"
  echo "$BODY" | jq . 2>/dev/null || echo "$BODY"
  exit 1
fi
