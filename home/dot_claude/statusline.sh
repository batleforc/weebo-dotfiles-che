#!/usr/bin/env bash
input=$(cat)
folder=$(echo "$input" | jq -r '.workspace.current_dir // .cwd' | xargs basename)
model=$(echo "$input" | jq -r '.model.display_name')
pct=$(echo "$input" | jq -r '.context_window.used_percentage // 0 | floor')
e=$(printf '\033')

# Context window color: green <50%, amber 50-70%, red >=70%
if [ "$pct" -lt 50 ]; then ctx_bg=34
elif [ "$pct" -lt 70 ]; then ctx_bg=178
else ctx_bg=160
fi

# Plan usage — cached for 60s
cache_file="/tmp/claude_usage_cache.json"
cache_mtime=$(stat -c %Y "$cache_file" 2>/dev/null || echo 0)
cache_age=$(( $(date +%s) - cache_mtime ))

if [ "$cache_age" -gt 60 ]; then
  token=$(jq -r '.claudeAiOauth.accessToken // empty' ~/.claude/.credentials.json 2>/dev/null)
  if [ -n "$token" ]; then
    curl -sf \
      -H "Authorization: Bearer $token" \
      -H "anthropic-beta: oauth-2025-04-20" \
      -H "Content-Type: application/json" \
      "https://api.anthropic.com/api/oauth/usage" \
      -o "$cache_file" 2>/dev/null || true
  fi
fi

fh=0; sd=0
if [ -f "$cache_file" ]; then
  fh=$(jq -r '.five_hour.utilization  // 0 | floor' "$cache_file" 2>/dev/null || echo 0)
  sd=$(jq -r '.seven_day.utilization  // 0 | floor' "$cache_file" 2>/dev/null || echo 0)
fi

# Plan usage color: green <50%, amber 50-80%, red >=80%
plan_bg() {
  local p=$1
  if   [ "$p" -lt 50 ]; then echo 34
  elif [ "$p" -lt 80 ]; then echo 178
  else echo 160
  fi
}
fh_bg=$(plan_bg "$fh")
sd_bg=$(plan_bg "$sd")

printf \
  "${e}[48;5;26m${e}[38;5;255m \xef\x81\xbb %s " \
  "$folder"
printf \
  "${e}[48;5;99m${e}[38;5;26m\xee\x82\xb0${e}[38;5;255m \xe2\x98\x85 %s " \
  "$model"
printf \
  "${e}[48;5;${ctx_bg}m${e}[38;5;99m\xee\x82\xb0${e}[38;5;255m Context %s%% " \
  "$pct"
printf \
  "${e}[48;5;${fh_bg}m${e}[38;5;${ctx_bg}m\xee\x82\xb0${e}[38;5;255m 5h %s%% " \
  "$fh"
printf \
  "${e}[48;5;${sd_bg}m${e}[38;5;${fh_bg}m\xee\x82\xb0${e}[38;5;255m 7d %s%% " \
  "$sd"
printf "${e}[0m${e}[38;5;${sd_bg}m\xee\x82\xb0${e}[0m"
