# Context-aware MCP data writer
# Source this in your statusline script, or copy these lines.

_ctx_input=$(cat)
_ctx_transcript=$(echo "$_ctx_input" | jq -r '.transcript_path // empty')
_ctx_max=$(echo "$_ctx_input" | jq -r '.context_window.context_window_size // empty')
if [[ -n "$_ctx_transcript" && -f "$_ctx_transcript" && -n "$_ctx_max" ]]; then
  _ctx_tokens=$(jq -s 'map(select(.message.usage and .isSidechain != true)) | last | if . then (.message.usage.input_tokens // 0) + (.message.usage.cache_read_input_tokens // 0) + (.message.usage.cache_creation_input_tokens // 0) else 0 end' < "$_ctx_transcript")
  [[ "$_ctx_tokens" -gt 0 ]] && _ctx_percentage=$((_ctx_tokens * 100 / _ctx_max))
fi
_ctx_remaining=${_ctx_percentage:+$((100-_ctx_percentage))}
echo "{\"used_percentage\":\"${_ctx_percentage:-unknown}\",\"remaining_percentage\":\"${_ctx_remaining:-unknown}\",\"context_size\":\"${_ctx_max:-unknown}\",\"updated_at\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"}" > /tmp/claude-context.json
