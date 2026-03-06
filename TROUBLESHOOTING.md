# Troubleshooting Guide

Common issues and solutions when working with Claude Code status lines.

## Table of Contents

- [Status Line Issues](#status-line-issues)
- [Cross-Session Issues](#cross-session-issues)
- [Data Issues](#data-issues)
- [Display Issues](#display-issues)
- [Debugging](#debugging)

---

## Status Line Issues

### Status Line Not Appearing

**Symptoms**: No status line appears at the bottom of Claude Code interface.

**Possible Causes & Solutions**:

1. **Script not executable**
   ```bash
   chmod +x /path/to/statusline.sh
   ```

2. **Script has errors**
   - Check that the script runs without errors:
   ```bash
   echo '{"model":{"display_name":"Test"},"workspace":{"current_dir":"/test"},"context_window":{"total_input_tokens":100,"total_output_tokens":200,"context_window_size":200000}}' | ./statusline.sh
   ```

3. **Output going to stderr instead of stdout**
   - Ensure all output goes to stdout
   - Redirect errors if needed: `2>/dev/null`

4. **Settings not reloaded**
   - Restart Claude Code after changing `settings.json`

### Status Line Shows Error Messages

**Symptoms**: Status line displays error text instead of formatted output.

**Solutions**:

1. **Check jq is installed**
   ```bash
   which jq
   # If not found, install it:
   brew install jq  # macOS
   ```

2. **Verify JSON parsing**
   - Add error handling to your script:
   ```bash
   if ! echo "$INPUT" | jq -e . >/dev/null 2>&1; then
       echo "JSON parse error"
       exit 1
   fi
   ```

---

## Cross-Session Issues

### Wrong Model Showing in Status Line

**Symptoms**: Status line shows "Opus 4.5" when session is using "Sonnet 4.5" (or vice versa).

**Root Cause**: Variable contamination between multiple Claude Code sessions running simultaneously.

**Solution**: Use isolated bash subprocesses with readonly variables.

**Bad** (vulnerable to cross-contamination):
```bash
{
  "statusLine": {
    "type": "command",
    "command": "input=$(cat); model=$(echo \"$input\" | jq -r '.model.display_name'); echo \"$model\""
  }
}
```

**Good** (isolated and protected):
```bash
{
  "statusLine": {
    "type": "command",
    "command": "/bin/bash -c 'set -euo pipefail; readonly INPUT=$(cat); readonly MODEL=$(echo \"$INPUT\" | jq -r \".model.display_name\"); echo \"$MODEL\"'"
  }
}
```

**Key protections**:
- Explicit `/bin/bash -c` invocation (isolated subprocess)
- `set -euo pipefail` (strict error handling)
- `readonly` variables (prevents overwrites)
- Uppercase variable names (reduces conflicts)
- Single INPUT capture, parsed multiple times

### Sessions Interfering With Each Other

**Symptoms**: Status lines from different sessions show mixed data.

**Solution**: Ensure each session has isolated execution:

1. Use the pattern from "Wrong Model Showing" above
2. Avoid shared state (files, environment variables)
3. Don't use global caches that could be read by multiple sessions

---

## Data Issues

### Context Window Shows "null" or Wrong Values

**Symptoms**: Context usage shows `null/null` or incorrect numbers.

**Possible Causes**:

1. **Field doesn't exist in your Claude Code version**
   - The `context_window` fields were added in recent versions
   - Check your version: `claude --version`
   - Update Claude Code if needed

2. **Typo in field name**
   ```bash
   # Wrong
   echo "$INPUT" | jq -r '.context_window.input_tokens'  # Missing "total_"

   # Correct
   echo "$INPUT" | jq -r '.context_window.total_input_tokens'
   ```

3. **Field returns "null" in jq**
   - Use jq's `-e` flag to check if field exists:
   ```bash
   if echo "$INPUT" | jq -e '.context_window.total_input_tokens' >/dev/null 2>&1; then
       # Field exists
   else
       # Field doesn't exist, use fallback
   fi
   ```

### Statusline Shows Much Lower Context Than `/context` Command

**Symptoms**: Running `/context` at the start of a new session shows ~71k tokens, but statusline shows only ~3k tokens.

**Root Cause**: Different measurement points and data sources.

**What's happening**:

1. **Before first assistant response**:
   - `/context` shows ~71k: full context allocation including system overhead and autocompact buffer
   - Statusline shows ~3k: fallback to conversation tokens only (from stdin JSON)
   - **Why**: No assistant response in transcript yet, so statusline can't access accurate API usage data

2. **After first assistant response**:
   - `/context` shows ~71k: still includes 45k autocompact buffer (reserved space)
   - Statusline shows ~35k: actual API usage (27k system + 8k conversation)
   - **Why**: Statusline reads real API usage from transcript, excluding unused buffer space

**Key differences**:

| Tool | Source | Includes Buffer | Updates |
|------|--------|----------------|---------|
| `/context` | Claude Code internals | Yes (45k autocompact) | Always |
| Statusline | Transcript API usage | No (actual usage only) | After assistant response |

**This is expected behavior**:
- Statusline prioritizes **accuracy** - shows actual tokens sent to API
- `/context` shows **allocation** - includes reserved buffer space
- Before first response, statusline falls back to less accurate stdin JSON data

**Example**:
```
# Start of session, before assistant responds:
/context → 71k tokens (system + buffer + conversation)
statusline → ctx:3.0K/200K  (conversation only, fallback mode)

# After assistant responds:
/context → 71k tokens (still includes 45k buffer)
statusline → ctx:34.7K/200K [sys:27.1K conv:7.6K]  (actual API usage)
```

**Solution**: This is working as designed. Wait for the first assistant response to see accurate statusline data.

### Git Information Not Showing

**Symptoms**: Git branch and status don't appear even in a git repository.

**Solutions**:

1. **Check you're in a git repo**
   ```bash
   git rev-parse --git-dir
   ```

2. **Verify git commands work**
   ```bash
   git --no-optional-locks branch --show-current
   ```

3. **Check directory change succeeds**
   ```bash
   if cd "$CWD" 2>/dev/null && git rev-parse --git-dir > /dev/null 2>&1; then
       # Git commands here
   fi
   ```

---

## Display Issues

### Colors Not Showing

**Symptoms**: Status line appears without colors, shows raw ANSI codes.

**Possible Causes**:

1. **Terminal doesn't support colors**
   - Check `TERM` environment variable:
   ```bash
   echo $TERM  # Should be something like "xterm-256color"
   ```

2. **ANSI codes being escaped**
   - Use `printf` instead of `echo -e`:
   ```bash
   # Good
   printf "\033[36m%s\033[0m" "text"

   # May not work in all shells
   echo -e "\033[36mtext\033[0m"
   ```

### Status Line Truncated

**Symptoms**: Status line cuts off partway through.

**Solutions**:

1. **Reduce information shown**
   - Remove less critical fields
   - Shorten directory path display

2. **Use abbreviations**
   ```bash
   # Instead of "context:"
   "ctx:"

   # Instead of full path
   basename "$CWD"
   ```

### Special Characters Not Displaying

**Symptoms**: Symbols like `✓`, `●`, `↑`, `↓` show as boxes or question marks.

**Solutions**:

1. **Check terminal font**
   - Use a font that supports Unicode (e.g., Menlo, Source Code Pro)

2. **Use ASCII alternatives**
   ```bash
   # Unicode
   GIT_STATUS="✓"  # Clean
   GIT_STATUS="●"  # Dirty

   # ASCII alternatives
   GIT_STATUS="+"  # Clean
   GIT_STATUS="*"  # Dirty
   ```

---

## Debugging

### Capture and Inspect JSON Input

Create a debug version that logs the JSON:

```json
{
  "statusLine": {
    "type": "command",
    "command": "/bin/bash -c 'INPUT=$(cat); echo \"$INPUT\" > /tmp/statusline_debug.json; echo \"Debug mode - check /tmp/statusline_debug.json\"'"
  }
}
```

Then inspect:
```bash
cat /tmp/statusline_debug.json | jq '.'
```

### Test Script Manually

Run your script with mock data:

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

### Add Logging

Add debug output to your script (to stderr so it doesn't affect status line):

```bash
echo "DEBUG: INPUT=$INPUT" >&2
echo "DEBUG: MODEL=$MODEL" >&2
```

Then check Claude Code logs or terminal output for debug messages.

### Incremental Testing

Test each component separately:

```bash
# Test 1: Can we read input?
echo '{"test":"value"}' | bash -c 'INPUT=$(cat); echo "$INPUT"'

# Test 2: Can we parse JSON?
echo '{"model":{"display_name":"Test"}}' | bash -c 'INPUT=$(cat); echo "$INPUT" | jq -r ".model.display_name"'

# Test 3: Can we do calculations?
bash -c 'readonly A=100; readonly B=200; echo $((A + B))'

# Test 4: Can we format output?
printf "\033[36m%s\033[0m\n" "Colored text"
```

### Check File Permissions

```bash
ls -la /path/to/statusline.sh
# Should show: -rwxr-xr-x (executable)

# If not:
chmod +x /path/to/statusline.sh
```

### Validate settings.json

```bash
cat ~/.claude/settings.json | jq '.'
# Should parse without errors

# If errors, validate JSON:
cat ~/.claude/settings.json | jq . > /tmp/fixed.json
mv /tmp/fixed.json ~/.claude/settings.json
```

---

## Getting Help

1. **Check Claude Code version**
   ```bash
   claude --version
   ```

2. **Review official documentation**
   - Local: `~/.claude/plugins/cache/superpowers-marketplace/superpowers-developing-for-claude-code/*/skills/working-with-claude-code/references/statusline.md`
   - Online: https://docs.claude.com/statusline

3. **Test with minimal configuration**
   - Start with the simplest possible status line:
   ```json
   {
     "statusLine": {
       "type": "command",
       "command": "/bin/bash -c 'INPUT=$(cat); echo \"$INPUT\" | jq -r \".model.display_name\"'"
     }
   }
   ```
   - Add complexity incrementally

4. **Check for known issues**
   - Review this repository's issues
   - Check Claude Code GitHub issues

---

## Quick Reference: Common Fixes

| Problem | Quick Fix |
|---------|-----------|
| No status line | `chmod +x statusline.sh` |
| Wrong model displayed | Use isolated bash subprocess with readonly vars |
| No colors | Use `printf` with ANSI codes |
| Null values | Check field exists with `jq -e` |
| Git info missing | Verify `cd "$CWD"` succeeds |
| JSON errors | Validate with `jq '.'` |
| Special chars broken | Change terminal font or use ASCII |
| Line truncated | Reduce displayed information |
