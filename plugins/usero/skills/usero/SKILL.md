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

**No API key yet?** Do not send the user to a signup page. If the `usero` MCP server is connected but every tool answers 401, or
the only tools you see are `start_signup` and `check_signup`, run the signup from here: ask for the user's email, call
`start_signup(email, clientName: "Claude Code")`, tell the user Usero has emailed them (subject "Connect Claude Code to Usero")
and to press the button in it, then "Yes, connect Claude Code" on the page, and poll `check_signup(pollToken)` every 5 seconds
without ending your turn. It returns the API key once. Save it straight away: add `export USERO_API_KEY=<key>` to their shell
profile, then, only if `claude mcp list` already shows a `usero` server, `claude mcp remove usero` (Claude Code will not overwrite
a server name in place), then
`claude mcp add --transport http usero https://usero.io/mcp --header 'Authorization: Bearer ${USERO_API_KEY}'` (single quotes,
same scope the server was added with). Then `create_client(name, repo?)` for their product and `connect_github(clientId)` for the
install URL; poll `check_github(clientId)` until it lands. If the server is not connected at all, add it first with
`claude mcp add --transport http usero https://usero.io/mcp` (no header) and start from `start_signup`.

This skill gives you two ways in:

1. **MCP tools** (preferred). If the `usero` MCP server is connected you have tools named `list_clients`, `search_feedback` and so
   on. Use them. They return structured JSON, are scoped to the user's clients, and need no shell.
2. **REST scripts** (fallback). If no `usero` MCP tools are available, run the shell scripts in the `scripts/` directory next to
   this file. When loaded as a plugin that directory is `${CLAUDE_PLUGIN_ROOT}/skills/usero/scripts/`; when loaded from
   `~/.claude/skills/usero/` it is `~/.claude/skills/usero/scripts/`. Every script needs `USERO_API_KEY` in the environment (or in
   `~/.zshrc`).

How to tell which you have: look at your tool list for `list_clients` or `search_feedback`. Present means MCP. Absent means REST.
Do not run `claude mcp` commands to find out.

When no MCP tools are available, every action below has a REST script equivalent (see the table); `import-issue.sh` and
`form-analytics.sh` are that fallback for the two newest tools. Forms are MCP-first: `create_form`, `get_form`, `update_form` and
`delete_form` take typed fields and return the public link (`get_form_theme_options` and `preview_form_theme` theme one from a
brief without saving), so never fall back to `create-form.sh` or `update-form.sh` while those tools are present, and never read
Usero's source to find the field shape; the tool schema is the documentation. GitHub issue import and form analytics are MCP-first
too: prefer `import_github_issue` over `import-issue.sh` and `get_form_analytics` over `form-analytics.sh` while those tools are
present (the scripts stay as the no-MCP fallback).

## Setup the user needs once

- API key: `start_signup` from the agent (above), or https://usero.io/profile under API keys. Keys look like `usk_live_...` and
  are shown once.
- MCP path: install the plugin (`/plugin marketplace add usero-feedback/claude-plugin`, then `/plugin install usero@usero`) with
  `USERO_API_KEY` exported in the shell, or
  `claude mcp add --transport http usero https://usero.io/mcp --header "Authorization: Bearer usk_live_..."`.
- REST path: `export USERO_API_KEY="usk_live_..."` in `~/.zshrc`.
- Docs: https://usero.io/docs/mcp (MCP) and https://usero.io/docs/api (REST).

## MCP tools, and when to reach for each

Always start with `list_clients` unless the user has already given you a client id (ids start with `client_`).

| Tool                      | Use it when                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                |
| ------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `start_signup`            | No key. Args: `email`, `clientName` ("Claude Code"). Emails a confirm page link, returns `pollToken`. Tell the user to open it and press the confirm button.                                                                                                                                                                                                                                                                                                                                                                                                                                                                               |
| `check_signup`            | No key. Arg: `pollToken`. `pending` until the user confirms, then `ready` with `apiKey` once. Save the key immediately; the token is dead after.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                           |
| `create_client`           | The user has no client yet, or wants one for a new product. Args: `name`, optional `repo` (only if the GitHub App already reaches it; otherwise skip and use `connect_github`).                                                                                                                                                                                                                                                                                                                                                                                                                                                            |
| `connect_github`          | The client has no GitHub connection. Returns the install URL for the user to open. After the install, call again with `repo` if the installation covers several repositories.                                                                                                                                                                                                                                                                                                                                                                                                                                                              |
| `check_github`            | Polling after the user opened the install URL. `pending` until it lands, then `connected` with `repo` and `repos`.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                         |
| `list_clients`            | You need a client id, or the user asks which projects are on Usero. Returns a page (25 by default) of id, name, environments, open feedback count, plus `totalCount` and `hasMore`. Many clients: pass `nameContains` to narrow, or `offset: nextOffset` for the next page.                                                                                                                                                                                                                                                                                                                                                                |
| `search_feedback`         | "What are users saying about X", "recent feedback", "what did we resolve this week". Args: `clientId`, plus optional `query`, `status`, `source`, `environment`, `since` (created), `resolvedSince` (resolved), `sort` (newest, oldest, severity), `hasScreenshot`, `limit` (max 50). Defaults to open items, newest first. Bodies are cut at 400 chars.                                                                                                                                                                                                                                                                                   |
| `get_feedback`            | You have one feedback id and need the full item: comment, quotes, person, screenshots, replay link, clusters, pull requests.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               |
| `list_clusters`           | "What are the biggest complaints", "what should we fix first", triage. Args: `clientId`, optional `includeAddressed`, `limit`. Biggest first, each with up to three sample verbatim quotes, so a top-3 summary needs no further calls.                                                                                                                                                                                                                                                                                                                                                                                                     |
| `get_cluster`             | Drill into one cluster: members (default 50, `memberLimit` up to 200) with verbatim quotes and senders, plus its PR if one exists.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                         |
| `create_feedback`         | The user wants to log something into Usero ("file this as feedback", "add this bug to the inbox"). Args: `clientId`, `title`, `body`, optional `environment`, `pageUrl`, `userEmail`. Source is recorded as `mcp`.                                                                                                                                                                                                                                                                                                                                                                                                                         |
| `get_pr_status`           | Checking on an AI pull request for a feedback item. Returns status, URL, progress.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                         |
| `request_ai_pr`           | The user asks Usero to open an AI pull request for a feedback item. Usero's agent writes and opens it server-side; you do not need the repo checked out, no git or gh. Needs GitHub connected on the client. Optional `guidance` steers the fix. Capped at 5 per key per day. Confirm with the user before calling; it opens a PR on their repo.                                                                                                                                                                                                                                                                                           |
| `list_forms`              | The user asks about surveys or hosted forms for a client.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                  |
| `list_form_responses`     | Reading answers to one form. Args: `clientId`, `formId`, optional `page`, `limit` (max 50).                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                |
| `get_form`                | You need one form in full (fields with ids, settings, public URL, response count), always before `update_form`.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                            |
| `create_form`             | "Build me an NPS survey", "make a bug report form". Args: `clientId`, `title`, `fields` (typed list: text, textarea, email, number, select, radio, multiselect, checkbox, rating, scale; choice types take `options`, scale takes `min`/`max`/`minLabel`/`maxLabel`), optional `description`, `settings` (`surveyMetric: "nps"` with a 0 to 10 scale, `"csat"` with a rating, `"ces"` with a 1 to 7 scale; `appearance: { preset: "dark-slate" }` or another of minimal, warm-editorial, clean-saas, high-contrast to brand the page), `published`. Returns `publicUrl` to hand the user. The tool description carries a full NPS example. |
| `update_form`             | Changing a form. Only passed args change. `fields` replaces the whole list: `get_form` first, edit, send back whole, keep ids so old responses stay attached. `settings.appearance` takes a preset, the full theme from `get_form` with edits, or `null` to clear; a low-contrast theme is refused on a published form. `published: false` closes it.                                                                                                                                                                                                                                                                                      |
| `delete_form`             | Removing a form and all its responses. Irreversible; confirm with the user first. Prefer `update_form` with `published: false` to pause.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                   |
| `get_form_theme_options`  | Theming a form from a brief. Read once per session: schema, presets as full objects, textures, layouts, font pairings, contrast rules, worked examples. Pass `formId` to also see the current theme.                                                                                                                                                                                                                                                                                                                                                                                                                                       |
| `preview_form_theme`      | You have composed an appearance and want the user to see it before saving. Returns the contrast report and a signed one-hour `previewUrl` (no save, no submissions). Iterate here until `ok` is true and the user approves, then `update_form`.                                                                                                                                                                                                                                                                                                                                                                                            |
| `get_form_analytics`      | "How is this form converting", "which fields get skipped". Aggregate funnel for one form; use `list_form_responses` for individual answers. Args: `clientId`, `formId`. Returns sessions (unique visitors), views (page loads), submit attempts and successes, completion rate, average session duration, per-field completions and response count.                                                                                                                                                                                                                                                                                        |
| `import_github_issue`     | "File this issue in Usero", "import owner/repo#123". Args: `clientId`, `issueUrl`. Use only for a GitHub issue URL; use `create_feedback` for pasted text. Creates a feedback item from the issue that appears in inbox search and clusters; the URL must belong to the client's connected repo. Repeats return the existing item with `alreadyImported: true`. Providing the URL is the confirmation.                                                                                                                                                                                                                                     |
| `list_ai_user_test_runs`  | "What did the AI user tests find". Args: `clientId`, optional `environment` (omit to cover the default environment, feedback with no environment set), `limit` (max 50). Runs newest first with verdict (`clean` is the only pass), summary, finding counts and schedule flag. Read-only; starting runs and scheduling stay in the dashboard.                                                                                                                                                                                                                                                                                              |
| `get_ai_user_test_run`    | Drill into one AI test run: verdict (`clean` means no issues found), summary, whether on a schedule, every finding with severity, category, what happened and timestamp to jump to in the replay. Args: `clientId`, `runId`, optional `includeSteps` (step trace, large on long runs). Starting a run or changing its schedule stays in the dashboard.                                                                                                                                                                                                                                                                                     |
| `create_user_test`        | "Run a paid round on my checkout", "test the new landing page with 5 users". Args: `clientId`, `name`, `targetUrl`, `tasks` (1 to 20 prompts in order), optional `introMessage`, `rewardDollars` (e.g. "15"), `rewardCurrency`, `minDurationSeconds` (default 30, advisory only). Returns the participant `shareUrl` (`/ut/<slug>`) to hand the user.                                                                                                                                                                                                                                                                                      |
| `list_user_tests`         | "Show my user tests", "which tests have payouts waiting". Args: `clientId`, optional `limit` (max 50). Tests newest first with share URL, reward, task count, session counts by status and `readyToPayCount`.                                                                                                                                                                                                                                                                                                                                                                                                                              |
| `get_user_test`           | You need one test in full (tasks in order, counts) plus the 20 most recent sessions with status, payment state, quality flag and duration. Args: `clientId`, `testId`.                                                                                                                                                                                                                                                                                                                                                                                                                                                                     |
| `list_user_test_sessions` | Review a round. Args: `clientId`, `testId`, optional `status` and `paymentStatus` filters, `limit` (max 50). Sessions newest first with tester, payment state, quality flag, duration, audio flag, task and note counts, auto-release deadline.                                                                                                                                                                                                                                                                                                                                                                                            |
| `get_user_test_session`   | Drill into one session before paying it: tester, payout details, task completions with prompts, notes, transcript excerpt, research asset and replay pointers, findings, muted segments, end note. Audio stays in the dashboard. Args: `clientId`, `sessionId`.                                                                                                                                                                                                                                                                                                                                                                            |
| `update_user_test`        | Edit a test. Only passed args change. `tasks` replaces the whole list: `get_user_test` first, edit, send back whole; refused once the test has sessions, to protect completion history. `introMessage: ""` clears it, `rewardDollars: ""` makes the test unpaid. Other fields stay editable any time.                                                                                                                                                                                                                                                                                                                                      |
| `delete_user_test`        | Delete a test and its tasks; the share link stops resolving. Irreversible; confirm with the user first. Refused when the test has sessions, keeping session history. Args: `clientId`, `testId`.                                                                                                                                                                                                                                                                                                                                                                                                                                           |
| `release_payment`         | Mark a `ready_to_pay` session paid. Anything else returns an error naming the current status. Same guard as the dashboard. Confirm with the user first, naming the tester and reward. Args: `clientId`, `sessionId`.                                                                                                                                                                                                                                                                                                                                                                                                                       |

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
