#!/bin/bash
# Claude Code Custom Status Line
# Displays: current directory | git status | model | context usage | input/output tokens
#
# This script receives JSON input via stdin from Claude Code with session information.
# It outputs a formatted status line with ANSI color codes.

set -euo pipefail

# Read JSON input from stdin
readonly INPUT=$(cat)

# Extract values from JSON
readonly CWD=$(echo "$INPUT" | jq -r ".workspace.current_dir")
readonly MODEL=$(echo "$INPUT" | jq -r ".model.display_name")
readonly SESSION_ID=$(echo "$INPUT" | jq -r ".session_id")
readonly TOTAL_INPUT=$(echo "$INPUT" | jq -r ".context_window.total_input_tokens")
readonly TOTAL_OUTPUT=$(echo "$INPUT" | jq -r ".context_window.total_output_tokens")
readonly CONTEXT_SIZE=$(echo "$INPUT" | jq -r ".context_window.context_window_size")

# Calculate totals
readonly TOTAL_TOKENS=$((TOTAL_INPUT + TOTAL_OUTPUT))
readonly USAGE_PCT=$(awk "BEGIN {printf \"%.1f\", ($TOTAL_TOKENS / $CONTEXT_SIZE) * 100}")
readonly INPUT_K=$(awk "BEGIN {printf \"%.1fK\", $TOTAL_INPUT / 1000}")
readonly OUTPUT_K=$(awk "BEGIN {printf \"%.1fK\", $TOTAL_OUTPUT / 1000}")
readonly TOTAL_K=$(awk "BEGIN {printf \"%.1fK\", $TOTAL_TOKENS / 1000}")
readonly CONTEXT_K=$(awk "BEGIN {printf \"%.0fK\", $CONTEXT_SIZE / 1000}")

# Get git information if in a git repository
GIT_INFO=""
if cd "$CWD" 2>/dev/null && git rev-parse --git-dir > /dev/null 2>&1; then
    BRANCH=$(git --no-optional-locks branch --show-current 2>/dev/null)
    if [ -n "$BRANCH" ]; then
        if git --no-optional-locks diff-index --quiet HEAD -- 2>/dev/null; then
            GIT_STATUS="✓"
        else
            GIT_STATUS="●"
        fi
        GIT_INFO=" | git:$BRANCH$GIT_STATUS"
    fi
fi

# Format display path (replace home directory with ~)
readonly DISPLAY_CWD="${CWD/#$HOME/~}"

# Output formatted status line with ANSI colors:
# - Cyan (36m) for directory
# - Magenta (35m) for model
# - Yellow (33m) for context usage
# - Green (32m) for input/output breakdown
printf "\033[36m%s\033[0m%s | \033[35m%s\033[0m | \033[33mctx:%s/%s (%s%%)\033[0m | \033[32m↑%s ↓%s\033[0m" \
    "$DISPLAY_CWD" "$GIT_INFO" "$MODEL" "$TOTAL_K" "$CONTEXT_K" "$USAGE_PCT" "$INPUT_K" "$OUTPUT_K"
