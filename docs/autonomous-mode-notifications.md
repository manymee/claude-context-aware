# Autonomous Mode Notifications

## Problem

The current Stop hook only notifies Claude when it tries to stop. During long autonomous tasks with many consecutive tool calls, Claude won't be warned about rising context until it's potentially too late.

## Proposed Solution: Threshold-Crossing PostToolUse Hook

A PostToolUse hook that injects a system message only when context crosses a new threshold level for the first time.

### Behavior

1. After each tool use, check current context percentage
2. Track which thresholds have already been notified (via temp file per session)
3. Only inject a system message when crossing a NEW threshold
4. Thresholds: 40% (wrapping up), 50% (handoff), 60% (overshot), 65% (critical)

### Example Flow

```
Tool call #1  → 35% → no notification
Tool call #5  → 38% → no notification
Tool call #10 → 41% → NOTIFY: "Context at 41% — Consider preparing a handoff soon."
Tool call #15 → 48% → no notification (already notified for 40% tier)
Tool call #20 → 52% → NOTIFY: "Context at 52% — Handoff recommended."
...
```

### Implementation Notes

- Use something like `/tmp/claude-context-aware-{session_id}-{threshold}` to track notified thresholds
- Keep both Stop and PostToolUse hooks — Stop hook serves as final reminder when Claude tries to stop, PostToolUse catches rising context during autonomous work
