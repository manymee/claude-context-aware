# context-aware

Monitor Claude Code context window usage and get recommendations for handoffs before exhaustion.

## Installation

### 1. Add the marketplace and install

```
/plugin marketplace add manymee/claude-context-aware
/plugin install context-aware@manymee
```

### 2. Configure your statusline

The MCP server reads context data from `/tmp/claude-context.json`, which must be written by your statusline script.

**Add to your existing statusline:**

Source the script (reads from stdin, so must be first):

```bash
source /path/to/statusline.sh

# Your existing statusline code here...
```

Or copy the lines directly into your statusline script:

```bash
_ctx_input=$(cat)
_ctx_transcript=$(echo "$_ctx_input" | jq -r '.transcript_path // empty')
_ctx_max=$(echo "$_ctx_input" | jq -r '.context_window.context_window_size // empty')
if [[ -n "$_ctx_transcript" && -f "$_ctx_transcript" && -n "$_ctx_max" ]]; then
  _ctx_tokens=$(jq -s 'map(select(.message.usage and .isSidechain != true)) | last | if . then (.message.usage.input_tokens // 0) + (.message.usage.cache_read_input_tokens // 0) + (.message.usage.cache_creation_input_tokens // 0) else 0 end' < "$_ctx_transcript")
  [[ "$_ctx_tokens" -gt 0 ]] && _ctx_percentage=$((_ctx_tokens * 100 / _ctx_max))
fi
_ctx_remaining=${_ctx_percentage:+$((100-_ctx_percentage))}
echo "{\"used_percentage\":\"${_ctx_percentage:-unknown}\",\"remaining_percentage\":\"${_ctx_remaining:-unknown}\",\"context_size\":\"${_ctx_max:-unknown}\",\"updated_at\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"}" > /tmp/claude-context.json
```

### 3. Add instructions to CLAUDE.md

```markdown
## Context Awareness

You have access to `mcp__context-aware__check_context` tool. Use it:
- Every 10 tool calls during autonomous tasks
- Before starting any new major subtask
- When user asks you to work on something large

React to status levels:
- `normal` (0-40%): Continue working normally
- `wrapping_up` (40-50%): Finish current atomic unit, then prepare handoff
- `handoff` (50-60%): STOP new work. Write checkpoint/handoff now
- `overshot` (60-65%): Write quality handoff immediately
- `critical` (65%+): Auto-compaction imminent. Write handoff NOW
```

## How it works

```
Claude Code → Statusline Script → /tmp/claude-context.json → MCP Server → Claude
   (stdin JSON)    (writes data)                               (reads & responds)
```
