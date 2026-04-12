# Claude Code Configs

A collection of my personal configuration files for [Claude Code](https://docs.anthropic.com/en/docs/claude-code).

## What's included

### Status Line

A custom status line script (`statusline/statusline-command.sh`) that displays:

- **Git branch** -- current branch or detached HEAD
- **Model & effort level** -- which model is active and the configured effort level
- **Context window** -- tokens used / total with color-coded percentage (green < 50%, yellow < 80%, red >= 80%)
- **Rate limits** -- 5-hour and 7-day usage percentages with the same color coding

**Requirements:** `jq` and `git` must be available on your `PATH`.

## Setup

1. Copy the statusline script to your Claude config directory:

```bash
cp statusline/statusline-command.sh ~/.claude/statusline-command.sh
```

2. Add the following to your `~/.claude/settings.json`:

```json
{
  "statusLine": {
    "type": "command",
    "command": "bash ~/.claude/statusline-command.sh"
  }
}
```

3. Restart Claude Code.

## License

MIT
