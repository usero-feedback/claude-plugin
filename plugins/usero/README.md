# Usero plugin for Claude Code

Read your user feedback inbox and clusters, file feedback, and open AI pull requests without leaving Claude Code.

The plugin bundles two things:

- The config for the **usero MCP server** at `https://usero.io/mcp` (10 tools, 2 resources, 3 prompt templates; the full list is
  at https://usero.io/docs/mcp).
- A **skill** that teaches Claude when to reach for those tools ("what are users complaining about?", "fix the top complaint",
  "did that PR land?") and falls back to bundled REST scripts when the MCP server is not connected.

## Get an API key

Sign in at https://usero.io/profile and create a key under API keys. It looks like `usk_live_...` and is shown once. The key acts
as you: the agent sees every client you are a member of and nothing else.

## Install

### Path 1: the plugin (MCP server + skill)

Export the key in your shell so the plugin's MCP config can read it, then add the marketplace and install:

```bash
export USERO_API_KEY="usk_live_..."   # put this in ~/.zshrc or ~/.bashrc
```

Inside Claude Code:

```
/plugin marketplace add usero-feedback/claude-plugin
/plugin install usero@usero
```

Or from a terminal:

```bash
claude plugin marketplace add usero-feedback/claude-plugin
claude plugin install usero@usero
```

Restart Claude Code, then check `/mcp` shows `usero` with its tools. Try: "list my usero clients".

The MCP config reads `USERO_API_KEY` from the environment (`${USERO_API_KEY}` expansion in `.mcp.json`). If it is unset, Claude
Code warns in `/mcp` and `claude mcp list` naming the variable and every call returns 401.

### Path 2: just the MCP server

If you only want the tools and not the skill:

```bash
claude mcp add --transport http usero https://usero.io/mcp --header "Authorization: Bearer usk_live_..."
```

Add `--scope user` to make it available in every project. Check with `claude mcp list`.

### Not on Claude Code?

This plugin is Claude Code only. Cursor, Windsurf, Claude Desktop, VS Code and any other MCP client connect to the same server
with the config block for your client at https://usero.io/docs/mcp.

## Testing a local checkout

```bash
claude plugin validate ./plugins/usero
USERO_API_KEY=usk_live_... claude --plugin-dir ./plugins/usero
```

Then `/mcp` should list `usero`, and `/usero:usero` invokes the skill. `/reload-plugins` picks up edits without restarting.

## Layout

```
plugins/usero/
  .claude-plugin/plugin.json   name, version, homepage
  .mcp.json                    the remote MCP server, key from $USERO_API_KEY
  skills/usero/SKILL.md        when and how to use the tools, REST fallback
  skills/usero/scripts/*.sh    REST scripts (curl + jq) over https://usero.io/api/v1
```

Plugin and marketplace format: https://code.claude.com/docs/en/plugins and https://code.claude.com/docs/en/plugin-marketplaces.
Environment variable expansion in `.mcp.json`: https://code.claude.com/docs/en/mcp#environment-variable-expansion-in-mcp-json.

## Versioning

The plugin version (`plugin.json` and the marketplace entry) bumps on every tool, resource or prompt change to the server, in step
with the changelog table at https://usero.io/docs/mcp. Tools are never removed inside 90 days of being announced.
