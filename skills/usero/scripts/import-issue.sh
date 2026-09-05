#!/usr/bin/env bash
set -euo pipefail

# Import a GitHub issue into Usero as feedback
# Usage: ./import-issue.sh <clientId> <issueUrl>

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
ISSUE_URL="${2:?Error: Issue URL required (e.g. https://github.com/owner/repo/issues/123)}"

RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$BASE_URL/clients/$CLIENT_ID/import-issue" \
  -H "Authorization: Bearer $USERO_API_KEY" \
  -H "Content-Type: application/json" \
  -d "$(jq -n --arg url "$ISSUE_URL" '{issueUrl: $url}')")

HTTP_CODE=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | sed '$d')

if [[ "$HTTP_CODE" -ge 200 && "$HTTP_CODE" -lt 300 ]]; then
  echo "$BODY" | jq .
else
  echo "Error ($HTTP_CODE):"
  echo "$BODY" | jq . 2>/dev/null || echo "$BODY"
  exit 1
fi
