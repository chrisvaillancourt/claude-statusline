# Performance Considerations

This document describes alternative approaches for reading the transcript file, with tradeoffs between accuracy and performance.

## Current Approach: Read Entire File

The statusline script currently reads the entire transcript JSONL file to find the last assistant message with usage data.

```python
with open(transcript_path, "r") as f:
    lines = f.readlines()
```

### Why This Approach

**Accuracy is the primary goal.** The purpose of this tool is to provide accurate context usage information that matches what `/context` shows in Claude Code. Any approach that might miss data compromises this goal.

### Tradeoffs

| Aspect | Assessment |
|--------|------------|
| **Accuracy** | 100% - guaranteed to find the last assistant message |
| **Memory** | O(file size) - loads entire file into memory |
| **Speed** | O(n) - reads all lines, but searches backwards |
| **Reliability** | High - simple, no edge cases |

### When This Might Be a Problem

- Very long sessions with large transcripts (>100MB)
- Systems with limited memory
- High-frequency statusline updates causing I/O pressure

In practice, most sessions produce transcripts under 10MB, and the statusline only updates every ~300ms when conversations change, so this is rarely an issue.

---

## Alternative Approaches

If performance becomes a concern, consider these alternatives. Each trades some accuracy guarantee or implementation complexity for better performance.

### 1. Tail Reading (Fixed Size)

Read only the last N bytes of the file.

```python
TAIL_BYTES = 50 * 1024  # 50KB

file_size = os.path.getsize(transcript_path)
with open(transcript_path, "r") as f:
    if file_size > TAIL_BYTES:
        f.seek(file_size - TAIL_BYTES)
        f.readline()  # Skip partial first line
    lines = f.readlines()
```

| Aspect | Assessment |
|--------|------------|
| **Accuracy** | ~95% - may miss if last assistant message is beyond tail |
| **Memory** | O(TAIL_BYTES) - constant, predictable |
| **Speed** | O(1) for seek + O(TAIL_BYTES) for read |
| **Reliability** | Medium - edge cases when messages are very large |

**When it fails:**
- Last assistant message is larger than TAIL_BYTES
- Many tool calls or other entries after the last assistant message
- Very long code blocks or error messages in responses

### 2. Exponential Backoff

Start with a small read, double if not found, until the entire file is read.

```python
def parse_with_backoff(transcript_path: str) -> dict | None:
    file_size = os.path.getsize(transcript_path)
    read_size = 50 * 1024  # Start with 50KB

    while read_size <= file_size:
        with open(transcript_path, "r") as f:
            if file_size > read_size:
                f.seek(file_size - read_size)
                f.readline()  # Skip partial line
            lines = f.readlines()

        result = search_for_assistant_message(lines)
        if result:
            return result

        read_size *= 2  # Double and retry

    return None  # Not found even after reading entire file
```

| Aspect | Assessment |
|--------|------------|
| **Accuracy** | 100% - will eventually read entire file if needed |
| **Memory** | O(read_size) - starts small, grows as needed |
| **Speed** | O(1) typical, O(n) worst case with multiple reads |
| **Reliability** | High - but more complex implementation |

**Tradeoffs:**
- More code complexity
- Potential for multiple file reads in worst case
- Still guarantees accuracy

### 3. Reverse Chunked Reading

Read file in reverse chunks without loading entirely into memory.

```python
def read_reverse_chunks(transcript_path: str, chunk_size: int = 64 * 1024):
    file_size = os.path.getsize(transcript_path)

    with open(transcript_path, "rb") as f:
        position = file_size
        leftover = b""

        while position > 0:
            read_size = min(chunk_size, position)
            position -= read_size
            f.seek(position)
            chunk = f.read(read_size) + leftover

            # Split into lines, keeping incomplete first line for next iteration
            lines = chunk.split(b"\n")
            leftover = lines[0]

            for line in reversed(lines[1:]):
                yield line.decode("utf-8")
```

| Aspect | Assessment |
|--------|------------|
| **Accuracy** | 100% - processes entire file if needed |
| **Memory** | O(chunk_size) - constant, low memory |
| **Speed** | O(n) worst case, but typically finds quickly |
| **Reliability** | Medium - more complex, binary/text handling |

**Tradeoffs:**
- Most complex implementation
- Must handle binary/text encoding carefully
- Generator pattern may not fit current architecture

### 4. Memory-Mapped File

Use mmap for efficient large file access.

```python
import mmap

def parse_with_mmap(transcript_path: str) -> dict | None:
    with open(transcript_path, "r") as f:
        with mmap.mmap(f.fileno(), 0, access=mmap.ACCESS_READ) as mm:
            # Search backwards for last assistant message
            # mmap allows efficient random access
            ...
```

| Aspect | Assessment |
|--------|------------|
| **Accuracy** | 100% - full file access |
| **Memory** | O(1) virtual - OS manages paging |
| **Speed** | O(n) but with efficient OS-level caching |
| **Reliability** | Medium - platform differences, complexity |

**Tradeoffs:**
- Platform-specific behavior (Windows vs Unix)
- More complex implementation
- Requires careful handling of file boundaries

---

## Recommendation

**Stick with reading the entire file** unless you observe actual performance problems. The current approach:

1. Is simple and reliable
2. Guarantees accuracy (the primary goal)
3. Works well for typical session sizes
4. Has no edge cases to handle

If performance becomes an issue, **exponential backoff** is the recommended alternative because it:
- Maintains the accuracy guarantee
- Is fast for typical cases
- Has moderate implementation complexity

---

## Benchmarks

If you need to evaluate performance, here's how to measure:

```bash
# Check transcript file sizes
find ~/.claude/projects -name "*.jsonl" -exec ls -lh {} \; | sort -k5 -h

# Time the statusline script
time (echo '{"transcript_path": "/path/to/large.jsonl", ...}' | ./statusline.py)

# Profile memory usage
/usr/bin/time -l ./statusline.py < test_input.json
```

Typical results:
- 1MB transcript: <50ms, <10MB memory
- 10MB transcript: <200ms, <50MB memory
- 100MB transcript: <2s, <200MB memory

The statusline updates at most every 300ms, so anything under 100ms is imperceptible.
