# Installation and Usage Guide

Step-by-step guide for installing and using the Claude Code custom status line.

## Prerequisites

Before installing, ensure you have:

- ✅ Claude Code installed (v2.0.69 or later recommended)
- ✅ `jq` JSON processor installed
- ✅ `bash` shell (macOS/Linux)
- ✅ `git` (optional, for git status features)

### Check Prerequisites

```bash
# Check Claude Code
claude --version

# Check jq
jq --version
# If not installed: brew install jq (macOS) or apt-get install jq (Linux)

# Check bash
bash --version

# Check git (optional)
git --version
```

## Installation Methods

### Method 1: Clone Repository (Recommended)

This method keeps your configuration in version control and makes updates easier.

```bash
# 1. Clone the repository
cd ~/dev/github/chrisvaillancourt
git clone https://github.com/chrisvaillancourt/claude-statusline.git

# 2. Make script executable (should already be set, but just in case)
chmod +x ~/dev/github/chrisvaillancourt/claude-statusline/statusline.sh

# 3. Update your Claude Code settings
# Open ~/.claude/settings.json and add:
```

```json
{
  "statusLine": {
    "type": "command",
    "command": "/Users/chris/dev/github/chrisvaillancourt/claude-statusline/statusline.sh"
  }
}
```

```bash
# 4. Restart Claude Code or start a new session
```

### Method 2: Copy Script to Standard Location

```bash
# 1. Create claude config directory if it doesn't exist
mkdir -p ~/.claude/scripts

# 2. Copy the script
cp statusline.sh ~/.claude/scripts/statusline.sh
chmod +x ~/.claude/scripts/statusline.sh

# 3. Update settings.json
```

```json
{
  "statusLine": {
    "type": "command",
    "command": "~/.claude/scripts/statusline.sh"
  }
}
```

Note: You may need to use the full path instead of `~`:
```json
{
  "statusLine": {
    "type": "command",
    "command": "/Users/YOUR_USERNAME/.claude/scripts/statusline.sh"
  }
}
```

### Method 3: Inline Command

Copy the entire command directly into your `settings.json`. This method doesn't require a separate script file but is harder to maintain.

```json
{
  "statusLine": {
    "type": "command",
    "command": "/bin/bash -c 'set -euo pipefail; readonly INPUT=$(cat); readonly CWD=$(echo \"$INPUT\" | jq -r \".workspace.current_dir\"); readonly MODEL=$(echo \"$INPUT\" | jq -r \".model.display_name\"); readonly SESSION_ID=$(echo \"$INPUT\" | jq -r \".session_id\"); readonly TOTAL_INPUT=$(echo \"$INPUT\" | jq -r \".context_window.total_input_tokens\"); readonly TOTAL_OUTPUT=$(echo \"$INPUT\" | jq -r \".context_window.total_output_tokens\"); readonly CONTEXT_SIZE=$(echo \"$INPUT\" | jq -r \".context_window.context_window_size\"); readonly TOTAL_TOKENS=$((TOTAL_INPUT + TOTAL_OUTPUT)); readonly USAGE_PCT=$(awk \"BEGIN {printf \\\"%.1f\\\", ($TOTAL_TOKENS / $CONTEXT_SIZE) * 100}\"); readonly INPUT_K=$(awk \"BEGIN {printf \\\"%.1fK\\\", $TOTAL_INPUT / 1000}\"); readonly OUTPUT_K=$(awk \"BEGIN {printf \\\"%.1fK\\\", $TOTAL_OUTPUT / 1000}\"); readonly TOTAL_K=$(awk \"BEGIN {printf \\\"%.1fK\\\", $TOTAL_TOKENS / 1000}\"); readonly CONTEXT_K=$(awk \"BEGIN {printf \\\"%.0fK\\\", $CONTEXT_SIZE / 1000}\"); GIT_INFO=\"\"; if cd \"$CWD\" 2>/dev/null && git rev-parse --git-dir > /dev/null 2>&1; then BRANCH=$(git --no-optional-locks branch --show-current 2>/dev/null); if [ -n \"$BRANCH\" ]; then if git --no-optional-locks diff-index --quiet HEAD -- 2>/dev/null; then GIT_STATUS=\"✓\"; else GIT_STATUS=\"●\"; fi; GIT_INFO=\" | git:$BRANCH$GIT_STATUS\"; fi; fi; readonly DISPLAY_CWD=\"${CWD/#$HOME/~}\"; printf \"\\033[36m%s\\033[0m%s | \\033[35m%s\\033[0m | \\033[33mctx:%s/%s (%s%%)\\033[0m | \\033[32m↑%s ↓%s\\033[0m\" \"$DISPLAY_CWD\" \"$GIT_INFO\" \"$MODEL\" \"$TOTAL_K\" \"$CONTEXT_K\" \"$USAGE_PCT\" \"$INPUT_K\" \"$OUTPUT_K\"'"
  }
}
```

## Editing settings.json Safely

### Backup First

```bash
cp ~/.claude/settings.json ~/.claude/settings.json.backup
```

### Edit with Validation

```bash
# Edit the file
nano ~/.claude/settings.json
# or
code ~/.claude/settings.json

# Validate JSON syntax
cat ~/.claude/settings.json | jq '.'

# If validation fails, restore backup:
# cp ~/.claude/settings.json.backup ~/.claude/settings.json
```

### Example Complete settings.json

Here's an example of what your `settings.json` might look like with the status line configured:

```json
{
  "cleanupPeriodDays": 365,
  "statusLine": {
    "type": "command",
    "command": "/Users/chris/dev/github/chrisvaillancourt/claude-statusline/statusline.sh"
  },
  "enabledPlugins": {
    "superpowers@superpowers-marketplace": true
  }
}
```

## Testing Installation

### Test 1: Script Runs Manually

```bash
echo '{
  "model": {"display_name": "Test Model"},
  "workspace": {"current_dir": "'$(pwd)'"},
  "context_window": {
    "total_input_tokens": 5000,
    "total_output_tokens": 15000,
    "context_window_size": 200000
  }
}' | ~/dev/github/chrisvaillancourt/claude-statusline/statusline.sh
```

Expected output (with colors):
```
~/your/current/path | Test Model | ctx:20.0K/200K (10.0%) | ↑5.0K ↓15.0K
```

### Test 2: Verify in Claude Code

1. Start a new Claude Code session
2. Look at the bottom of the interface
3. You should see the status line with:
   - Your current directory
   - Git info (if in a git repo)
   - Model name
   - Context usage
   - Input/output token counts

## Customization

### Change Colors

Edit `statusline.sh` and modify these lines:

```bash
# Current colors:
# \033[36m = Cyan (directory)
# \033[35m = Magenta (model)
# \033[33m = Yellow (context)
# \033[32m = Green (input/output)

# Color reference:
# 30=Black, 31=Red, 32=Green, 33=Yellow
# 34=Blue, 35=Magenta, 36=Cyan, 37=White

# Example: Change model to blue
# Replace \033[35m with \033[34m
```

### Change Git Status Symbols

Edit `statusline.sh`:

```bash
# Current:
GIT_STATUS="✓"  # Clean
GIT_STATUS="●"  # Dirty

# Alternatives:
# GIT_STATUS="✔︎" / "✘"
# GIT_STATUS="🟢" / "🔴"
# GIT_STATUS="+" / "*"
# GIT_STATUS="clean" / "dirty"
```

### Add Custom Information

You can add more information from the JSON. See `JSON_STRUCTURE.md` for available fields.

Example - Add total cost:

```bash
# In statusline.sh, add:
readonly TOTAL_COST=$(echo "$INPUT" | jq -r ".cost.total_cost_usd")
readonly COST_DISPLAY=$(awk "BEGIN {printf \"$%.2f\", $TOTAL_COST}")

# Then in the printf:
printf "... | \033[31m%s\033[0m" ... "$COST_DISPLAY"
```

## Uninstallation

### Remove Status Line

Edit `~/.claude/settings.json` and remove the `statusLine` section:

```json
{
  "cleanupPeriodDays": 365,
  // Remove this entire block:
  // "statusLine": {
  //   "type": "command",
  //   "command": "..."
  // }
}
```

### Remove Files

```bash
# If using Method 1 (cloned repo)
rm -rf ~/dev/github/chrisvaillancourt/claude-statusline

# If using Method 2 (standard location)
rm ~/.claude/scripts/statusline.sh
```

## Updating

### Method 1 (Git Repository)

```bash
cd ~/dev/github/chrisvaillancourt/claude-statusline
git pull origin main
```

### Method 2 or 3 (Manual)

1. Download new version of script
2. Replace old script:
   ```bash
   cp new_statusline.sh ~/.claude/scripts/statusline.sh
   ```
3. Or update inline command in `settings.json`

## Troubleshooting

If the status line isn't working, see `TROUBLESHOOTING.md` for common issues and solutions.

Quick checks:

```bash
# 1. Is script executable?
ls -l ~/dev/github/chrisvaillancourt/claude-statusline/statusline.sh

# 2. Does script run?
echo '{"model":{"display_name":"Test"},"workspace":{"current_dir":"/test"},"context_window":{"total_input_tokens":100,"total_output_tokens":200,"context_window_size":200000}}' | ~/dev/github/chrisvaillancourt/claude-statusline/statusline.sh

# 3. Is JSON valid?
cat ~/.claude/settings.json | jq '.'

# 4. Is jq installed?
which jq
```

## Support

- See `TROUBLESHOOTING.md` for common issues
- Check the repository for updates and issues
- Refer to official Claude Code docs at https://docs.claude.com/statusline

## Next Steps

After installation:

1. ✅ Review `JSON_STRUCTURE.md` to see all available data
2. ✅ Customize colors and symbols to your preference
3. ✅ Add additional information you find useful
4. ✅ Star the repository if you find it helpful!
