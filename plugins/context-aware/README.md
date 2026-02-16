# context-aware

Monitors Claude Code context window usage and recommends handoff when thresholds are exceeded.

## Requirements

- [jq](https://jqlang.github.io/jq/) — used for JSON config parsing and threshold lookup

## Installation

```
/plugin marketplace add manymee/claude-plugins
/plugin install context-aware@manymee
```

## How it works

A Stop hook runs when Claude tries to stop. If context usage exceeds the configured threshold, it blocks with an advisory message:

```
[context-aware hook] Context at 45% — Consider preparing a handoff soon.
```

Claude sees this message and can decide whether to prepare a handoff or continue working.

## Default Thresholds

| Threshold | Message |
|-----------|---------|
| 40% | Context at {percent}% — Consider preparing a handoff soon. |
| 50% | Context at {percent}% — Handoff recommended. |
| 60% | Context at {percent}% — Handoff strongly recommended. |
| 65% | Context at {percent}% — Auto-compaction risk. Handoff advised. |

## Configuration

Configuration uses a JSON file with the following schema:

```json
{
  "context_size": 200000,
  "debug": false,
  "thresholds": [
    { "percent": 40, "message": "Context at {percent}% — Consider preparing a handoff soon." },
    { "percent": 50, "message": "Context at {percent}% — Handoff recommended." }
  ]
}
```

- `context_size` (optional) — Context window size in tokens. Default: `200000`.
- `debug` (optional) — Include raw hook input in output as `systemMessage`. Default: `false`.
- `thresholds` (required) — Array of threshold entries, each with:
  - `percent` — Number 0–100. Block triggers when usage >= this value.
  - `message` — Message template. `{percent}` is replaced with the actual usage percentage.

### Resolution chain

The first matching config file wins (no merging):

1. `$CONTEXT_AWARE_CONFIG` — explicit file path (env var)
2. `$CLAUDE_PROJECT_DIR/.claude/context-aware.json` — project-level override
3. `~/.claude/context-aware.json` — user global config
4. `default-config.json` (built-in) — shipped with the plugin, always exists

If a config file is found but fails validation, a warning is logged to stderr and the built-in default config is used.

### Environment variables

| Variable | Description |
|----------|-------------|
| `CONTEXT_AWARE_CONFIG` | Explicit path to a config JSON file |

Set via `~/.claude/settings.json`:

```json
{
  "env": {
    "CONTEXT_AWARE_CONFIG": "/path/to/my-config.json"
  }
}
```

### Example: project-level config

Create `.claude/context-aware.json` in your project root:

```json
{
  "thresholds": [
    { "percent": 30, "message": "Starting to fill up ({percent}%)." },
    { "percent": 50, "message": "Half full ({percent}%). Wrap up soon." }
  ]
}
```
