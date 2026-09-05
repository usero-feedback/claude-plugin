# Usero plugin for Claude Code

Read your user feedback inbox and clusters, file feedback, and open AI pull requests without leaving Claude Code.

```
/plugin marketplace add usero-feedback/claude-plugin
/plugin install usero@usero
```

Setup, the tool list and config for other MCP clients (Cursor, Claude Desktop, Windsurf, VS Code): https://usero.io/docs/mcp

The plugin's own README with install details lives at [`plugins/usero/README.md`](plugins/usero/README.md).

Root `.mcp.json` and `skills/` are copies for Open Plugins compatible scanners; the canonical plugin is `plugins/usero`.

## This repo is a mirror

This repository is a one-way mirror of the private Usero source. Every push to the source syncs `plugins/usero/` and
`.claude-plugin/marketplace.json` here; commits made directly to this repo get reverted by the next sync. Please report problems
through https://usero.io/contact?subject=Claude%20Code%20plugin rather than opening pull requests here.

## License

MIT, see [LICENSE](LICENSE).
