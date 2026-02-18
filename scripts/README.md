# tmux Session Continuation (POC)

Interactive session continuation using tmux `send-keys`. When the context-aware plugin blocks Claude from stopping, Claude writes a handoff file, and after the second stop the hook automatically injects `/clear` + a continuation prompt into the tmux pane — starting a fresh interactive session with full handoff context.

See [approaches.md](approaches.md) for all approaches tried and why this one was chosen.

## Prerequisites

- `tmux` — Claude Code must be running inside a tmux session
- `jq` installed
- [context-aware](../plugins/context-aware/) plugin installed

## Setup

### 1. Hook configuration

Add to `.claude/settings.local.json`:

```json
{
  "hooks": {
    "Stop": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "bash \"$CLAUDE_PROJECT_DIR\"/scripts/stop-tmux-inject.sh"
          }
        ]
      }
    ]
  }
}
```

### 2. Test config (optional)

Use `scripts/test-config.json` to trigger at a low threshold for testing:

```bash
export CONTEXT_AWARE_CONFIG="$PWD/scripts/test-config.json"
```

This sets a single threshold at 5% so you can test the full loop quickly.

## How It Works

### Two-phase stop flow

1. **First stop** (`stop_hook_active=false`): The context-aware plugin blocks Claude from stopping and tells Claude to write a handoff. Claude writes `.claude/handoff.md` with `continue: true` in YAML frontmatter.

2. **Second stop** (`stop_hook_active=true`): Claude tries to stop again. This time `stop-tmux-inject.sh` reads the handoff file. If `continue: true`, it backgrounds a tmux injection sequence and returns `{"decision": "approve"}` so Claude stops.

3. **After Claude stops**: The backgrounded process waits, sends `/clear` via `tmux send-keys`, waits again, then sends `Continue from .claude/handoff.md` as a prompt. Claude reads the handoff file directly in the new session.

### Handoff format

```markdown
---
continue: true
---

# Task
What we're doing.

# Completed
- Done items

# Remaining
- Todo items

# Key Context
Important state for the next session.
```

Set `continue: false` (or omit the file) to stop the loop.

## Known Limitations

- **Requires tmux** — won't work in a plain terminal
- **Timing-dependent** — hardcoded `sleep` delays (3s before `/clear`, 5s before prompt); may need tuning
- **POC quality** — not production-hardened, no retry logic, no error recovery
- **Single pane** — assumes Claude is in the current tmux pane
- **Should be a plugin** — the tmux session continuation hooks should be packaged as a plugin (like context-aware) rather than loose scripts
- **Frontmatter overhead** — the `continue: true` YAML frontmatter check could be simplified: use a specific filename (e.g., `.claude/handoff-continue.md`) and just check for file presence instead of parsing frontmatter
