#!/usr/bin/env bash
#
# clean.sh — nuke build/cache directories under /projects
#
set -euo pipefail

# ── Config ──────────────────────────────────────────────────────────────────
ROOT="${CLEAN_ROOT:-/projects}"
TARGETS=(node_modules target dist)

# ── Colors ──────────────────────────────────────────────────────────────────
e=$(printf '\033')
BOLD="${e}[1m"; DIM="${e}[2m"; RESET="${e}[0m"
RED="${e}[31m"; GREEN="${e}[32m"; YELLOW="${e}[33m"
BLUE="${e}[34m"; CYAN="${e}[36m"

# ── ASCII art ───────────────────────────────────────────────────────────────
banner() {
  printf '%s' "$CYAN"
  cat <<'EOF'
   ______   __       ______   ______   __   __
  /\  ___\ /\ \     /\  ___\ /\  __ \ /\ "-.\ \
  \ \ \____\ \ \____\ \  __\ \ \  __ \\ \ \-.  \
   \ \_____\\ \_____\\ \_____\\ \_\ \_\\ \_\\"\_\
    \/_____/ \/_____/ \/_____/ \/_/\/_/ \/_/ \/_/
EOF
  printf '%s' "$RESET"
  printf "  %s»%s scrubbing %s%s%s for %s%s%s\n\n" \
    "$DIM" "$RESET" "$BOLD" "$ROOT" "$RESET" \
    "$YELLOW" "${TARGETS[*]}" "$RESET"
}

# ── Human-readable size of a path ───────────────────────────────────────────
dir_size() { du -sh "$1" 2>/dev/null | cut -f1; }

# ── Args ────────────────────────────────────────────────────────────────────
DRY_RUN=0
ASSUME_YES=0
for arg in "$@"; do
  case "$arg" in
    -n|--dry-run) DRY_RUN=1 ;;
    -y|--yes)     ASSUME_YES=1 ;;
    -h|--help)
      banner
      cat <<EOF
Usage: clean.sh [options]

  -n, --dry-run   Show what would be removed without deleting anything
  -y, --yes       Skip the confirmation prompt
  -h, --help      Show this help

Environment:
  CLEAN_ROOT      Directory to scan (default: /projects)
EOF
      exit 0 ;;
    *)
      printf "%s✗%s unknown option: %s\n" "$RED" "$RESET" "$arg" >&2
      exit 1 ;;
  esac
done

# ── Main ────────────────────────────────────────────────────────────────────
banner

if [[ ! -d "$ROOT" ]]; then
  printf "%s✗%s root directory does not exist: %s\n" "$RED" "$RESET" "$ROOT" >&2
  exit 1
fi

# Build the -name predicate: \( -name node_modules -o -name target ... \)
find_expr=()
for i in "${!TARGETS[@]}"; do
  ((i > 0)) && find_expr+=(-o)
  find_expr+=(-name "${TARGETS[$i]}")
done

# Collect matches. -prune stops find from descending into a match, so we
# never recurse into a node_modules to hunt for a nested dist.
mapfile -t matches < <(
  find "$ROOT" -type d \( "${find_expr[@]}" \) -prune 2>/dev/null | sort
)

if (( ${#matches[@]} == 0 )); then
  printf "%s✓%s nothing to clean — you're already tidy.\n" "$GREEN" "$RESET"
  exit 0
fi

# Report what we found, tallying total disk usage in KiB.
printf "%sFound %d director%s:%s\n" \
  "$BOLD" "${#matches[@]}" "$([[ ${#matches[@]} -eq 1 ]] && echo y || echo ies)" "$RESET"

total_kib=0
for dir in "${matches[@]}"; do
  kib=$(du -sk "$dir" 2>/dev/null | cut -f1 || echo 0)
  total_kib=$(( total_kib + kib ))
  printf "  %s•%s %s %s(%s)%s\n" \
    "$DIM" "$RESET" "$dir" "$YELLOW" "$(dir_size "$dir")" "$RESET"
done

# Pretty-print the reclaimable total.
total_human=$(numfmt --to=iec --suffix=B $(( total_kib * 1024 )) 2>/dev/null || echo "${total_kib}K")
printf "\n%sReclaimable:%s %s%s%s\n\n" "$BOLD" "$RESET" "$GREEN" "$total_human" "$RESET"

if (( DRY_RUN )); then
  printf "%s»%s dry run — nothing was deleted.\n" "$BLUE" "$RESET"
  exit 0
fi

if (( ! ASSUME_YES )); then
  printf "%sDelete all of the above? %s[y/N]%s " "$BOLD" "$DIM" "$RESET"
  read -r reply
  case "$reply" in
    [yY]|[yY][eE][sS]) ;;
    *) printf "%s✗%s aborted.\n" "$RED" "$RESET"; exit 1 ;;
  esac
fi

# Delete.
removed=0
for dir in "${matches[@]}"; do
  if rm -rf -- "$dir"; then
    printf "  %s✓%s removed %s\n" "$GREEN" "$RESET" "$dir"
    (( ++removed ))
  else
    printf "  %s✗%s failed   %s\n" "$RED" "$RESET" "$dir"
  fi
done

printf "\n%s✓%s done — %d/%d removed, %s%s%s reclaimed.\n" \
  "$GREEN" "$RESET" "$removed" "${#matches[@]}" "$GREEN" "$total_human" "$RESET"
