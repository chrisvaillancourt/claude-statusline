#!/usr/bin/env -S uv run
# /// script
# requires-python = ">=3.11"
# dependencies = []
# ///
"""
Claude Code Custom Status Line (Python version)
Displays: current directory | git status | model | ACTUAL context usage | input/output tokens

This script reads the transcript file to calculate actual full context usage including
system overhead (prompts, tools, MCP, memory files) rather than just conversation tokens.
"""

import json
import os
import subprocess
import sys
from pathlib import Path


def get_git_info(cwd: str) -> str:
    """Get git branch and status for the given directory."""
    try:
        # Change to the working directory
        result = subprocess.run(
            ["git", "rev-parse", "--git-dir"],
            cwd=cwd,
            capture_output=True,
            text=True,
            timeout=1,
        )

        if result.returncode != 0:
            return ""

        # Get current branch
        result = subprocess.run(
            ["git", "--no-optional-locks", "branch", "--show-current"],
            cwd=cwd,
            capture_output=True,
            text=True,
            timeout=1,
        )

        branch = result.stdout.strip()
        if not branch:
            return ""

        # Check if working tree is clean
        result = subprocess.run(
            ["git", "--no-optional-locks", "diff-index", "--quiet", "HEAD", "--"],
            cwd=cwd,
            capture_output=True,
            timeout=1,
        )

        status = "✓" if result.returncode == 0 else "●"
        return f" | git:{branch}{status}"

    except (subprocess.TimeoutExpired, FileNotFoundError, Exception):
        return ""


def parse_transcript_for_usage(transcript_path: str) -> tuple[int, int, int]:
    """
    Parse the JSONL transcript file to find the last assistant message's usage stats.

    Returns: (total_input_tokens, total_output_tokens, context_window_size)
    where total_input_tokens includes system overhead (prompts, tools, etc.)
    """
    try:
        # Read the file in reverse to find the last assistant message quickly
        # For large files, we'll read the last N lines instead of the whole file
        with open(transcript_path, 'r') as f:
            # Read last 100 lines (should be more than enough)
            lines = f.readlines()

        # Search backwards for the last assistant message
        for line in reversed(lines):
            try:
                entry = json.loads(line)
                if entry.get("message", {}).get("role") == "assistant":
                    usage = entry.get("message", {}).get("usage", {})

                    # Total input = uncached + cache_creation + cache_read
                    input_tokens = usage.get("input_tokens", 0)
                    cache_creation = usage.get("cache_creation_input_tokens", 0)
                    cache_read = usage.get("cache_read_input_tokens", 0)
                    total_input = input_tokens + cache_creation + cache_read

                    output_tokens = usage.get("output_tokens", 0)

                    # Context window size from the entry (typically 200000)
                    # We'll return this from here instead of stdin JSON for accuracy
                    return (total_input, output_tokens, 200000)

            except json.JSONDecodeError:
                continue

        # No assistant message found, return zeros
        return (0, 0, 200000)

    except (FileNotFoundError, IOError):
        # If we can't read the transcript, return zeros
        return (0, 0, 200000)


def format_number(num: int) -> str:
    """Format number as K (e.g., 5205 -> 5.2K)."""
    return f"{num / 1000:.1f}K"


def main():
    # Read JSON input from stdin
    try:
        input_data = json.load(sys.stdin)
    except json.JSONDecodeError:
        print("Error: Invalid JSON input", file=sys.stderr)
        sys.exit(1)

    # Extract values from input JSON
    cwd = input_data.get("workspace", {}).get("current_dir", "")
    model = input_data.get("model", {}).get("display_name", "Unknown")
    transcript_path = input_data.get("transcript_path", "")
    context_window_size = input_data.get("context_window", {}).get("context_window_size", 200000)

    # Parse transcript for actual usage (includes system overhead)
    total_input, total_output, _ = parse_transcript_for_usage(transcript_path)

    # Calculate totals
    total_tokens = total_input + total_output
    usage_pct = (total_tokens / context_window_size * 100) if context_window_size > 0 else 0

    # Format numbers
    input_k = format_number(total_input)
    output_k = format_number(total_output)
    total_k = format_number(total_tokens)
    context_k = f"{context_window_size // 1000}K"

    # Get git information
    git_info = get_git_info(cwd)

    # Format display path (replace home directory with ~)
    home = os.path.expanduser("~")
    display_cwd = cwd.replace(home, "~", 1) if cwd.startswith(home) else cwd

    # Output formatted status line with ANSI colors:
    # - Cyan (36m) for directory
    # - Magenta (35m) for model
    # - Yellow (33m) for context usage
    # - Green (32m) for input/output breakdown
    print(
        f"\033[36m{display_cwd}\033[0m{git_info} | "
        f"\033[35m{model}\033[0m | "
        f"\033[33mctx:{total_k}/{context_k} ({usage_pct:.1f}%)\033[0m | "
        f"\033[32m↑{input_k} ↓{output_k}\033[0m",
        end=""
    )


if __name__ == "__main__":
    main()
