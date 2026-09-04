---
name: usero
description:
  Work with Usero, the user feedback tool, from inside the agent. Use whenever the user mentions Usero, asks what users are saying
  or complaining about, wants to see feedback, feedback clusters or form responses, wants to file feedback, or wants Usero to open
  or check an AI pull request for a feedback item (Usero writes the PR server-side). The MCP server tools cover all of that; the
  bundled REST scripts additionally create clients, import GitHub issues and manage forms, and are the fallback when no MCP server
  is connected.
allowed-tools: Bash
---

# Usero

Usero turns user feedback into shipped code. This skill gives you two ways in:

1. **MCP tools** (preferred). If the `usero` MCP server is connected you have tools named `list_clients`, `search_feedback` and so
   on. Use them. They return structured JSON, are scoped to the user's clients, and need no shell.
2. **REST scripts** (fallback). If no `usero` MCP tools are available, run the shell scripts in the `scripts/` directory next to
   this file. When loaded as a plugin that directory is `${CLAUDE_PLUGIN_ROOT}/skills/usero/scripts/`; when loaded from
   `~/.claude/skills/usero/` it is `~/.claude/skills/usero/scripts/`. Every script needs `USERO_API_KEY` in the environment (or in
   `~/.zshrc`).

How to tell which you have: look at your tool list for `list_clients` or `search_feedback`. Present means MCP. Absent means REST.
Do not run `claude mcp` commands to find out.

Some actions exist only on REST (creating a client, importing a GitHub issue, creating or editing forms, form analytics). For
those, use the scripts even when MCP is connected.

## Setup the user needs once

- API key: https://usero.io/profile, under API keys. Keys look like `usk_live_...` and are shown once.
- MCP path: install the plugin (`/plugin marketplace add usero-feedback/claude-plugin`, then `/plugin install usero@usero`) with
  `USERO_API_KEY` exported in the shell, or
  `claude mcp add --transport http usero https://usero.io/mcp --header "Authorization: Bearer usk_live_..."`.
- REST path: `export USERO_API_KEY="usk_live_..."` in `~/.zshrc`.
- Docs: https://usero.io/docs/mcp (MCP) and https://usero.io/docs/api (REST).

## MCP tools, and when to reach for each

Always start with `list_clients` unless the user has already given you a client id (ids start with `client_`).

| Tool                  | Use it when                                                                                                                                                                                                                                                                                                                                              |
| --------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `list_clients`        | You need a client id, or the user asks which projects are on Usero. Returns id, name, environments, feedback counts.                                                                                                                                                                                                                                     |
| `search_feedback`     | "What are users saying about X", "recent feedback", "what did we resolve this week". Args: `clientId`, plus optional `query`, `status`, `source`, `environment`, `since` (created), `resolvedSince` (resolved), `sort` (newest, oldest, severity), `hasScreenshot`, `limit` (max 50). Defaults to open items, newest first. Bodies are cut at 400 chars. |
| `get_feedback`        | You have one feedback id and need the full item: comment, quotes, person, screenshots, replay link, clusters, pull requests.                                                                                                                                                                                                                             |
| `list_clusters`       | "What are the biggest complaints", "what should we fix first", triage. Args: `clientId`, optional `includeAddressed`, `limit`. Biggest first, each with up to three sample verbatim quotes, so a top-3 summary needs no further calls.                                                                                                                   |
| `get_cluster`         | Drill into one cluster: members (default 50, `memberLimit` up to 200) with verbatim quotes and senders, plus its PR if one exists.                                                                                                                                                                                                                       |
| `create_feedback`     | The user wants to log something into Usero ("file this as feedback", "add this bug to the inbox"). Args: `clientId`, `title`, `body`, optional `environment`, `pageUrl`, `userEmail`. Source is recorded as `mcp`.                                                                                                                                       |
| `get_pr_status`       | Checking on an AI pull request for a feedback item. Returns status, URL, progress.                                                                                                                                                                                                                                                                       |
| `request_ai_pr`       | The user asks Usero to open an AI pull request for a feedback item. Usero's agent writes and opens it server-side; you do not need the repo checked out, no git or gh. Needs GitHub connected on the client. Optional `guidance` steers the fix. Capped at 5 per key per day. Confirm with the user before calling; it opens a PR on their repo.         |
| `list_forms`          | The user asks about surveys or hosted forms for a client.                                                                                                                                                                                                                                                                                                |
| `list_form_responses` | Reading answers to one form. Args: `clientId`, `formId`, optional `page`, `limit` (max 50).                                                                                                                                                                                                                                                              |

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

## REST scripts (fallback, and REST-only actions)

Base URL `https://usero.io/api/v1`, auth `Authorization: Bearer $USERO_API_KEY`. Set `USERO_API_BASE_URL` to point at another
deployment. Every script prints JSON on success and `Error (<code>)` plus the body on failure.

| Script                                                     | Does                                                                                                    | MCP equivalent        |
| ---------------------------------------------------------- | ------------------------------------------------------------------------------------------------------- | --------------------- |
| `create-client.sh "Name" [owner/repo]`                     | Creates a client. Repo is optional and only for PR generation; see the note below.                      | none (REST only)      |
| `import-issue.sh <clientId> <issueUrl>`                    | Imports a GitHub issue as feedback. URL must match the client's repo. Idempotent. Returns `feedbackId`. | none (REST only)      |
| `create-pr.sh <clientId> <feedbackId> [guidance]`          | Asks Usero to open an AI PR. Returns `prId`. Asynchronous.                                              | `request_ai_pr`       |
| `check-status.sh <clientId> <prId>`                        | PR status. Terminal: `created`, `failed`, `blocked`.                                                    | `get_pr_status`       |
| `full-workflow.sh "Name" owner/repo <issueUrl> [guidance]` | Create client, import issue, open PR, poll until terminal (15 min cap).                                 | none                  |
| `list-feedback.sh <clientId> [page] [limit] [environment]` | Feedback items with pagination.                                                                         | `search_feedback`     |
| `list-forms.sh <clientId>`                                 | Forms with response counts.                                                                             | `list_forms`          |
| `create-form.sh <clientId> <title> [description]`          | Creates a form. Returns `id` and `slug`.                                                                | none (REST only)      |
| `get-form.sh <clientId> <formId>`                          | One form with fields, settings, response count.                                                         | none (REST only)      |
| `update-form.sh <clientId> <formId> '<json>'`              | Updates `title`, `description`, `fields`, `settings`, `published`.                                      | none (REST only)      |
| `delete-form.sh <clientId> <formId>`                       | Deletes a form and all its responses. Confirm with the user first.                                      | none (REST only)      |
| `list-responses.sh <clientId> <formId> [page] [limit]`     | Form responses, paginated.                                                                              | `list_form_responses` |
| `form-analytics.sh <clientId> <formId>`                    | Sessions, views, completion rate, per-field completion.                                                 | none (REST only)      |

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

- Never print an API key. Scripts read it from the environment; the MCP header is set by the plugin config.
- `request_ai_pr`, `create-pr.sh`, `delete-form.sh` and `full-workflow.sh` have side effects on the user's repo or data. Say what
  you are about to do and confirm before running them, unless the user already asked for exactly that action.
- Quote users verbatim when summarising feedback. Paraphrase loses the signal the user came for.
