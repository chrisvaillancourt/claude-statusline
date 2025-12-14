# Agent instructions


This file provides guidance to coding assistants when working with code in this repository.

## What This Project Does

This is a custom status line configuration for Claude Code that displays contextual session information including current directory, git status, model name, and context window usage. The status line is implemented as a bash script that receives JSON input from Claude Code via stdin and outputs a formatted status line with ANSI colors.

Example output:
```
~/dev/project | git:main✓ | Claude Sonnet 4.5 | ctx:22.5K/200K (11.3%) | ↑5.2K ↓17.3K
```

## Testing the Status Line Script

To test the status line script with mock data:

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

To debug and capture the actual JSON being passed by Claude Code, you can temporarily modify the settings to log the input (see TROUBLESHOOTING.md for details).

## Key Architecture Decisions

### Bash Script Isolation for Multi-Session Safety

The status line script uses strict isolation patterns to prevent cross-session variable contamination when multiple Claude Code sessions run simultaneously:

1. **Explicit bash subprocess**: `/bin/bash -c` creates isolated execution environment
2. **Strict error handling**: `set -euo pipefail` catches errors immediately
3. **Readonly variables**: All variables declared `readonly` to prevent overwrites
4. **Single input capture**: JSON input captured once as `readonly INPUT` and parsed multiple times
5. **Uppercase variable names**: Reduces likelihood of conflicts with shell internals

This pattern prevents issues like Session A (using Sonnet) showing "Opus 4.5" in the status line when Session B (using Opus) is running simultaneously.

### JSON Input Structure

Claude Code passes session information to the status line script via stdin as JSON. The structure includes:

**Documented fields:**
- `session_id`: Unique session identifier
- `workspace.current_dir`: Current working directory
- `model.display_name`: Human-readable model name (e.g., "Sonnet 4.5")
- `model.id`: Full model identifier (e.g., "claude-sonnet-4-5-20250929")
- `cost.*`: Session cost and usage metrics
- `version`: Claude Code version

**Undocumented but available fields:**
- `context_window.total_input_tokens`: Input tokens used this session
- `context_window.total_output_tokens`: Output tokens used this session
- `context_window.context_window_size`: Maximum context window (typically 200000)
- `exceeds_200k_tokens`: Boolean flag for exceeding 200K tokens

See JSON_STRUCTURE.md for the complete reference based on actual testing with Claude Code v2.0.69.

### ANSI Color Codes

The script uses these ANSI escape sequences:
- `\033[36m` - Cyan (directory path)
- `\033[35m` - Magenta (model name)
- `\033[33m` - Yellow (context usage)
- `\033[32m` - Green (input/output tokens)
- `\033[0m` - Reset

Colors are applied via `printf` for maximum portability across shells.

### Git Status Detection

Git information is gathered by:
1. Changing to the workspace directory (`cd "$CWD"`)
2. Checking if it's a git repository (`git rev-parse --git-dir`)
3. Getting current branch (`git --no-optional-locks branch --show-current`)
4. Checking working tree status (`git --no-optional-locks diff-index --quiet HEAD`)

The `--no-optional-locks` flag prevents git from updating index files, which is important for status line performance.

## Important Files

- `statusline.sh` - Main status line script (executable)
- `debug-statusline.sh` - Debug version that logs JSON input to file
- `JSON_STRUCTURE.md` - Complete documented JSON structure from actual testing
- `TROUBLESHOOTING.md` - Common issues and debugging techniques
- `INSTALL.md` - Installation instructions for different setup methods

## Dependencies

Required:
- `bash` - Shell interpreter
- `jq` - JSON processor for parsing Claude Code's JSON input
- `awk` - Floating point calculations (percentage, K-formatted numbers)

Optional:
- `git` - For git status display (gracefully skipped if not in a git repo)

## Known Issues and Gotchas

1. **Cross-session contamination**: Earlier versions using simple inline bash commands had issues with variable sharing between sessions. Fixed by using isolated subprocess pattern (see "Bash Script Isolation" above).

2. **Undocumented fields**: The `context_window` object is not in the official Claude Code documentation but works reliably as of v2.0.69. Future versions may change this.

3. **Status line update frequency**: Updates at most every 300ms when conversation messages update. Don't rely on real-time updates.

4. **Field name discrepancy**: Official docs reference `cwd` field, but `workspace.current_dir` is the recommended field to use (both work, but workspace.current_dir is more consistent).

## Development History Context

This project was created through iterative development where we:
1. Started with Claude Code's `/statusline` command
2. Customized based on user preferences (directory, git, model, context usage)
3. Discovered undocumented `context_window` fields through testing
4. Debugged cross-session contamination issues
5. Documented the actual JSON structure vs official docs

See README.md "Development Journey" section for detailed chronology.
