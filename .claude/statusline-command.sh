#!/bin/bash

# Read JSON input from stdin
input=$(cat)

# rate_limits 等をエージェント側から参照できるよう入力 JSON をキャッシュする
# （部分読み込み防止のため atomic に置換。tmp 名に PID を含め並行実行時の mv 競合を防ぐ）
echo "$input" > ~/.claude/statusline-input-cache.json.tmp.$$ && mv ~/.claude/statusline-input-cache.json.tmp.$$ ~/.claude/statusline-input-cache.json

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

# Model info
model_info=""
model_name=$(echo "$input" | jq -r '.model.display_name // empty')
if [ -n "$model_name" ]; then
  model_info=" 🤖 \033[34m${model_name}\033[0m"
fi

# グレーの区切り線（パーセント以外は色を付けない）
sep=" \033[90m|\033[0m "

# 使用率%を閾値で色分けして出力する（<=50 緑 / <75 黄 / それ以上 赤。取得不可は "-"）
pct_colored() {
  local pct=$1 color
  if [ -z "$pct" ]; then
    printf '\033[90m-\033[0m'
    return
  fi
  pct=$(printf "%.0f" "$pct")
  if [ "$pct" -le 50 ]; then
    color="\033[32m"
  elif [ "$pct" -lt 75 ]; then
    color="\033[33m"
  else
    color="\033[31m"
  fi
  printf '%b%s%%\033[0m' "$color" "$pct"
}

# epoch 秒までの残り時間を 4d10h / 2h10m / 15m の形式で返す（過去なら空）
rel_time() {
  local diff=$(( $1 - $(date +%s) )) d h m
  [ "$diff" -le 0 ] && return
  d=$(( diff / 86400 ))
  h=$(( diff % 86400 / 3600 ))
  m=$(( diff % 3600 / 60 ))
  if [ "$d" -gt 0 ]; then
    printf '%dd%dh' "$d" "$h"
  elif [ "$h" -gt 0 ]; then
    printf '%dh%dm' "$h" "$m"
  else
    printf '%dm' "$m"
  fi
}

# Context window info (usage percentage)
context_info=""
remaining=$(echo "$input" | jq -r '.context_window.remaining_percentage // empty')
if [ -n "$remaining" ]; then
  used_int=$(printf "%.0f" "$(echo "100 - $remaining" | bc)")
  context_info="${sep}🧠 $(pct_colored "$used_int")"
fi

# Usage limits (2nd line)
# statusLine の stdin JSON にはモデル別の週次使用率が無いため、/usage と同じ
# api.anthropic.com/api/oauth/usage を Keychain の OAuth トークンで叩いて取得する。
# 非公開 API のため仕様変更で壊れる可能性あり。その場合は stdin にフォールバックする
usage_cache="$HOME/.claude/statusline-usage-cache.json"
cache_ttl=60
cache_mtime=$(stat -f %m "$usage_cache" 2>/dev/null || echo 0)
if [ $(( $(date +%s) - cache_mtime )) -ge "$cache_ttl" ]; then
  # statusLine は高頻度で並行実行されるため、mkdir ロックでフェッチを1本に絞る。
  # プロセス異常終了でロックが残ってもフェッチが止まり続けないよう、古いロックは無効化する
  lock="${usage_cache}.lock"
  lock_mtime=$(stat -f %m "$lock" 2>/dev/null || echo 0)
  [ $(( $(date +%s) - lock_mtime )) -ge "$cache_ttl" ] && rmdir "$lock" 2>/dev/null
  if mkdir "$lock" 2>/dev/null; then
    (
      trap 'rmdir "$lock" 2>/dev/null' EXIT
      # トークンはディスクに書かず、レスポンス（使用率のみ）だけをキャッシュする
      token=$(security find-generic-password -s "Claude Code-credentials" -w 2>/dev/null | jq -r '.claudeAiOauth.accessToken // empty')
      tmp="${usage_cache}.tmp.$$"
      if [ -n "$token" ] && curl -sS -m 5 "https://api.anthropic.com/api/oauth/usage" \
          -H "Authorization: Bearer $token" \
          -H "anthropic-beta: oauth-2025-04-20" > "$tmp" 2>/dev/null \
          && jq -e '.limits' "$tmp" > /dev/null 2>&1; then
        chmod 600 "$tmp" && mv "$tmp" "$usage_cache"
      else
        rm -f "$tmp"
      fi
    ) > /dev/null 2>&1 &
  fi
fi

# resets_at は ISO 8601（小数秒 + +00:00 オフセット付き）なので epoch 秒に正規化する
ISO_TO_EPOCH='sub("\\.[0-9]+"; "") | sub("\\+00:00$"; "Z") | fromdateiso8601'
session_pct=""
week_pct=""
fable_pct=""
session_reset=""
week_reset=""
if [ -f "$usage_cache" ]; then
  session_pct=$(jq -r 'first(.limits[] | select(.kind=="session") | .percent) // empty' "$usage_cache" 2>/dev/null)
  week_pct=$(jq -r 'first(.limits[] | select(.kind=="weekly_all") | .percent) // empty' "$usage_cache" 2>/dev/null)
  fable_pct=$(jq -r 'first(.limits[] | select(.kind=="weekly_scoped") | .percent) // empty' "$usage_cache" 2>/dev/null)
  session_reset=$(jq -r "(first(.limits[] | select(.kind==\"session\") | .resets_at) // empty) | $ISO_TO_EPOCH" "$usage_cache" 2>/dev/null)
  week_reset=$(jq -r "(first(.limits[] | select(.kind==\"weekly_all\") | .resets_at) // empty) | $ISO_TO_EPOCH" "$usage_cache" 2>/dev/null)
fi
# キャッシュ未生成・API 失敗時のフォールバック(モデル別使用率は stdin に無いため fable は不可)
[ -z "$session_pct" ] && session_pct=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
[ -z "$week_pct" ] && week_pct=$(echo "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty')
[ -z "$session_reset" ] && session_reset=$(echo "$input" | jq -r '.rate_limits.five_hour.resets_at // empty')
[ -z "$week_reset" ] && week_reset=$(echo "$input" | jq -r '.rate_limits.seven_day.resets_at // empty')

session_rel=""
week_rel=""
[ -n "$session_reset" ] && session_rel=$(rel_time "$session_reset")
[ -n "$week_reset" ] && week_rel=$(rel_time "$week_reset")

# ⏱ = 5h セッション制限 / 📅 = 週次制限(全モデル) / 🦋 = Fable の週次制限
usage_line="⏱ $(pct_colored "$session_pct")${session_rel:+ $session_rel}${sep}📅 $(pct_colored "$week_pct") 🦋 $(pct_colored "$fable_pct")${week_rel:+ $week_rel}"

# Output status line
printf "\033[36m%s\033[0m%b%b%b\n%b" "$current_dir" "$git_info" "$model_info" "$context_info" "$usage_line"
