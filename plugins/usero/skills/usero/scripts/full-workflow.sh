#!/usr/bin/env bash
set -euo pipefail

# Full Usero workflow: create client, import issue, create PR, poll until done
# Usage: ./full-workflow.sh "Client Name" owner/repo <issueUrl> [guidance]

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

NAME="${1:?Error: Client name required}"
REPO="${2:?Error: GitHub repo required (owner/repo)}"
ISSUE_URL="${3:?Error: Issue URL required}"
GUIDANCE="${4:-}"

echo "=== Step 1: Create client ==="
CLIENT_RESPONSE=$("$SCRIPT_DIR/create-client.sh" "$NAME" "$REPO")
echo "$CLIENT_RESPONSE"
CLIENT_ID=$(echo "$CLIENT_RESPONSE" | jq -r '.client.clientId')

if [[ -z "$CLIENT_ID" || "$CLIENT_ID" == "null" ]]; then
  echo "Error: Failed to extract clientId"
  exit 1
fi
echo ""
echo "Client ID: $CLIENT_ID"

echo ""
echo "=== Step 2: Import issue ==="
IMPORT_RESPONSE=$("$SCRIPT_DIR/import-issue.sh" "$CLIENT_ID" "$ISSUE_URL")
echo "$IMPORT_RESPONSE"
FEEDBACK_ID=$(echo "$IMPORT_RESPONSE" | jq -r '.feedbackId')

if [[ -z "$FEEDBACK_ID" || "$FEEDBACK_ID" == "null" ]]; then
  echo "Error: Failed to extract feedbackId"
  exit 1
fi
echo ""
echo "Feedback ID: $FEEDBACK_ID"

echo ""
echo "=== Step 3: Create PR ==="
if [[ -n "$GUIDANCE" ]]; then
  PR_RESPONSE=$("$SCRIPT_DIR/create-pr.sh" "$CLIENT_ID" "$FEEDBACK_ID" "$GUIDANCE")
else
  PR_RESPONSE=$("$SCRIPT_DIR/create-pr.sh" "$CLIENT_ID" "$FEEDBACK_ID")
fi
echo "$PR_RESPONSE"
PR_ID=$(echo "$PR_RESPONSE" | jq -r '.prId')

if [[ -z "$PR_ID" || "$PR_ID" == "null" ]]; then
  echo "Error: Failed to extract prId"
  exit 1
fi
echo ""
echo "PR ID: $PR_ID"

echo ""
echo "=== Step 4: Polling for completion ==="
MAX_POLLS=60  # 15 minutes at 15s intervals
POLL_COUNT=0

while true; do
  POLL_COUNT=$((POLL_COUNT + 1))
  if [[ $POLL_COUNT -gt $MAX_POLLS ]]; then
    echo "Timeout after $MAX_POLLS polls. Check manually:"
    echo "  $SCRIPT_DIR/check-status.sh $CLIENT_ID $PR_ID"
    exit 1
  fi

  STATUS_RESPONSE=$("$SCRIPT_DIR/check-status.sh" "$CLIENT_ID" "$PR_ID" 2>/dev/null || echo '{"status":"error"}')
  STATUS=$(echo "$STATUS_RESPONSE" | jq -r '.status')
  PHASE=$(echo "$STATUS_RESPONSE" | jq -r '.progressPhase // empty')
  MESSAGE=$(echo "$STATUS_RESPONSE" | jq -r '.progressMessage // empty')

  echo "[$POLL_COUNT/$MAX_POLLS] Status: $STATUS ${PHASE:+($PHASE)} ${MESSAGE:+- $MESSAGE}"

  case $STATUS in
    created)
      PR_URL=$(echo "$STATUS_RESPONSE" | jq -r '.prUrl')
      echo ""
      echo "=== PR Created ==="
      echo "URL: $PR_URL"
      echo "$STATUS_RESPONSE" | jq .
      exit 0
      ;;
    failed|blocked)
      ERROR=$(echo "$STATUS_RESPONSE" | jq -r '.errorMessage')
      echo ""
      echo "=== Failed ==="
      echo "Error: $ERROR"
      echo "$STATUS_RESPONSE" | jq .
      exit 1
      ;;
    error)
      echo "API error, retrying..."
      ;;
    *)
      sleep 15
      ;;
  esac
done
