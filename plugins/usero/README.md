# Usero plugin for Claude Code

Read your user feedback inbox and clusters, file feedback, and open AI pull requests without leaving Claude Code.

The plugin bundles two things:

- The config for the **usero MCP server** at `https://usero.io/mcp` (the full tool list is at https://usero.io/docs/mcp).
- A **skill** that teaches Claude when to reach for those tools ("what are users complaining about?", "fix the top complaint",
  "did that PR land?").

## Install

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

## Sign in

The plugin has no API key to set. It connects with OAuth: on first use Claude Code shows that `usero` needs authentication. Open
`/mcp`, pick `usero`, choose Authenticate, and approve the connection in the browser (a new email gets an account on the way).
Claude Code stores and refreshes the token itself, so nothing lands in your shell profile or config files. From a terminal,
`claude mcp login plugin:usero:usero` does the same.

Check `/mcp` shows `usero` connected with its tools, then try: "list my usero clients". The token acts as you: the agent sees
every client you are a member of and nothing else.

### Upgrading from 0.11 or earlier

Earlier versions read an API key from an environment variable in your shell. 0.12.0 doesn't: run `/plugin update usero@usero` (or
`claude plugin update usero@usero`), restart, and sign in once through `/mcp` as above. You can then delete that export from your
shell profile unless another tool uses it, and revoke the key on https://usero.io/profile. The bundled REST scripts are gone too;
every action they covered is an MCP tool.

## Just the MCP server, or a static key

If you only want the tools and not the skill, or you run Claude Code headless (`claude -p`, CI) where the browser sign-in can't
happen, add the server yourself with an API key from https://usero.io/profile (keys look like `usk_live_...` and are shown once):

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
claude --plugin-dir ./plugins/usero
```

Then `/mcp` should list `usero` (authenticate it there), and `/usero:usero` invokes the skill. `/reload-plugins` picks up edits
without restarting.

## Layout

```
plugins/usero/
  .claude-plugin/plugin.json   name, version, homepage, icon, privacy policy
  .mcp.json                    the remote MCP server, OAuth sign-in (?auth=oauth)
  assets/icon.png              512x512 listing icon
  skills/usero/SKILL.md        when and how to use the tools
```

Plugin and marketplace format: https://code.claude.com/docs/en/plugins and https://code.claude.com/docs/en/plugin-marketplaces.
MCP OAuth in Claude Code: https://code.claude.com/docs/en/mcp#authenticate-with-remote-mcp-servers.

## Versioning

The plugin version (`plugin.json` and the marketplace entry) bumps on every tool, resource or prompt change to the server, in step
with the changelog table at https://usero.io/docs/mcp. Tools are never removed inside 90 days of being announced.
