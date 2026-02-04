#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOK_SCRIPT="$SCRIPT_DIR/context-monitor.sh"

# Test counters
PASSED=0
FAILED=0

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

run_test() {
  local name="$1"
  local input="$2"
  local expected_exit="$3"
  local expected_output="${4:-}"
  local env_vars="${5:-}"

  local actual_output
  local actual_exit

  if [[ -n "$env_vars" ]]; then
    actual_output=$(echo "$input" | env -S "$env_vars" bash "$HOOK_SCRIPT" 2>&1) && actual_exit=0 || actual_exit=$?
  else
    actual_output=$(echo "$input" | bash "$HOOK_SCRIPT" 2>&1) && actual_exit=0 || actual_exit=$?
  fi

  local failed=false

  if [[ "$actual_exit" -ne "$expected_exit" ]]; then
    failed=true
  fi

  if [[ -n "$expected_output" && "$actual_output" != *"$expected_output"* ]]; then
    failed=true
  fi

  if [[ "$failed" == "true" ]]; then
    echo -e "${RED}FAIL${NC}: $name"
    echo "  Expected exit: $expected_exit, got: $actual_exit"
    [[ -n "$expected_output" ]] && echo "  Expected output to contain: $expected_output"
    echo "  Actual output: $actual_output"
    ((++FAILED))
  else
    echo -e "${GREEN}PASS${NC}: $name"
    ((++PASSED))
  fi
}

# Create a temporary transcript file for testing
TEMP_TRANSCRIPT=$(mktemp)
trap "rm -f $TEMP_TRANSCRIPT" EXIT

# Write sample transcript data (low usage - should not block)
cat > "$TEMP_TRANSCRIPT" << 'EOF'
{"type":"assistant","message":{"model":"claude-opus-4-5-20251101","usage":{"input_tokens":100,"cache_creation_input_tokens":500,"cache_read_input_tokens":1000}}}
EOF

echo "Running tests..."
echo

# Test: Missing transcript_path should exit 1
run_test "missing transcript_path exits 1" \
  '{"stop_hook_active": false}' \
  1

# Test: Non-existent transcript file should exit 1
run_test "non-existent transcript file exits 1" \
  '{"stop_hook_active": false, "transcript_path": "/nonexistent/file.jsonl"}' \
  1

# Test: Already blocked should exit 0 (no action)
run_test "already blocked exits 0" \
  '{"stop_hook_active": true, "transcript_path": "'"$TEMP_TRANSCRIPT"'"}' \
  0

# Test: Low usage should exit 0 (no block needed)
run_test "low usage exits 0" \
  '{"stop_hook_active": false, "transcript_path": "'"$TEMP_TRANSCRIPT"'"}' \
  0

# Create high usage transcript (above wrapping_up threshold)
cat > "$TEMP_TRANSCRIPT" << 'EOF'
{"type":"assistant","message":{"model":"claude-opus-4-5-20251101","usage":{"input_tokens":50000,"cache_creation_input_tokens":30000,"cache_read_input_tokens":20000}}}
EOF

# Test: High usage should output block decision
run_test "high usage (50%) outputs block" \
  '{"stop_hook_active": false, "transcript_path": "'"$TEMP_TRANSCRIPT"'"}' \
  0 \
  '"decision": "block"'

# Create critical usage transcript
cat > "$TEMP_TRANSCRIPT" << 'EOF'
{"type":"assistant","message":{"model":"claude-opus-4-5-20251101","usage":{"input_tokens":100000,"cache_creation_input_tokens":50000,"cache_read_input_tokens":30000}}}
EOF

# Test: Critical usage shows auto-compaction warning
run_test "critical usage (90%) shows auto-compaction warning" \
  '{"stop_hook_active": false, "transcript_path": "'"$TEMP_TRANSCRIPT"'"}' \
  0 \
  "Auto-compaction"

# --- Environment variable tests ---

# Create low usage transcript for env var tests
cat > "$TEMP_TRANSCRIPT" << 'EOF'
{"type":"assistant","message":{"model":"claude-opus-4-5-20251101","usage":{"input_tokens":100,"cache_creation_input_tokens":500,"cache_read_input_tokens":1000}}}
EOF

# Test: Custom threshold triggers block at lower usage
# 1600 tokens / 200000 = 0.8%, but with threshold set to 0, it should block
run_test "custom threshold (0%) triggers block" \
  '{"stop_hook_active": false, "transcript_path": "'"$TEMP_TRANSCRIPT"'"}' \
  0 \
  '"decision": "block"' \
  "CONTEXT_AWARE_THRESHOLD_WRAPPING_UP=0"

# Test: DEBUG mode includes systemMessage
run_test "debug mode includes systemMessage" \
  '{"stop_hook_active": false, "transcript_path": "'"$TEMP_TRANSCRIPT"'"}' \
  0 \
  "systemMessage" \
  "CONTEXT_AWARE_THRESHOLD_WRAPPING_UP=0 CONTEXT_AWARE_DEBUG=1"

echo
echo "Results: $PASSED passed, $FAILED failed"
[[ "$FAILED" -eq 0 ]] && exit 0 || exit 1