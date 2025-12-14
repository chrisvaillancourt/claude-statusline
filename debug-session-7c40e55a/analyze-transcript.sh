#!/bin/bash
# Quick analysis tool for the session transcript

TRANSCRIPT="transcript.jsonl"

if [ ! -f "$TRANSCRIPT" ]; then
    echo "Error: $TRANSCRIPT not found"
    echo "Run this script from the debug-session-7c40e55a directory"
    exit 1
fi

show_help() {
    cat << EOF
Session Transcript Analysis Tool

Usage: $0 [command]

Commands:
  summary       - Show session summary (default)
  timeline      - Show conversation timeline
  tokens        - Show token usage progression
  tools         - List all tools used
  bash          - Show all bash commands run
  reads         - Show all files read
  writes        - Show all files written
  errors        - Find any errors or failures
  costs         - Show cost breakdown
  jumps         - Find large token jumps
  raw [type]    - Show raw JSON for specific type (user, assistant, tool_use, etc)

Examples:
  $0 summary
  $0 timeline | less
  $0 bash
  $0 raw assistant | jq '.message.usage'
EOF
}

summary() {
    echo "=== SESSION SUMMARY ==="
    echo ""

    local session_id=$(jq -r 'select(.sessionId) | .sessionId' "$TRANSCRIPT" | head -1)
    local start_time=$(jq -r 'select(.timestamp) | .timestamp' "$TRANSCRIPT" | head -1)
    local end_time=$(jq -r 'select(.timestamp) | .timestamp' "$TRANSCRIPT" | tail -1)
    local total_lines=$(wc -l < "$TRANSCRIPT")
    local user_msgs=$(jq 'select(.type == "user")' "$TRANSCRIPT" | wc -l)
    local assistant_msgs=$(jq 'select(.type == "assistant")' "$TRANSCRIPT" | wc -l)
    local tool_uses=$(jq 'select(.message.content[]? | type == "array") | .message.content[] | select(.type == "tool_use")' "$TRANSCRIPT" | wc -l)

    echo "Session ID: $session_id"
    echo "Start time: $start_time"
    echo "End time:   $end_time"
    echo ""
    echo "Total events:     $total_lines"
    echo "User messages:    $user_msgs"
    echo "Assistant msgs:   $assistant_msgs"
    echo "Tool calls:       $tool_uses"
    echo ""

    local final_tokens=$(jq -s '[.[] | select(.message.usage?) | .message.usage] | last | .input_tokens + .output_tokens' "$TRANSCRIPT")
    local final_cost=$(jq -s '[.[] | select(.message.usage?) | .message.usage.input_tokens * 0.000003 + .message.usage.output_tokens * 0.000015] | add' "$TRANSCRIPT")

    echo "Final token count: $final_tokens"
    echo "Estimated cost:    \$$final_cost USD"
}

timeline() {
    echo "=== CONVERSATION TIMELINE ==="
    echo ""
    jq -r 'select(.type == "user" or .type == "assistant") |
           "\(.timestamp | sub("T"; " ") | sub("\\..*Z"; "")) | \(.type | ascii_upcase | .[0:4]): \(
             if .message.content then
               (.message.content | if type == "string" then . else .[0].text // "<<complex>>" end | .[0:100])
             else "<<no content>>" end
           )"' "$TRANSCRIPT"
}

tokens() {
    echo "=== TOKEN USAGE PROGRESSION ==="
    echo ""
    echo "Timestamp                | Input   | Output  | Total   | Delta"
    echo "-------------------------|---------|---------|---------|-------"

    jq -r 'select(.message.usage?) |
           "\(.timestamp | sub("T"; " ") | sub("\\..*Z"; "")) | \(.message.usage.input_tokens) | \(.message.usage.output_tokens) | \(.message.usage.input_tokens + .message.usage.output_tokens)"' \
           "$TRANSCRIPT" | \
    awk '{
        split($1, date, " ");
        time = date[2];
        input = $3;
        output = $5;
        total = $7;
        delta = total - prev_total;
        if (NR > 1) {
            printf "%s | %7d | %7d | %7d | %+6d\n", time, input, output, total, delta;
        } else {
            printf "%s | %7d | %7d | %7d | %6s\n", time, input, output, total, "-";
        }
        prev_total = total;
    }'
}

tools() {
    echo "=== TOOLS USED ==="
    echo ""
    jq -r 'select(.message.content[]? | type == "array") |
           .message.content[] |
           select(.type == "tool_use") |
           .name' "$TRANSCRIPT" | sort | uniq -c | sort -rn
}

bash_commands() {
    echo "=== BASH COMMANDS EXECUTED ==="
    echo ""
    jq -r 'select(.message.content[]? | type == "array") |
           .message.content[] |
           select(.type == "tool_use" and .name == "Bash") |
           "\(.input.description // "No description"):\n  \(.input.command)\n"' "$TRANSCRIPT"
}

reads() {
    echo "=== FILES READ ==="
    echo ""
    jq -r 'select(.message.content[]? | type == "array") |
           .message.content[] |
           select(.type == "tool_use" and .name == "Read") |
           .input.file_path' "$TRANSCRIPT" | sort -u
}

writes() {
    echo "=== FILES WRITTEN ==="
    echo ""
    jq -r 'select(.message.content[]? | type == "array") |
           .message.content[] |
           select(.type == "tool_use" and (.name == "Write" or .name == "Edit")) |
           "\(.name): \(.input.file_path)"' "$TRANSCRIPT" | sort -u
}

errors() {
    echo "=== ERRORS AND FAILURES ==="
    echo ""
    jq -r 'select(.message.content[]? | type == "array") |
           .message.content[] |
           select(.type == "tool_result" and (.isError == true or .content | contains("error") or contains("Error") or contains("failed"))) |
           "\(.timestamp): \(.content | .[0:200])"' "$TRANSCRIPT"
}

costs() {
    echo "=== COST BREAKDOWN ==="
    echo ""

    local total_input=$(jq -s '[.[] | select(.message.usage?) | .message.usage.input_tokens] | add' "$TRANSCRIPT")
    local total_output=$(jq -s '[.[] | select(.message.usage?) | .message.usage.output_tokens] | add' "$TRANSCRIPT")
    local total_cache_create=$(jq -s '[.[] | select(.message.usage?) | .message.usage.cache_creation_input_tokens // 0] | add' "$TRANSCRIPT")
    local total_cache_read=$(jq -s '[.[] | select(.message.usage?) | .message.usage.cache_read_input_tokens // 0] | add' "$TRANSCRIPT")

    # Sonnet 4.5 pricing (as of Dec 2025)
    local input_cost=$(echo "$total_input * 0.000003" | bc -l)
    local output_cost=$(echo "$total_output * 0.000015" | bc -l)
    local cache_write_cost=$(echo "$total_cache_create * 0.00000375" | bc -l)
    local cache_read_cost=$(echo "$total_cache_read * 0.0000003" | bc -l)
    local total_cost=$(echo "$input_cost + $output_cost + $cache_write_cost + $cache_read_cost" | bc -l)

    printf "Input tokens:        %10d @ \$0.003/1K  = \$%.4f\n" "$total_input" "$input_cost"
    printf "Output tokens:       %10d @ \$0.015/1K  = \$%.4f\n" "$total_output" "$output_cost"
    printf "Cache write:         %10d @ \$0.00375/1K = \$%.4f\n" "$total_cache_create" "$cache_write_cost"
    printf "Cache read:          %10d @ \$0.0003/1K = \$%.4f\n" "$total_cache_read" "$cache_read_cost"
    printf "%s\n" "$(printf '%.0s-' {1..60})"
    printf "Total estimated:                          \$%.4f\n" "$total_cost"
}

jumps() {
    echo "=== LARGE TOKEN JUMPS (>1000 tokens) ==="
    echo ""
    echo "Time     | Previous | Current | Jump    | Description"
    echo "---------|----------|---------|---------|------------------"

    jq -r 'select(.message.usage?) |
           "\(.timestamp | sub("T"; " ") | sub("\\..*Z"; "")) | \(.message.usage.input_tokens + .message.usage.output_tokens) | \(.message.content[0].text // "<<tool use>>" | .[0:50])"' \
           "$TRANSCRIPT" | \
    awk -F'|' '{
        time = $1;
        gsub(/^[ \t]+|[ \t]+$/, "", time);
        total = $2;
        gsub(/^[ \t]+|[ \t]+$/, "", total);
        desc = $3;
        gsub(/^[ \t]+|[ \t]+$/, "", desc);

        if (prev_total > 0) {
            jump = total - prev_total;
            if (jump > 1000) {
                printf "%s | %8d | %7d | %+7d | %s\n", time, prev_total, total, jump, desc;
            }
        }
        prev_total = total;
    }'
}

raw() {
    local type="$1"
    if [ -z "$type" ]; then
        echo "Error: Please specify a type (user, assistant, tool_use, etc.)"
        exit 1
    fi

    jq "select(.type == \"$type\")" "$TRANSCRIPT"
}

# Main command dispatcher
case "${1:-summary}" in
    summary)   summary ;;
    timeline)  timeline ;;
    tokens)    tokens ;;
    tools)     tools ;;
    bash)      bash_commands ;;
    reads)     reads ;;
    writes)    writes ;;
    errors)    errors ;;
    costs)     costs ;;
    jumps)     jumps ;;
    raw)       raw "$2" ;;
    help|-h)   show_help ;;
    *)         echo "Unknown command: $1"; show_help; exit 1 ;;
esac
