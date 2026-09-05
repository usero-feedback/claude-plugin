#!/usr/bin/env bash
set -euo pipefail

# Get form analytics summary
# Usage: ./form-analytics.sh <clientId> <formId>

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

RESPONSE=$(curl -s -w "\n%{http_code}" "$BASE_URL/clients/$CLIENT_ID/forms/$FORM_ID/analytics" \
  -H "Authorization: Bearer $USERO_API_KEY")

HTTP_CODE=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | sed '$d')

if [[ "$HTTP_CODE" -ge 200 && "$HTTP_CODE" -lt 300 ]]; then
  echo "$BODY" | jq .
else
  echo "Error ($HTTP_CODE):"
  echo "$BODY" | jq . 2>/dev/null || echo "$BODY"
  exit 1
fi
