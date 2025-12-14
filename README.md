# Claude Code Custom Status Line

A custom status line configuration for Claude Code that displays contextual information about your session, including current directory, git status, model name, and context window usage.

## What It Looks Like

```
~/dev/project | git:main✓ | Claude Sonnet 4.5 | ctx:22.5K/200K (11.3%) | ↑5.2K ↓17.3K
```

## Features

- **Current Directory** (cyan) - Shows your working directory with `~` for home
- **Git Status** - Shows branch name with status indicator:
  - `✓` = clean working tree
  - `●` = uncommitted changes
- **Model Name** (magenta) - Displays which Claude model you're using
- **Context Usage** (yellow) - Shows tokens used/total (percentage)
- **Input/Output Breakdown** (green) - Shows ↑input and ↓output tokens separately

## Installation

### Option 1: Reference this script directly

Add to your `~/.claude/settings.json`:

```json
{
  "statusLine": {
    "type": "command",
    "command": "/Users/chris/dev/github/chrisvaillancourt/claude-statusline/statusline.sh"
  }
}
```

### Option 2: Use inline command

Add to your `~/.claude/settings.json`:

```json
{
  "statusLine": {
    "type": "command",
    "command": "/bin/bash -c 'set -euo pipefail; readonly INPUT=$(cat); readonly CWD=$(echo \"$INPUT\" | jq -r \".workspace.current_dir\"); readonly MODEL=$(echo \"$INPUT\" | jq -r \".model.display_name\"); readonly SESSION_ID=$(echo \"$INPUT\" | jq -r \".session_id\"); readonly TOTAL_INPUT=$(echo \"$INPUT\" | jq -r \".context_window.total_input_tokens\"); readonly TOTAL_OUTPUT=$(echo \"$INPUT\" | jq -r \".context_window.total_output_tokens\"); readonly CONTEXT_SIZE=$(echo \"$INPUT\" | jq -r \".context_window.context_window_size\"); readonly TOTAL_TOKENS=$((TOTAL_INPUT + TOTAL_OUTPUT)); readonly USAGE_PCT=$(awk \"BEGIN {printf \\\"%.1f\\\", ($TOTAL_TOKENS / $CONTEXT_SIZE) * 100}\"); readonly INPUT_K=$(awk \"BEGIN {printf \\\"%.1fK\\\", $TOTAL_INPUT / 1000}\"); readonly OUTPUT_K=$(awk \"BEGIN {printf \\\"%.1fK\\\", $TOTAL_OUTPUT / 1000}\"); readonly TOTAL_K=$(awk \"BEGIN {printf \\\"%.1fK\\\", $TOTAL_TOKENS / 1000}\"); readonly CONTEXT_K=$(awk \"BEGIN {printf \\\"%.0fK\\\", $CONTEXT_SIZE / 1000}\"); GIT_INFO=\"\"; if cd \"$CWD\" 2>/dev/null && git rev-parse --git-dir > /dev/null 2>&1; then BRANCH=$(git --no-optional-locks branch --show-current 2>/dev/null); if [ -n \"$BRANCH\" ]; then if git --no-optional-locks diff-index --quiet HEAD -- 2>/dev/null; then GIT_STATUS=\"✓\"; else GIT_STATUS=\"●\"; fi; GIT_INFO=\" | git:$BRANCH$GIT_STATUS\"; fi; fi; readonly DISPLAY_CWD=\"${CWD/#$HOME/~}\"; printf \"\\033[36m%s\\033[0m%s | \\033[35m%s\\033[0m | \\033[33mctx:%s/%s (%s%%)\\033[0m | \\033[32m↑%s ↓%s\\033[0m\" \"$DISPLAY_CWD\" \"$GIT_INFO\" \"$MODEL\" \"$TOTAL_K\" \"$CONTEXT_K\" \"$USAGE_PCT\" \"$INPUT_K\" \"$OUTPUT_K\"'"
  }
}
```

### Option 3: Use the `/statusline` command

Run `/statusline` in Claude Code and ask Claude to set it up based on this configuration.

## Development Journey

### What We Learned

1. **JSON Input Structure**: Claude Code passes session information to the status line script via stdin as JSON
2. **Context Window Fields Exist**: The `context_window` object is available but not documented in the official docs
3. **Session Isolation**: Each Claude Code session runs its status line command independently
4. **Update Frequency**: Status line updates at most every 300ms when conversation messages update

### Issues Encountered

#### Issue 1: Cross-Session Model Name Contamination

**Problem**: When running multiple Claude Code sessions simultaneously (one with Sonnet, one with Opus 4.5), the status line was showing the wrong model name (Opus 4.5 in a Sonnet session).

**Root Cause**: The original inline bash command used lowercase variable names (e.g., `$model`) which could be shared across sessions or have race conditions when multiple sessions executed simultaneously.

**Solution**:
- Used explicit bash subprocess invocation (`/bin/bash -c`)
- Added strict error handling (`set -euo pipefail`)
- Changed all variables to `readonly` to prevent overwrites
- Used uppercase variable names (e.g., `$MODEL` instead of `$model`)
- Captured input once as `readonly INPUT` and parsed all values from it

**Technical Details**:
```bash
# Before (vulnerable to cross-contamination)
input=$(cat); model=$(echo "$input" | jq -r '.model.display_name')

# After (isolated and protected)
readonly INPUT=$(cat); readonly MODEL=$(echo "$INPUT" | jq -r ".model.display_name")
```

#### Issue 2: Documentation Gaps

**Problem**: The official Claude Code documentation doesn't mention `context_window` fields, but they're available and working.

**What We Tried**:
1. Checked official docs at `~/.claude/plugins/.../references/statusline.md`
2. Created a test to capture the actual JSON being passed to the status line
3. Compared documented fields vs actual fields

**Discovery**: Found these undocumented but working fields:
- `context_window.total_input_tokens`
- `context_window.total_output_tokens`
- `context_window.context_window_size`
- `exceeds_200k_tokens`

**Solution**: Documented the complete JSON structure (see `JSON_STRUCTURE.md`) based on actual testing rather than relying solely on docs.

### What We Tried

1. **Used `/statusline` command**: Started with Claude Code's built-in helper to set up the status line
2. **Tested with PS1 detection**: Initially tried to replicate the shell PS1, but user wanted custom configuration
3. **Iterative customization**: Added elements based on user preferences:
   - Current working directory ✅
   - Git branch/status ✅
   - Model name ✅
   - Context usage ✅
   - Weekly usage tracking ❌ (not available via statusLine JSON)
   - Session block time remaining ❌ (not available)
4. **Created test harness**: Built a temporary logging mechanism to capture and inspect the actual JSON
5. **Isolated execution**: Moved from simple inline bash to isolated subprocess with strict error handling

## Files in This Repository

- `statusline.sh` - The standalone status line script
- `README.md` - This documentation
- `JSON_STRUCTURE.md` - Complete reference of available JSON fields
- `TROUBLESHOOTING.md` - Common issues and solutions

## Customization

The script uses these ANSI color codes:
- `\033[36m` - Cyan (directory)
- `\033[35m` - Magenta (model)
- `\033[33m` - Yellow (context usage)
- `\033[32m` - Green (input/output)
- `\033[0m` - Reset

You can modify these in `statusline.sh` to change colors.

### Available Git Status Indicators

Current:
- `✓` = clean
- `●` = dirty

You could also use:
- `✓` / `✗`
- `✔︎` / `✘`
- `🟢` / `🔴`
- `+` / `*`

## Testing

To test the script with mock data:

```bash
echo '{
  "model": {"display_name": "Test Model"},
  "workspace": {"current_dir": "/test/path"},
  "context_window": {
    "total_input_tokens": 5000,
    "total_output_tokens": 15000,
    "context_window_size": 200000
  }
}' | ./statusline.sh
```

## Dependencies

- `bash`
- `jq` - JSON processor
- `awk` - For floating point calculations
- `git` - For git status (optional)

## References

- [Claude Code Status Line Documentation](https://docs.claude.com/statusline)
- Official docs location (local): `~/.claude/plugins/cache/superpowers-marketplace/superpowers-developing-for-claude-code/*/skills/working-with-claude-code/references/statusline.md`

## License

MIT

## Contributing

Feel free to submit issues or pull requests with improvements or additional features.
