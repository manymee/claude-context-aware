# context-aware — Development

## Files
- `default-config.json` — source of truth for default thresholds/settings
- `hooks/context-monitor.sh` — stop hook script (requires jq)
- `hooks/context-monitor.test.sh` — test suite, run with `bash plugins/context-aware/hooks/context-monitor.test.sh`

## Claude Code Stop Hook API
- `reason` — visible to Claude (the AI); drives Claude's behavior
- `systemMessage` — visible to the user in the UI
- `"decision": "block"` prevents Claude from stopping; `"approve"` allows it
- Non-blocking user-facing messages: `{"decision": "approve", "systemMessage": "..."}`

## Config Resolution Chain
`$CONTEXT_AWARE_CONFIG` → `$CLAUDE_PROJECT_DIR/.claude/context-aware.json` → `~/.claude/context-aware.json` → `default-config.json`

## Style
- `[context-aware hook]` prefix on all hook output messages
- Use `return 1` (not `exit 1`) in functions for graceful error handling with `set -euo pipefail`
