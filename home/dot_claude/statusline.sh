#!/usr/bin/env bash
input=$(cat)
folder=$(echo "$input" | jq -r '.workspace.current_dir // .cwd' | xargs basename)
model=$(echo "$input" | jq -r '.model.display_name')
e=$(printf '\033')
printf "${e}[48;5;26m${e}[38;5;255m \xef\x81\xbb %s ${e}[48;5;99m${e}[38;5;26m\xee\x82\xb0${e}[38;5;255m \xe2\x98\x85 %s ${e}[0m${e}[38;5;99m\xee\x82\xb0${e}[0m" \
  "$folder" "$model"
