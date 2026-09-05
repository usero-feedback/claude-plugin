#!/usr/bin/env bash
set -euo pipefail

# Create a form for a client
# Usage: ./create-form.sh <clientId> <title> [description]

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
TITLE="${2:?Error: Form title required}"
DESCRIPTION="${3:-}"

# Build JSON payload
JSON=$(jq -n \
  --arg title "$TITLE" \
  --arg desc "$DESCRIPTION" \
  '{title: $title, description: $desc}')

RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$BASE_URL/clients/$CLIENT_ID/forms" \
  -H "Authorization: Bearer $USERO_API_KEY" \
  -H "Content-Type: application/json" \
  -d "$JSON")

HTTP_CODE=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | sed '$d')

if [[ "$HTTP_CODE" -ge 200 && "$HTTP_CODE" -lt 300 ]]; then
  echo "$BODY" | jq .
else
  echo "Error ($HTTP_CODE):"
  echo "$BODY" | jq . 2>/dev/null || echo "$BODY"
  exit 1
fi
