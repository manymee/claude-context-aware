# Session Continuation Approaches

This document covers the approaches explored for automatically continuing Claude Code sessions when the context window fills up.

**Goal**: When the context-aware plugin detects high context usage, seamlessly start a fresh session with a handoff of accumulated state — without requiring the user to manually intervene.

---

## 0. External Wrapper (`claude-continue.sh`) — initial approach

The first thing we tried: a bash script that wraps `claude -p` in a loop. When Claude stops, the script reads a handoff file and starts a new non-interactive session with the handoff content as the prompt. Works, but non-interactive — uses `claude -p` so there's no live terminal and you can't intervene mid-session. This motivated the search for an interactive solution.

---

## 1. Direct CLI Interaction (Experiment 1)

**What it does**: Attempted to have a Stop hook write commands (like `/compact`) directly to the Claude CLI's stdin, simulating user input from within a hook subprocess.

**How it works**: The hook tried 4 approaches to write to the parent process's stdin:
1. `/proc/$PPID/fd/0` — Linux procfs (not available on macOS)
2. `tty` device — hook subprocess has no tty
3. `/dev/tty` — writes to the display but doesn't reach CLI's input buffer
4. `/dev/stdin` — same as above

**Result**: Failed. Hooks run in a subprocess that has no access to the CLI's stdin. On macOS, `/proc` doesn't exist; `tty` returns "not a tty"; `/dev/tty` and `/dev/stdin` write to the terminal display but don't inject into the CLI's readline input.

**Discarded**: Fundamental limitation of the hook execution model. No workaround possible without changes to Claude Code itself.

**Script**: Was at `scripts/experiments/experiment-1/stop-self-compact.sh`

---

## 2. tmux Send-Keys (Experiment 2) — POC

**What it does**: Uses tmux `send-keys` to inject `/clear` and a continuation prompt into the terminal pane after Claude stops. Works because tmux bypasses the stdin limitation — it types into the terminal as if the user did.

**How it works** (two-phase stop):

1. **First stop** (`stop_hook_active=false`): The context-aware plugin blocks Claude from stopping. Claude writes a handoff file (`.claude/handoff.md`) with `continue: true` in YAML frontmatter.

2. **Second stop** (`stop_hook_active=true`): The stop hook checks for the handoff file. If `continue: true`:
   - Gets the current tmux pane ID
   - Backgrounds a subshell that will inject commands after Claude exits
   - Returns `{"decision": "approve"}` so Claude stops and releases the terminal

3. **After the stop**: The backgrounded subshell:
   - Waits 3 seconds for Claude to fully exit
   - Sends `/clear` via `tmux send-keys` (resets the session)
   - Waits 5 seconds for the fresh session to initialize
   - Sends `Continue from .claude/handoff.md` as a prompt — Claude reads the handoff file directly

**Result**: Works. Fully interactive — the new session is a normal Claude Code session where you can intervene, ask questions, guide the work.

**Kept**: Yes — promoted to POC. Script at `scripts/stop-tmux-inject.sh`.

**Note**: We initially had a SessionStart hook (`session-start-handoff.sh`) that injected the handoff content as `additionalContext` on `/clear`. This turned out to be redundant — the continuation prompt tells Claude to read the file directly, so the extra injection is unnecessary.

**Limitation**: Requires tmux. Timing is hardcoded (sleep delays). POC quality — not production-hardened.

---

## 3. External fswatch Watcher (Experiment 3)

**What it does**: An external process (run in a separate tmux pane) uses `fswatch` to watch for handoff file changes, then injects `/clear` + continuation prompt via tmux — similar to experiment 2, but decoupled from the hook.

**How it works**:
1. Start the watcher in a separate pane: `./watcher.sh --pane %0`
2. Watcher uses `fswatch` to monitor `.claude/handoff.md` for creation/updates
3. On change: debounce, wait, send `/clear`, wait, send continuation prompt
4. Configurable delays via flags (`--clear-delay`, `--prompt-delay`, `--debounce`)

**Advantages over experiment 2**:
- Decoupled from hook execution (no timing dependency on Claude's stop sequence)
- Configurable delays
- Visible logs in a separate pane
- Debouncing ensures file write is complete before acting

**Result**: Not tested. Was written as an alternative to experiment 2, but experiment 2 worked well enough that this was never needed.

**Discarded**: Superseded by experiment 2. The added complexity of running a separate watcher process wasn't justified given experiment 2's success. Could be revisited if timing issues in experiment 2 become problematic.

**Scripts**: Were at `scripts/experiments/experiment-3/`
