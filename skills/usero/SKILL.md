---
name: usero
description:
  Work with Usero, the user feedback tool, from inside the agent. Use whenever the user mentions Usero, asks what users are saying
  or complaining about, wants to see feedback, feedback clusters or form responses, wants to file feedback, wants a GitHub, Linear
  or Jira issue created from a feedback item, wants to build or edit a survey or feedback form and get its public link, asks
  whether Intercom or app reviews are syncing, or wants Usero to open or check an AI pull request for a feedback item (Usero
  writes the PR server-side). The usero MCP server tools cover all of that, including GitHub issue import and form analytics.
---

# Usero

Usero is the direct line from user to engineer.

Everything goes through the `usero` MCP server's tools (`list_clients`, `search_feedback`, `get_feedback`, `create_issue`,
`intercom_status` and so on). They return structured JSON, are scoped to the user's clients, and need no shell. Forms take typed
fields through `create_form`, `get_form`, `update_form` and `delete_form` and return the public link, so never read Usero's source
to find a field shape; the tool schema is the documentation.

**Not connected yet?** Look at your tool list for `list_clients` or `search_feedback`. If they are missing, the server needs a
sign-in, which only the user can do in the browser. Do not run `claude mcp` commands to find out. Tell the user:

- Installed as the Claude Code plugin: open `/mcp`, pick `usero`, choose Authenticate and approve in the browser. A new email gets
  an account on the way.
- Plugin not installed: `/plugin marketplace add usero-feedback/claude-plugin`, then `/plugin install usero@usero`, restart, and
  sign in as above.

## Setup the user needs once

- Claude Code plugin: install it and sign in through `/mcp` (above).
- Other MCP clients: the setup guide at https://usero.io/docs/mcp.

## MCP tools

The server lists every tool with its schema, and each description names the next step. Always start with `list_clients` unless the
user has already given you a client id (ids start with `client_`).

The `environment` argument is the environment name sent from the widget. Omit it to search every environment. The literal `no-env`
means feedback sent without one.

Resources you can pin instead of calling a tool: `usero://clients/{clientId}/clusters` and `usero://feedback/{id}`.

Prompt templates the server provides (`clientId` optional; omitted means the key's only client, or pick one via `list_clients`):
`get_first_feedback`, `triage_inbox`, `fix_top_complaint`, `write_changelog_from_feedback`. A new account with no feedback yet:
`create_form` gives a public link to share, no code needed.

### Typical MCP flows

**"What are users complaining about?"** `list_clients` if needed, then `list_clusters`, then `get_cluster` on the top one or two.
Quote users verbatim, name the cluster size, and say what you would fix first and why.

**"Fix the top complaint."** `list_clusters`, `get_cluster`, then find the cause in the current repo and fix it yourself.
Reference the feedback ids and a quote in the commit or PR body. Only call `request_ai_pr` if the user asks Usero to open the PR
rather than you.

**"Open an issue for this."** `get_feedback` on the item (its `issues` list shows any tracker issue already linked), then
`create_issue` with the `feedbackId`. Omit `title` and `body` for the dashboard draft, or pass your own; `tracker` is `github`,
`linear` or `jira` and defaults to the tracker selected in the client's settings. Reply with the identifier (`#123`, `ENG-12` or
`PROJ-123`) and URL; `alreadyLinked: true` means it already had one and nothing new was created. If the error says no tracker is
connected, point the user at the client's Integrations page rather than retrying.

**"Did that PR land?"** `get_pr_status` with the feedback id. Terminal statuses are `created`, `failed`, `blocked`.

**"Create an NPS survey and give me the link."** `list_clients` if needed, then `create_form` with a `scale` field (min 0, max 10,
end labels) plus a `textarea` follow-up and `settings: { surveyMetric: "nps" }`. Reply with `publicUrl`. No shell, no scripts.

**"Run a paid user test round."** `list_clients` if needed, then `create_user_test` (name, target URL, task prompts, reward) and
hand the user the `shareUrl`. To fix copy or settings later, `update_user_test` (tasks can only change before the first session).
When sessions land, `list_user_test_sessions` with `paymentStatus: "ready_to_pay"` to find payouts waiting,
`get_user_test_session` on each to review the transcript excerpt, findings and quality flag, then `release_payment` per session,
confirming with the user first each time (name the tester and the reward). No shell, no scripts.

**"How is this form converting?"** `get_form_analytics` with the `clientId` and `formId`. Quote the completion rate and the
per-field completions.

**"What did the AI user tests find?"** `list_ai_user_test_runs` for the verdicts (`clean` is the only pass), then
`get_ai_user_test_run` on the interesting runs to read the findings. Starting a run or changing its schedule stays in the
dashboard.

**"Sync my App Store / Play reviews."** `connect_app_reviews` with the `clientId` plus `appleAppId` (numeric, optional
`appleCountry`, default us) or `playPackageName` (at least one store id required), then poll `app_reviews_status` until the phase
is `done`. Prod Apple syncs often report a 403 in `lastSyncError` (Apple RSS blocks Workers egress) while Play lands first; a
Play-only connect avoids that. Disconnect stays in the dashboard.

**"Is Intercom syncing?" / "Pull my Intercom conversations now."** `intercom_status` with the `clientId` for what is connected and
when it last synced: `lastSyncedAt` is the run's wall clock, `lastPolledAt` is the newest item's `updated_at` (the cursor),
`diagnosis` says in plain words why nothing arrived (tag filter mismatch, expired token, nothing new), and `syncRuns` lists the
last 5 runs. `sync_intercom` queues a sync now and returns at once; poll `intercom_status` until a new run appears in `syncRuns`.
If it errors with "not connected", point the user at the client's Integrations page (OAuth connect stays in the dashboard).

**"Note that moment in the recording."** `note_replay_moment` with the `clientId`, exactly one of `sessionReplayId` (from
`get_feedback`) or `userTestSessionId` (from `list_user_test_sessions`), the `replayAtMs`, a one-line `title`, and optionally
`description`, `severity`, `pageUrl` and the participant's verbatim `quote`. The item lands in the inbox with source `replay-note`
and its replay link opens at that second.

**"Set me up with Usero."** Once the user has signed in through `/mcp`, `create_client`, then `connect_github` and `check_github`.
End by telling the user which client was created and whether GitHub is connected.

**"Theme this form like a warm print newsletter" (any brief).** Four steps, no dashboard:

1. `get_form_theme_options` with the `formId`. Read the presets, textures, layouts, pairings and the three worked examples once.
2. Compose one appearance object. Start from the closest preset or example and change only what the brief calls for: a texture
   (`background: { kind: "texture", color, textureId, textureStrength }`), a layout (`hero` for a landing-page feel, `focused` for
   one question at a time, `card` otherwise), a pairing (`editorial` serif, `geist`, `grotesk`, `inter`, `system`, `mono`), accent
   and text colours as 6-digit hex. Keep `version: 1` and `typography.family`.
3. `preview_form_theme` with that object. If `ok` is false, fix the blocking rows in `contrast.checks` (below 3:1 on body, input,
   error, button, or page text for hero/focused) by moving text toward black or white or changing the surface, then preview again.
   Give the user the `previewUrl` and say it lasts one hour, is not saved, and cannot be submitted.
4. On approval, `update_form` with `settings: { appearance: <the same object> }`. Mention that embeds (`?embed=1`) keep the card
   layout on a transparent page, so the texture and layout show on the hosted page only.

## Clients and PRs

**Creating a client with a repo fails unless the Usero GitHub App already has access to that repo**, which it never does for a
repo created moments ago:

```
"error": "GitHub App installation does not have access to owner/repo."
```

Leave out `repo` in `create_client` if the client only collects feedback. For PR generation, grant access at
https://github.com/settings/installations and run it again, or connect GitHub later from the client's Integrations page.

### PR status values

| Status       | Meaning                   | Terminal |
| ------------ | ------------------------- | -------- |
| `pending`    | Waiting to start          | no       |
| `queued`     | In the queue              | no       |
| `processing` | Claude Code is working    | no       |
| `created`    | PR opened                 | yes      |
| `failed`     | Error, see `errorMessage` | yes      |
| `blocked`    | Plan limit reached        | yes      |

Poll `get_pr_status` every 15 seconds until a terminal status.

## Adding the feedback widget to a project

Creating a client is half of it. The client is where feedback lands; the widget is what sends it. Docs:
https://usero.io/docs/widget

```bash
npm install @usero/sdk
```

```ts
import { initUseroFeedbackWidget } from '@usero/sdk'

initUseroFeedbackWidget({ clientId: 'client_...' })
```

There is also a CDN form (`<script src="https://unpkg.com/@usero/sdk">`, then `Usero.initUseroFeedbackWidget({...})`) for a plain
HTML page with no build step. Prefer the npm package for anything bundled, and for any app that runs locally or offline.

- It attaches its own shadow root to `document.body` and is not part of the React tree. Mount it once at the entry point, not
  inside a component that could remount.
- Wrap the call in `try/catch`. The widget failing to load must never take the host app down.
- It follows `prefers-color-scheme`; pass `theme` only to override.
- Omit the `environment` option for the default environment.

## Rules

- Sign-in happens only in the browser through `/mcp`, and Claude Code holds the session. Never ask the user to paste a secret.
- `request_ai_pr`, `create_issue`, `delete_form`, `delete_user_test` and `release_payment` have side effects on the user's repo,
  tracker or data. Say what you will do and confirm before running them, unless the user already asked for exactly that action.
- Quote users verbatim when summarising feedback. Paraphrase loses the signal the user came for.
