---
name: usero
description:
  Work with Usero, the user feedback tool, from inside the agent. Use whenever the user mentions Usero, asks what users are saying
  or complaining about, wants to see feedback, feedback clusters or form responses, wants to file feedback, wants to build or edit
  a survey or feedback form and get its public link, or wants Usero to open or check an AI pull request for a feedback item (Usero
  writes the PR server-side). The MCP server tools cover all of that; the bundled REST scripts additionally import GitHub issues
  and read form analytics, and are the fallback when no MCP server is connected.
allowed-tools: Bash
---

# Usero

Usero turns user feedback into shipped code.

**No API key yet?** If no `usero` tools are visible at all, connect the server first with
`claude mcp add --transport http usero https://usero.io/mcp` (no header), then load the `start_signup` tool and follow it. Ask for
the user's email, call it, tell the user to open the email and press the button, then keep polling `check_signup` until it returns
the key. Each tool description names the next step, so follow those, ending with `create_client` and `connect_github`.

This skill gives you two ways in:

1. **MCP tools** (preferred). If the `usero` MCP server is connected you have tools named `list_clients`, `search_feedback` and so
   on. Use them. They return structured JSON, are scoped to the user's clients, and need no shell.
2. **REST scripts** (fallback). If no `usero` MCP tools are available, run the shell scripts in the `scripts/` directory next to
   this file. When loaded as a plugin that directory is `${CLAUDE_PLUGIN_ROOT}/skills/usero/scripts/`; when loaded from
   `~/.claude/skills/usero/` it is `~/.claude/skills/usero/scripts/`. Every script needs `USERO_API_KEY` in the environment (or in
   `~/.zshrc`).

How to tell which you have: look at your tool list for `list_clients` or `search_feedback`. Present means MCP. Absent means REST.
Do not run `claude mcp` commands to find out.

When no MCP tools are available, the REST scripts below cover the same actions (`import-issue.sh` and `form-analytics.sh` are that
fallback for the two newest tools). Forms are MCP-first: `create_form`, `get_form`, `update_form` and `delete_form` take typed
fields and return the public link (`get_form_theme_options` and `preview_form_theme` theme one from a brief without saving), so
never read Usero's source to find the field shape; the tool schema is the documentation. GitHub issue import and form analytics
are MCP-first too: prefer `import_github_issue` over `import-issue.sh` and `get_form_analytics` over `form-analytics.sh` while
those tools are present (the scripts stay as the no-MCP fallback).

## Setup the user needs once

- API key: `start_signup` from the agent (above), or https://usero.io/profile under API keys. Keys look like `usk_live_...` and
  are shown once.
- MCP path: install the plugin (`/plugin marketplace add usero-feedback/claude-plugin`, then `/plugin install usero@usero`) with
  `USERO_API_KEY` exported in the shell, or
  `claude mcp add --transport http usero https://usero.io/mcp --header "Authorization: Bearer usk_live_..."`.
- REST path: `export USERO_API_KEY="usk_live_..."` in `~/.zshrc`.
- Docs: https://usero.io/docs/mcp (MCP) and https://usero.io/docs/api (REST).

## MCP tools

The server lists every tool with its schema, and each description names the next step. Always start with `list_clients` unless the
user has already given you a client id (ids start with `client_`).

The `environment` argument is the environment name sent from the widget. Omit it to search every environment. The literal `no-env`
means feedback sent without one.

Resources you can pin instead of calling a tool: `usero://clients/{clientId}/clusters` and `usero://feedback/{id}`.

Prompt templates the server provides (`clientId` optional; omitted means the key's only client, or pick one via `list_clients`):
`triage_inbox`, `fix_top_complaint`, `write_changelog_from_feedback`.

### Typical MCP flows

**"What are users complaining about?"** `list_clients` if needed, then `list_clusters`, then `get_cluster` on the top one or two.
Quote users verbatim, name the cluster size, and say what you would fix first and why.

**"Fix the top complaint."** `list_clusters`, `get_cluster`, then find the cause in the current repo and fix it yourself.
Reference the feedback ids and a quote in the commit or PR body. Only call `request_ai_pr` if the user asks Usero to open the PR
rather than you.

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

**"Note that moment in the recording."** `note_replay_moment` with the `clientId`, exactly one of `sessionReplayId` (from
`get_feedback`) or `userTestSessionId` (from `list_user_test_sessions`), the `replayAtMs`, a one-line `title`, and optionally
`description`, `severity`, `pageUrl` and the participant's verbatim `quote`. The item lands in the inbox with source `replay-note`
and its replay link opens at that second.

**"Set me up with Usero."** `start_signup`, wait for the click via `check_signup`, save the key, `create_client`, then
`connect_github` and `check_github`. End by telling the user which client was created and whether GitHub is connected.

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

## REST scripts (fallback, and REST-only actions)

Base URL `https://usero.io/api/v1`, auth `Authorization: Bearer $USERO_API_KEY`. Set `USERO_API_BASE_URL` to point at another
deployment. Every script prints JSON on success and `Error (<code>)` plus the body on failure.

| Script                                                     | Does                                                                                                    | MCP equivalent        |
| ---------------------------------------------------------- | ------------------------------------------------------------------------------------------------------- | --------------------- |
| `create-client.sh "Name" [owner/repo]`                     | Creates a client. Repo is optional and only for PR generation; see the note below.                      | `create_client`       |
| `import-issue.sh <clientId> <issueUrl>`                    | Imports a GitHub issue as feedback. URL must match the client's repo. Idempotent. Returns `feedbackId`. | `import_github_issue` |
| `create-pr.sh <clientId> <feedbackId> [guidance]`          | Asks Usero to open an AI PR. Returns `prId`. Asynchronous.                                              | `request_ai_pr`       |
| `check-status.sh <clientId> <prId>`                        | PR status. Terminal: `created`, `failed`, `blocked`.                                                    | `get_pr_status`       |
| `full-workflow.sh "Name" owner/repo <issueUrl> [guidance]` | Create client, import issue, open PR, poll until terminal (15 min cap).                                 | none                  |
| `list-feedback.sh <clientId> [page] [limit] [environment]` | Feedback items with pagination.                                                                         | `search_feedback`     |
| `list-forms.sh <clientId>`                                 | Forms with response counts.                                                                             | `list_forms`          |
| `create-form.sh <clientId> <title> [description]`          | Creates an empty form. Returns `id` and `slug`. Field JSON shape: https://usero.io/docs/forms#api       | `create_form`         |
| `get-form.sh <clientId> <formId>`                          | One form with fields, settings, response count.                                                         | `get_form`            |
| `update-form.sh <clientId> <formId> '<json>'`              | Updates `title`, `description`, `fields`, `settings`, `published`.                                      | `update_form`         |
| `delete-form.sh <clientId> <formId>`                       | Deletes a form and all its responses. Confirm with the user first.                                      | `delete_form`         |
| `list-responses.sh <clientId> <formId> [page] [limit]`     | Form responses, paginated.                                                                              | `list_form_responses` |
| `form-analytics.sh <clientId> <formId>`                    | Sessions, views, completion rate, per-field completion.                                                 | `get_form_analytics`  |

**Creating a client with a repo fails unless the Usero GitHub App already has access to that repo**, which it never does for a
repo created moments ago:

```
"error": "GitHub App installation does not have access to owner/repo."
```

Drop the repo argument if the client only collects feedback. For PR generation, grant access at
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

Poll every 15 seconds. `full-workflow.sh` does this for you.

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

- Never print an API key, except that the key `check_signup` returns must be written into the MCP config and `USERO_API_KEY` right
  away (that is the one place it exists). Scripts read it from the environment; the MCP header is set by the plugin config.
- `request_ai_pr`, `delete_form`, `delete_user_test`, `release_payment`, `create-pr.sh`, `delete-form.sh` and `full-workflow.sh`
  have side effects on the user's repo or data. Say what you are about to do and confirm before running them, unless the user
  already asked for exactly that action.
- Quote users verbatim when summarising feedback. Paraphrase loses the signal the user came for.
