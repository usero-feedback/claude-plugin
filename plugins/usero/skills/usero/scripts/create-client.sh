#!/usr/bin/env bash
set -euo pipefail

# Create a Usero client.
# Usage: ./create-client.sh "Client Name" [owner/repo]
#
# The repo is OPTIONAL. It is only needed for the PR-generation flow (import an
# issue, have Claude open a PR against it). A client that just collects widget
# feedback needs no repo, and asking for one fails: the API rejects a repo the
# Usero GitHub App cannot see, which is every repo it has not been installed on,
# including any repo created moments ago.

# Source API key from ~/.zshrc if not already in environment
if [[ -z "${USERO_API_KEY:-}" && -f ~/.zshrc ]]; then
  USERO_API_KEY=$(sed -n "s/^export USERO_API_KEY=[\"']*\([^\"']*\)[\"']*/\1/p" ~/.zshrc | head -1)
fi

if [[ -z "${USERO_API_KEY:-}" ]]; then
  echo "Error: USERO_API_KEY not found in environment or ~/.zshrc"
  echo ""
  echo "Add to ~/.zshrc:"
  echo '  export USERO_API_KEY="usk_live_..."'
  exit 1
fi

BASE_URL="${USERO_API_BASE_URL:-https://usero.io/api/v1}"
NAME="${1:?Error: Client name required (e.g. \"My Project Demo\")}"
REPO="${2:-}"

if [[ -n "$REPO" ]]; then
  PAYLOAD=$(jq -n --arg name "$NAME" --arg repo "$REPO" '{name: $name, githubRepo: $repo}')
else
  PAYLOAD=$(jq -n --arg name "$NAME" '{name: $name}')
fi

RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$BASE_URL/clients" \
  -H "Authorization: Bearer $USERO_API_KEY" \
  -H "Content-Type: application/json" \
  -d "$PAYLOAD")

HTTP_CODE=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | sed '$d')

if [[ "$HTTP_CODE" -ge 200 && "$HTTP_CODE" -lt 300 ]]; then
  echo "$BODY" | jq .
else
  echo "Error ($HTTP_CODE):"
  echo "$BODY" | jq . 2>/dev/null || echo "$BODY"
  # The most common cause, and the fix is not obvious from the message alone.
  if [[ -n "$REPO" ]] && echo "$BODY" | grep -q "GitHub App installation"; then
    echo ""
    echo "The Usero GitHub App has no access to $REPO."
    echo "  - Only creating a client for feedback? Drop the repo argument, it is optional."
    echo "  - Need PR generation? Grant the app access at"
    echo "    https://github.com/settings/installations, then run this again."
  fi
  exit 1
fi
