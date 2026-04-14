#!/usr/bin/env bash

input=$(cat)

# ANSI colors
RESET="\033[0m"
BOLD="\033[1m"
DIM="\033[2m"
CYAN="\033[36m"
YELLOW="\033[33m"
GREEN="\033[32m"
MAGENTA="\033[35m"
RED="\033[31m"
BLUE="\033[34m"
WHITE="\033[97m"

# --- Git branch ---
cwd=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // empty')
branch=""
if [ -n "$cwd" ]; then
  branch=$(git -C "$cwd" symbolic-ref --short HEAD 2>/dev/null)
  if [ -z "$branch" ]; then
    short_sha=$(git -C "$cwd" rev-parse --short HEAD 2>/dev/null)
    [ -n "$short_sha" ] && branch="detached@${short_sha}"
  fi
fi

# --- Model & Effort ---
model_name=$(echo "$input" | jq -r '.model.display_name // "Unknown"')
effort=$(jq -r '.effortLevel // empty' ~/.claude/settings.json 2>/dev/null)

# Map effort to a readable label + colour
case "$effort" in
  high|High)       effort_label="High Effort";   effort_color="$RED"     ;;
  medium|Medium)   effort_label="Medium Effort";  effort_color="$YELLOW"  ;;
  low|Low)         effort_label="Low Effort";    effort_color="$GREEN"   ;;
  *)
    if [ -n "$effort" ]; then
      effort_label="$effort"
      effort_color="$CYAN"
    else
      effort_label=""
      effort_color=""
    fi
    ;;
esac

# --- Context window ---
# Derive raw used tokens from current_usage (the integer used_percentage field
# only gives whole-percent granularity, so we compute our own).
used_tokens=$(echo "$input" | jq -r '
  (.context_window.current_usage.input_tokens // 0) +
  (.context_window.current_usage.output_tokens // 0) +
  (.context_window.current_usage.cache_creation_input_tokens // 0) +
  (.context_window.current_usage.cache_read_input_tokens // 0)
')
ctx_size=$(echo "$input" | jq -r '.context_window.context_window_size // empty')

if [ -n "$ctx_size" ] && [ "$used_tokens" != "0" ]; then
  ctx_str=$(awk "BEGIN {
    used = $used_tokens
    if (used >= 1000000) {
      printf \"%.1fM\", used/1000000
    } else {
      printf \"%.1fk\", used/1000
    }
  }")
  size_str=$(awk "BEGIN {
    s = $ctx_size
    if (s >= 1000000) {
      printf \"%.0fM\", s/1000000
    } else {
      printf \"%.0fk\", s/1000
    }
  }")
  used_pct=$(awk "BEGIN { printf \"%.1f\", $used_tokens * 100 / $ctx_size }")
  pct_str=$(printf "%.1f%%" "$used_pct")

  # Colour the percentage based on usage
  pct_int=$(printf "%.0f" "$used_pct")
  if [ "$pct_int" -ge 80 ]; then
    pct_color="$RED"
  elif [ "$pct_int" -ge 50 ]; then
    pct_color="$YELLOW"
  else
    pct_color="$GREEN"
  fi
else
  ctx_str="—"
  size_str="—"
  pct_str="—"
  pct_color="$DIM"
fi

# --- Rate limits ---
five_pct=$(echo "$input"  | jq -r '.rate_limits.five_hour.used_percentage  // empty')
seven_pct=$(echo "$input" | jq -r '.rate_limits.seven_day.used_percentage  // empty')

rate_parts=""
if [ -n "$five_pct" ]; then
  five_fmt=$(printf "%d%%" "$five_pct")
  five_int=$five_pct
  if [ "$five_int" -ge 80 ]; then fc="$RED"; elif [ "$five_int" -ge 50 ]; then fc="$YELLOW"; else fc="$GREEN"; fi
  rate_parts="${fc}${five_fmt}${RESET} ${DIM}(5h)${RESET}"
fi
if [ -n "$seven_pct" ]; then
  seven_fmt=$(printf "%d%%" "$seven_pct")
  seven_int=$seven_pct
  if [ "$seven_int" -ge 80 ]; then sc="$RED"; elif [ "$seven_int" -ge 50 ]; then sc="$YELLOW"; else sc="$GREEN"; fi
  if [ -n "$rate_parts" ]; then
    rate_parts="${rate_parts} ${DIM}-${RESET} ${sc}${seven_fmt}${RESET} ${DIM}(7d)${RESET}"
  else
    rate_parts="${sc}${seven_fmt}${RESET} ${DIM}(7d)${RESET}"
  fi
fi

# --- Assemble output ---
out=""

# Segment 1: 📁 current working directory (with ~ for $HOME)
if [ -n "$cwd" ]; then
  cwd_display="${cwd/#$HOME/~}"
  out+="📁 ${BOLD}${BLUE}${cwd_display}${RESET}"
  out+=" ${DIM}|${RESET} "
fi

# Segment 2: 🌿 git branch (only if in a git repo)
if [ -n "$branch" ]; then
  out+="🌿 ${BOLD}${MAGENTA}${branch}${RESET}"
  out+=" ${DIM}|${RESET} "
fi

# Segment 2: 🤖 Model - Effort
out+="🤖 ${BOLD}${CYAN}${model_name}${RESET}"
if [ -n "$effort_label" ]; then
  out+=" ${DIM}-${RESET} ${effort_color}${effort_label}${RESET}"
fi

# Segment 3: 🧠 context tokens / size  percentage
out+=" ${DIM}|${RESET} "
out+="🧠 ${BOLD}${WHITE}${ctx_str}/${size_str}${RESET} ${pct_color}${pct_str}${RESET}"

# Segment 4: ⏱ rate limits (only if data is available)
if [ -n "$rate_parts" ]; then
  out+=" ${DIM}|${RESET} "
  out+="⏱ ${rate_parts}"
fi

printf "%b" "$out"
