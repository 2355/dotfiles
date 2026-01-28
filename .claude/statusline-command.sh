#!/bin/bash

# Read JSON input from stdin
input=$(cat)

# Current directory with ~ substitution
current_dir=$(pwd | sed "s|^$HOME|~|")

# Git info
git_info=""
if git rev-parse --git-dir > /dev/null 2>&1; then
  branch=$(git symbolic-ref --short HEAD 2>/dev/null || git rev-parse --short HEAD 2>/dev/null)
  staged=""
  unstaged=""

  if ! git diff --cached --quiet 2>/dev/null; then
    staged="\033[33m!"
  fi

  if ! git diff --quiet 2>/dev/null; then
    unstaged="\033[31m+"
  fi

  if [ -n "$branch" ]; then
    git_info=" \033[32m${staged}${unstaged}(${branch})\033[0m"
  fi
fi

# Context window info (usage percentage)
context_info=""
remaining=$(echo "$input" | jq -r '.context_window.remaining_percentage // empty')
if [ -n "$remaining" ]; then
  used_int=$(printf "%.0f" "$(echo "100 - $remaining" | bc)")

  if [ "$used_int" -lt 50 ]; then
    color="\033[90m"
  elif [ "$used_int" -lt 75 ]; then
    color="\033[33m"
  else
    color="\033[31m"
  fi

  context_info=" ${color}[ctx:${used_int}%]\033[0m"
fi

# Output status line
printf "\033[36m%s\033[0m%b%b" "$current_dir" "$git_info" "$context_info"
