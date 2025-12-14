#!/usr/bin/env -S uv run
# /// script
# requires-python = ">=3.11"
# dependencies = []
# ///
"""
Claude Code Custom Status Line (Python version)

Displays comprehensive context usage information:
- Total context (from transcript): actual tokens sent to API including system overhead
- Context breakdown: system overhead vs conversation tokens
- Git status and model info

This script parses the transcript JSONL file to get accurate context usage,
falling back to stdin JSON values if transcript parsing fails.
"""

import json
import os
import subprocess
import sys


# How many bytes to read from the end of the transcript file
# 50KB should be plenty to find the last assistant message
TAIL_BYTES = 50 * 1024


def get_git_info(cwd: str) -> str:
    """Get git branch and status for the given directory."""
    if not cwd:
        return ""

    try:
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

        status = "\u2713" if result.returncode == 0 else "\u25cf"
        return f" | git:{branch}{status}"

    except (subprocess.TimeoutExpired, FileNotFoundError, OSError):
        return ""


def parse_transcript_for_usage(transcript_path: str) -> dict | None:
    """
    Parse the JSONL transcript file to find the last assistant message's usage stats.

    Efficiently reads only the tail of the file to avoid loading large transcripts
    entirely into memory.

    Returns dict with usage info, or None if parsing fails.
    """
    if not transcript_path:
        return None

    try:
        file_size = os.path.getsize(transcript_path)

        with open(transcript_path, "r") as f:
            # Only read the last TAIL_BYTES of the file
            if file_size > TAIL_BYTES:
                f.seek(file_size - TAIL_BYTES)
                # Skip partial first line after seeking
                f.readline()

            lines = f.readlines()

        # Search backwards for the last assistant message with usage data
        for line in reversed(lines):
            line = line.strip()
            if not line:
                continue

            try:
                entry = json.loads(line)
                message = entry.get("message", {})

                if message.get("role") == "assistant" and "usage" in message:
                    usage = message["usage"]

                    # Total input = uncached + cache_creation + cache_read
                    # This represents the FULL context sent to the API
                    input_tokens = usage.get("input_tokens", 0)
                    cache_creation = usage.get("cache_creation_input_tokens", 0)
                    cache_read = usage.get("cache_read_input_tokens", 0)

                    return {
                        "total_context": input_tokens + cache_creation + cache_read,
                        "output_tokens": usage.get("output_tokens", 0),
                        "input_tokens": input_tokens,
                        "cache_creation": cache_creation,
                        "cache_read": cache_read,
                    }

            except json.JSONDecodeError:
                continue

        return None

    except (FileNotFoundError, IOError, OSError):
        return None


def format_tokens(num: int) -> str:
    """Format token count for display (e.g., 5205 -> 5.2K, 150 -> 150)."""
    if num >= 1000:
        return f"{num / 1000:.1f}K"
    return str(num)


def main():
    # Read JSON input from stdin
    try:
        input_data = json.load(sys.stdin)
    except json.JSONDecodeError:
        print("Error: Invalid JSON input", file=sys.stderr)
        sys.exit(1)

    # Extract values from stdin JSON
    cwd = input_data.get("workspace", {}).get("current_dir", "")
    model = input_data.get("model", {}).get("display_name", "Unknown")
    transcript_path = input_data.get("transcript_path", "")
    context_window_size = input_data.get("context_window", {}).get(
        "context_window_size", 200000
    )

    # Conversation tokens from stdin JSON (cumulative session totals)
    stdin_input = input_data.get("context_window", {}).get("total_input_tokens", 0)
    stdin_output = input_data.get("context_window", {}).get("total_output_tokens", 0)
    conversation_tokens = stdin_input + stdin_output

    # Parse transcript for actual full context usage
    transcript_usage = parse_transcript_for_usage(transcript_path)

    if transcript_usage:
        # We have accurate data from transcript
        total_context = transcript_usage["total_context"]

        # System overhead = total context - conversation tokens
        # This is approximate since conversation_tokens is cumulative
        # but gives a useful sense of overhead
        system_overhead = max(0, total_context - conversation_tokens)
    else:
        # Fallback to stdin JSON (less accurate, conversation only)
        total_context = conversation_tokens
        system_overhead = 0

    # Calculate usage percentage
    usage_pct = (total_context / context_window_size * 100) if context_window_size > 0 else 0

    # Format numbers for display
    total_k = format_tokens(total_context)
    context_limit_k = f"{context_window_size // 1000}K"
    conv_k = format_tokens(conversation_tokens)

    # Get git information
    git_info = get_git_info(cwd)

    # Format display path (replace home directory with ~)
    home = os.path.expanduser("~")
    display_cwd = cwd.replace(home, "~", 1) if cwd.startswith(home) else cwd

    # Build the status line
    # Colors:
    # - Cyan (36m) for directory
    # - Magenta (35m) for model
    # - Yellow (33m) for context usage
    # - Green (32m) for conversation tokens
    # - Red (31m) for high usage warning

    # Color code the percentage based on usage level
    if usage_pct >= 80:
        pct_color = "31"  # Red - danger zone
    elif usage_pct >= 60:
        pct_color = "33"  # Yellow - warning
    else:
        pct_color = "32"  # Green - healthy

    # Build context display
    if transcript_usage and system_overhead > 0:
        # Show breakdown: total context with system/conversation split
        sys_k = format_tokens(system_overhead)
        context_display = (
            f"\033[{pct_color}mctx:{total_k}/{context_limit_k} ({usage_pct:.1f}%)\033[0m"
            f" \033[90m[sys:{sys_k} conv:{conv_k}]\033[0m"
        )
    else:
        # No transcript data or no system overhead - simpler display
        context_display = (
            f"\033[{pct_color}mctx:{total_k}/{context_limit_k} ({usage_pct:.1f}%)\033[0m"
        )

    # Output formatted status line
    print(
        f"\033[36m{display_cwd}\033[0m{git_info} | "
        f"\033[35m{model}\033[0m | "
        f"{context_display}",
        end="",
    )


if __name__ == "__main__":
    main()
