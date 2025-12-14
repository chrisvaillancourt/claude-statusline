# Status Line JSON Input Structure

This document describes the complete JSON structure that Claude Code passes to your status line script via stdin.

## Complete JSON Example

Based on actual testing with Claude Code v2.0.69:

```json
{
  "session_id": "16c1d084-b4b9-4c4d-9d76-3b3977d4a09f",
  "transcript_path": "/Users/chris/.claude/projects/-Users-chris-dev-github-chrisvaillancourt/16c1d084-b4b9-4c4d-9d76-3b3977d4a09f.jsonl",
  "cwd": "/Users/chris/dev/github/chrisvaillancourt",
  "model": {
    "id": "claude-sonnet-4-5-20250929",
    "display_name": "Sonnet 4.5"
  },
  "workspace": {
    "current_dir": "/Users/chris/dev/github/chrisvaillancourt",
    "project_dir": "/Users/chris/dev/github/chrisvaillancourt"
  },
  "version": "2.0.69",
  "output_style": {
    "name": "default"
  },
  "cost": {
    "total_cost_usd": 0.86398355,
    "total_duration_ms": 1164827,
    "total_api_duration_ms": 353129,
    "total_lines_added": 8,
    "total_lines_removed": 4
  },
  "context_window": {
    "total_input_tokens": 5205,
    "total_output_tokens": 17325,
    "context_window_size": 200000
  },
  "exceeds_200k_tokens": false
}
```

## Field Reference

### Session Information

| Field | Type | Description | Example |
|-------|------|-------------|---------|
| `session_id` | string | Unique identifier for the current Claude Code session | `"16c1d084-b4b9-4c4d-9d76-3b3977d4a09f"` |
| `transcript_path` | string | Absolute path to the session transcript JSONL file | `"/Users/chris/.claude/projects/..."` |
| `version` | string | Claude Code version number | `"2.0.69"` |

### Workspace Information

| Field | Type | Description | Example |
|-------|------|-------------|---------|
| `workspace.current_dir` | string | Current working directory | `"/Users/chris/dev/project"` |
| `workspace.project_dir` | string | Original project directory when session started | `"/Users/chris/dev/project"` |
| `cwd` | string | **DEPRECATED** - Use `workspace.current_dir` instead | `"/Users/chris/dev/project"` |

### Model Information

| Field | Type | Description | Example |
|-------|------|-------------|---------|
| `model.id` | string | Full model identifier | `"claude-sonnet-4-5-20250929"` |
| `model.display_name` | string | Human-readable model name | `"Sonnet 4.5"` |

### Context Window Information ⚠️ UNDOCUMENTED

These fields are **not in the official documentation** but are available and working as of Claude Code v2.0.69:

| Field | Type | Description | Example |
|-------|------|-------------|---------|
| `context_window.total_input_tokens` | number | Total input tokens used in this session | `5205` |
| `context_window.total_output_tokens` | number | Total output tokens used in this session | `17325` |
| `context_window.context_window_size` | number | Maximum context window size for the current model | `200000` |
| `exceeds_200k_tokens` | boolean | Whether the session has exceeded 200K tokens | `false` |

### Cost and Usage Information

| Field | Type | Description | Example |
|-------|------|-------------|---------|
| `cost.total_cost_usd` | number | Total cost of API calls in USD | `0.86398355` |
| `cost.total_duration_ms` | number | Total session duration in milliseconds | `1164827` |
| `cost.total_api_duration_ms` | number | Total time spent in API calls in milliseconds | `353129` |
| `cost.total_lines_added` | number | Total lines of code added in this session | `8` |
| `cost.total_lines_removed` | number | Total lines of code removed in this session | `4` |

### Output Style Information

| Field | Type | Description | Example |
|-------|------|-------------|---------|
| `output_style.name` | string | Current output formatting style | `"default"` |

## Accessing Fields in Bash

### Using jq

```bash
# Read input once
readonly INPUT=$(cat)

# Extract individual fields
MODEL=$(echo "$INPUT" | jq -r '.model.display_name')
CURRENT_DIR=$(echo "$INPUT" | jq -r '.workspace.current_dir')
INPUT_TOKENS=$(echo "$INPUT" | jq -r '.context_window.total_input_tokens')
OUTPUT_TOKENS=$(echo "$INPUT" | jq -r '.context_window.total_output_tokens')
TOTAL_COST=$(echo "$INPUT" | jq -r '.cost.total_cost_usd')
```

### Calculating Derived Values

```bash
# Calculate total tokens
TOTAL_TOKENS=$((INPUT_TOKENS + OUTPUT_TOKENS))

# Calculate usage percentage
CONTEXT_SIZE=$(echo "$INPUT" | jq -r '.context_window.context_window_size')
USAGE_PCT=$(awk "BEGIN {printf \"%.1f\", ($TOTAL_TOKENS / $CONTEXT_SIZE) * 100}")

# Format numbers for display (e.g., 5205 -> 5.2K)
INPUT_K=$(awk "BEGIN {printf \"%.1fK\", $INPUT_TOKENS / 1000}")
```

## Fields NOT Available

These fields were requested but are **not available** through the statusLine JSON:

- ❌ Weekly usage across all models
- ❌ Claude plan usage allowance (remaining quota)
- ❌ Time remaining in current billing cycle
- ❌ Session block time limits

These would need to be tracked separately or accessed through Claude's API/dashboard.

## Testing Your Access

To see what JSON your statusLine receives, temporarily modify your command:

```json
{
  "statusLine": {
    "type": "command",
    "command": "/bin/bash -c 'INPUT=$(cat); echo \"$INPUT\" > /tmp/statusline_debug.json; echo \"$INPUT\" | jq -r \".model.display_name\"'"
  }
}
```

Then check `/tmp/statusline_debug.json` after the status line updates.

## Version History

| Claude Code Version | Changes |
|---------------------|---------|
| 2.0.69 | Confirmed all fields listed above are available |
| Earlier | `context_window` fields may not have been available |

## Documentation Discrepancies

The official Claude Code documentation (as of 2025-12-13) shows this JSON structure:

```json
{
  "hook_event_name": "Status",
  "session_id": "abc123...",
  "transcript_path": "/path/to/transcript.json",
  "cwd": "/current/working/directory",
  "model": { ... },
  "workspace": { ... },
  "version": "1.0.80",
  "output_style": { ... },
  "cost": { ... }
}
```

**Missing from docs:**
- ❌ `context_window` object (entire object is undocumented)
- ❌ `exceeds_200k_tokens` field
- ❌ `hook_event_name` field appears in docs but was NOT present in our testing

**Conclusion**: The actual JSON structure differs from the documented structure. Always test to confirm available fields for your version of Claude Code.
