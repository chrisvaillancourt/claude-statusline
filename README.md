# Claude Code Custom Status Line

A custom status line for Claude Code that provides **accurate context usage reporting** by parsing the session transcript to show the true context window consumption, including system overhead.

## Why This Exists

Claude Code's default status line data only reports conversation tokens. But the actual context window usage includes:

- System prompts (~3K tokens)
- Tool definitions (~19K tokens)
- MCP tools (~1.5K tokens)
- Memory files (~1.4K tokens)
- Conversation messages

This tool parses the session transcript to report the **actual full context usage** that matches what `/context` shows.

## What It Looks Like

```
~/dev/project | git:main✓ | Sonnet 4.5 | ctx:83.8K/200K (41.9%) [sys:45.4K conv:38.3K]
```

## Features

- **Accurate Context Usage** - Shows true context consumption including all system overhead
- **Context Breakdown** - Separates system overhead from conversation tokens
- **Color-Coded Warnings** - Accessible color scheme (cyan/yellow/magenta) indicates usage levels
- **Current Directory** (cyan) - Shows working directory with `~` for home
- **Git Status** - Branch name with status indicator (✓ clean, ● dirty)
- **Model Name** (magenta) - Current Claude model

## Installation

### Prerequisites

- Python 3.11+
- [uv](https://docs.astral.sh/uv/) (for running the Python script)

### Setup

Add to your `~/.claude/settings.json`:

```json
{
  "statusLine": {
    "type": "command",
    "command": "/path/to/claude-statusline/statusline.py"
  }
}
```

## How It Works

1. Claude Code passes session info (including `transcript_path`) to the statusline script
2. The script reads the JSONL transcript file
3. It finds the last assistant message with API usage data
4. The usage data includes `input_tokens + cache_creation_input_tokens + cache_read_input_tokens`
5. This total represents the **full context** sent to the API, including all system overhead

### Data Sources

| Source | What It Contains | Accuracy |
|--------|------------------|----------|
| stdin JSON `context_window.*` | Conversation tokens only | Partial |
| Transcript `usage.*` | Full API context including system overhead | **Accurate** |

## Output Format

```
~/path | git:branch● | Model | ctx:83.8K/200K (41.9%) [sys:45.4K conv:38.3K]
```

| Component | Description |
|-----------|-------------|
| `ctx:83.8K/200K` | Total context / context window limit |
| `(41.9%)` | Percentage of context used |
| `[sys:45.4K` | System overhead (prompts, tools, MCP, memory) |
| `conv:38.3K]` | Conversation tokens (your messages + AI responses) |

### Color Coding (Accessible)

- **Cyan** - Healthy usage (<60%)
- **Yellow** - Warning (60-80%)
- **Magenta** - Danger zone (≥80%)

The color scheme avoids red/green to be accessible for color vision deficiency.

## Files

| File | Purpose |
|------|---------|
| `statusline.py` | Main Python script (uses uv) |
| `statusline.sh` | Legacy bash script (conversation tokens only) |
| `AGENTS.md` | Instructions for AI coding assistants |
| `JSON_STRUCTURE.md` | Complete reference of available JSON fields |
| `PERFORMANCE.md` | Alternative approaches for file reading |
| `TROUBLESHOOTING.md` | Common issues and solutions |

## Testing

```bash
# Test with the current session transcript
echo '{
  "model": {"display_name": "Test Model"},
  "workspace": {"current_dir": "/test/path"},
  "transcript_path": "/path/to/session.jsonl",
  "context_window": {
    "total_input_tokens": 5000,
    "total_output_tokens": 15000,
    "context_window_size": 200000
  }
}' | ./statusline.py
```

## Dependencies

- Python 3.11+ (via uv)
- git (optional, for git status)

No external Python packages required - uses only standard library.

## Design Principles

1. **Accuracy over performance** - Reads entire transcript to guarantee correct context reporting
2. **Graceful degradation** - Falls back to stdin JSON if transcript unavailable
3. **Accessibility** - Color scheme works for color vision deficiency
4. **Simplicity** - No external dependencies, single file

See `PERFORMANCE.md` for alternative approaches if performance becomes a concern.

## License

MIT

## Contributing

Issues and pull requests welcome. When contributing, ensure changes maintain accuracy of context reporting - that's the primary goal of this project.
