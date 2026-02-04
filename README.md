# context-aware

Monitors Claude Code context window usage and recommends handoff when thresholds are exceeded.

## Installation

```
/plugin marketplace add manymee/claude-context-aware
/plugin install context-aware@manymee
```

## How it works

A Stop hook runs when Claude tries to stop. If context usage exceeds the configured threshold, it blocks with an advisory message:

```
Context at 45% — Consider preparing a handoff soon.
```

Claude sees this message and can decide whether to prepare a handoff or continue working.

## Thresholds

| Threshold | Message                                |
|-----------|----------------------------------------|
| 40%       | Consider preparing a handoff soon.     |
| 50%       | Handoff recommended.                   |
| 60%       | Handoff strongly recommended.          |
| 65%       | Auto-compaction risk. Handoff advised. |

## Configuration

Add to `~/.claude/settings.json`:

```json
{
  "env": {
    "CONTEXT_AWARE_THRESHOLD_WRAPPING_UP": "40",
    "CONTEXT_AWARE_THRESHOLD_HANDOFF": "50",
    "CONTEXT_AWARE_THRESHOLD_OVERSHOT": "60",
    "CONTEXT_AWARE_THRESHOLD_CRITICAL": "65",
    "CONTEXT_AWARE_DEBUG": "1"
  }
}
```

All settings are optional — defaults work out of the box.
