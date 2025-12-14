# Agent Instructions

This file provides guidance to coding assistants when working with code in this repository.

## Project Goal

**Accurate context usage reporting.** This tool exists to show the true context window consumption in Claude Code, including all system overhead that the default statusline data doesn't include.

The primary design principle is **accuracy over performance**. Any change that might compromise accuracy of the context reporting should be carefully considered.

## What This Project Does

This is a custom status line for Claude Code that parses the session transcript to report accurate context usage. Unlike the default stdin JSON data (which only reports conversation tokens), this tool reads the API usage data from the transcript to include:

- System prompts
- Tool definitions
- MCP tools
- Memory files
- Conversation messages

Example output:
```
~/dev/project | git:main✓ | Sonnet 4.5 | ctx:83.8K/200K (41.9%) [sys:45.4K conv:38.3K]
```

## Key Architecture

### Python Script with uv

The main implementation is `statusline.py`, a Python script that uses uv for execution:

```python
#!/usr/bin/env -S uv run
# /// script
# requires-python = ">=3.11"
# dependencies = []
# ///
```

### Two Data Sources

| Source | What It Provides | Used For |
|--------|------------------|----------|
| stdin JSON | Session info, conversation tokens, transcript path | Model name, directory, fallback tokens |
| Transcript JSONL | API usage data per message | **Accurate context totals** |

### Transcript Parsing

The script reads the entire transcript file to find the last assistant message with usage data:

```python
with open(transcript_path, "r") as f:
    lines = f.readlines()

for line in reversed(lines):
    entry = json.loads(line)
    if entry.get("message", {}).get("role") == "assistant":
        usage = entry["message"]["usage"]
        # Total context = input_tokens + cache_creation + cache_read
```

**Important:** The script reads the entire file to guarantee accuracy. See `PERFORMANCE.md` for alternative approaches if performance becomes a concern.

### Context Calculation

Total context = `input_tokens` + `cache_creation_input_tokens` + `cache_read_input_tokens`

This represents everything sent to the API, including:
- Uncached new tokens
- Tokens written to cache
- Tokens read from cache

## Testing

```bash
# Test with real transcript
echo '{
  "model": {"display_name": "Test Model"},
  "workspace": {"current_dir": "/test/path"},
  "transcript_path": "'$HOME'/.claude/projects/.../session.jsonl",
  "context_window": {
    "total_input_tokens": 5000,
    "total_output_tokens": 15000,
    "context_window_size": 200000
  }
}' | ./statusline.py

# Test fallback (no transcript)
echo '{
  "model": {"display_name": "Test Model"},
  "workspace": {"current_dir": "/test/path"},
  "transcript_path": "",
  "context_window": {
    "total_input_tokens": 5000,
    "total_output_tokens": 15000,
    "context_window_size": 200000
  }
}' | ./statusline.py
```

## Important Files

| File | Purpose |
|------|---------|
| `statusline.py` | Main Python script - **the primary implementation** |
| `statusline.sh` | Legacy bash script (conversation tokens only, kept for reference) |
| `JSON_STRUCTURE.md` | Complete reference of JSON fields from stdin |
| `PERFORMANCE.md` | Alternative file reading approaches with tradeoffs |
| `TROUBLESHOOTING.md` | Common issues and debugging |

## Design Decisions

### Why Read Entire File?

Accuracy. Reading only the tail of the file could miss the last assistant message if:
- The message itself is very large
- Many tool calls appear after the last assistant message

Since accuracy is the primary goal, we read the entire file. See `PERFORMANCE.md` for alternatives.

### Why Python Instead of Bash?

- Better JSON parsing
- Cleaner file handling
- Easier to maintain and extend
- uv provides dependency management without external packages

### Why Accessible Colors?

The color scheme uses cyan/yellow/magenta instead of green/yellow/red to be accessible for people with red-green color blindness (the most common type).

## Dependencies

- Python 3.11+ (via uv)
- git (optional, for git status)

No external Python packages - uses only standard library.

## Known Limitations

1. **Context breakdown is approximate** - The "sys" vs "conv" split is calculated as `total_context - conversation_tokens`. Since conversation_tokens is cumulative and total_context is a snapshot, this is an approximation.

2. **Update frequency** - Status line updates at most every 300ms. Don't expect real-time updates.

3. **Transcript dependency** - Requires Claude Code to write transcript files. If transcript is unavailable, falls back to less-accurate stdin JSON data.

## Issue Tracking

This project uses [beads](https://github.com/steveyegge/beads) (`bd` command). Run `bd onboard` on first session.
**Session end:** Always run `bd sync && git push` before claiming done.
