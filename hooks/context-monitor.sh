#!/bin/bash
set -euo pipefail

readonly THRESHOLD_WRAPPING_UP="${CONTEXT_AWARE_THRESHOLD_WRAPPING_UP:-40}"
readonly THRESHOLD_HANDOFF="${CONTEXT_AWARE_THRESHOLD_HANDOFF:-50}"
readonly THRESHOLD_OVERSHOT="${CONTEXT_AWARE_THRESHOLD_OVERSHOT:-60}"
readonly THRESHOLD_CRITICAL="${CONTEXT_AWARE_THRESHOLD_CRITICAL:-65}"
readonly DEFAULT_CONTEXT_SIZE="${CONTEXT_AWARE_DEFAULT_CONTEXT_SIZE:-200000}"
readonly DEBUG="${CONTEXT_AWARE_DEBUG:-}"

exit_if_already_blocked() {
  local input="$1"
  local stop_hook_active
  stop_hook_active=$(echo "$input" | jq -r '.stop_hook_active // false')
  if [[ "$stop_hook_active" == "true" ]]; then
    exit 0
  fi
}

get_transcript_path() {
  local input="$1"
  local transcript_path
  transcript_path=$(echo "$input" | jq -r '.transcript_path // empty')
  if [[ -z "$transcript_path" || ! -f "$transcript_path" ]]; then
    exit 1
  fi
  echo "$transcript_path"
}

get_context_size_for_model() {
  local model="$1"

  # All current Claude models have 200K context
  case "$model" in
    claude-opus-4-5*|claude-3-5*|claude-3-opus*|claude-3-sonnet*|claude-3-haiku*)
      echo "$DEFAULT_CONTEXT_SIZE"
      ;;
    *)
      echo "$DEFAULT_CONTEXT_SIZE"
      ;;
  esac
}

get_context_size() {
  local transcript_path="$1"
  local model
  model=$(jq -rs 'map(select(.message.model)) | first | .message.model // "unknown"' < "$transcript_path")
  get_context_size_for_model "$model"
}

get_token_count() {
  local transcript_path="$1"
  jq -s '
    map(select(.message.usage and .isSidechain != true))
    | last
    | if . then
        (.message.usage.input_tokens // 0)
        + (.message.usage.cache_read_input_tokens // 0)
        + (.message.usage.cache_creation_input_tokens // 0)
      else 0 end
  ' < "$transcript_path"
}

get_reason() {
  local percentage=$1
  local prefix="[Hook] Context at ${percentage}% —"

  if [[ $percentage -lt $THRESHOLD_WRAPPING_UP ]]; then
    return 1  # No action needed
  elif [[ $percentage -lt $THRESHOLD_HANDOFF ]]; then
    echo "$prefix Consider preparing a handoff soon."
  elif [[ $percentage -lt $THRESHOLD_OVERSHOT ]]; then
    echo "$prefix Handoff recommended."
  elif [[ $percentage -lt $THRESHOLD_CRITICAL ]]; then
    echo "$prefix Handoff strongly recommended."
  else
    echo "$prefix Auto-compaction risk. Handoff advised."
  fi
}

output_block_decision() {
  local reason="$1"
  local input="$2"

  if [[ -n "$DEBUG" ]]; then
    jq -n --arg reason "$reason" --arg debug "$input" \
      '{"decision": "block", "reason": $reason, "systemMessage": $debug}'
  else
    jq -n --arg reason "$reason" \
      '{"decision": "block", "reason": $reason}'
  fi
}

main() {
  local input
  input=$(cat)

  # Prevent infinite loops: if we already blocked once, let Claude stop
  exit_if_already_blocked "$input"

  local transcript_path
  transcript_path=$(get_transcript_path "$input")

  local context_size
  context_size=$(get_context_size "$transcript_path")

  local token_count
  token_count=$(get_token_count "$transcript_path")

  local percentage=$((token_count * 100 / context_size))

  local reason
  reason=$(get_reason "$percentage") || exit 0

  output_block_decision "$reason" "$input"
}

main
