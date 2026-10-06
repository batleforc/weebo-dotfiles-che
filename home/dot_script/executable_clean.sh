#!/usr/bin/env bash
#
# clean.sh — nuke build/cache directories under /projects
#
set -euo pipefail

# ── Config ──────────────────────────────────────────────────────────────────
ROOT="${CLEAN_ROOT:-/projects}"
TARGETS=(node_modules target dist)
# Extra names scanned with -c/--cache: per-project cache dirs whose names are
# unambiguous enough to not need an ecosystem marker.
CACHE_TARGETS=(.cache __pycache__ .pytest_cache .mypy_cache .ruff_cache
               .turbo .parcel-cache .vite .gradle
               .venv venv .terraform .tox .next .nuxt .svelte-kit coverage)
# Global per-user caches (outside $ROOT), removed with -g/--global-cache.
# All of these are pure download/build caches the tools rebuild on demand.
# Resolution order: ask the tool itself when installed, then the tool's
# env var, then the standard default location (XDG-aware).
XDG_CACHE="${XDG_CACHE_HOME:-$HOME/.cache}"
GLOBAL_CACHES=()

# Run a tool's "print my cache dir" command; emit the fallback when the
# tool is missing or prints nothing usable. Tools wrap the path in banner
# lines (yarn v1 does), so keep only the first absolute path.
tool_path() { # <fallback> <cmd> [args...]
  local fallback="$1"; shift
  local out=""
  if command -v "$1" >/dev/null 2>&1; then
    out=$("$@" 2>/dev/null | grep -m1 '^/' || true)
  fi
  printf '%s' "${out:-$fallback}"
}

resolve_global_caches() {
  local pip_cmd=pip
  command -v pip >/dev/null 2>&1 || pip_cmd=pip3
  GLOBAL_CACHES=(
    "npm|$(tool_path "${NPM_CONFIG_CACHE:-${npm_config_cache:-$HOME/.npm}}" npm config get cache)"
    "yarn|$(tool_path "${YARN_CACHE_FOLDER:-$XDG_CACHE/yarn}" yarn cache dir)"
    "pnpm store|$(tool_path "${PNPM_STORE_DIR:-$HOME/.local/share/pnpm/store}" pnpm store path)"
    "pip|$(tool_path "${PIP_CACHE_DIR:-$XDG_CACHE/pip}" "$pip_cmd" cache dir)"
    "uv|$(tool_path "${UV_CACHE_DIR:-$XDG_CACHE/uv}" uv cache dir)"
    "cargo registry|${CARGO_HOME:-$HOME/.cargo}/registry"
    "cargo git|${CARGO_HOME:-$HOME/.cargo}/git"
    "go build|$(tool_path "${GOCACHE:-$XDG_CACHE/go-build}" go env GOCACHE)"
    "gradle caches|${GRADLE_USER_HOME:-$HOME/.gradle}/caches"
    "gradle wrapper|${GRADLE_USER_HOME:-$HOME/.gradle}/wrapper"
  )
}

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

# ── Does this dir really belong to the ecosystem its name implies? ──────────
# Each cleanable name is only trusted when the surrounding project (or the
# dir itself) carries the matching ecosystem marker:
#   target       → Rust/Cargo: Cargo.toml next to it, or cargo's CACHEDIR.TAG
#   node_modules → Node: package.json next to it, or npm's .package-lock.json
#   dist         → JS/TS or Python build output: package.json, pyproject.toml
#                  or setup.py next to it
# Names without a rule are kept (better to list than to silently skip).
is_legit_build_dir() {
  local dir="$1" parent
  parent=$(dirname "$dir")
  case "$(basename "$dir")" in
    target)
      [[ -f "$parent/Cargo.toml" ]] || [[ -f "$dir/CACHEDIR.TAG" ]] ;;
    node_modules)
      [[ -f "$parent/package.json" ]] || [[ -f "$dir/.package-lock.json" ]] ;;
    dist)
      [[ -f "$parent/package.json" ]] || [[ -f "$parent/pyproject.toml" ]] \
        || [[ -f "$parent/setup.py" ]] ;;
    .venv|venv)
      [[ -f "$dir/pyvenv.cfg" ]] ;;
    .terraform)
      [[ -n $(find "$parent" -maxdepth 1 -name '*.tf' -print -quit 2>/dev/null) ]] ;;
    .tox)
      [[ -f "$parent/tox.ini" ]] || [[ -f "$parent/pyproject.toml" ]] \
        || [[ -f "$parent/setup.cfg" ]] ;;
    .next|.nuxt|.svelte-kit|coverage)
      [[ -f "$parent/package.json" ]] ;;
    *)
      return 0 ;;
  esac
}

# ── Args ────────────────────────────────────────────────────────────────────
DRY_RUN=0
ASSUME_YES=0
WITH_CACHE=0
WITH_GLOBAL=0
for arg in "$@"; do
  case "$arg" in
    -n|--dry-run)       DRY_RUN=1 ;;
    -y|--yes)           ASSUME_YES=1 ;;
    -c|--cache)         WITH_CACHE=1 ;;
    -g|--global-cache)  WITH_GLOBAL=1 ;;
    -h|--help)
      banner
      cat <<EOF
Usage: clean.sh [options]

  -n, --dry-run   Show what would be removed without deleting anything
  -y, --yes       Skip the confirmation prompt
  -c, --cache     Also remove per-project cache directories
                  (${CACHE_TARGETS[*]})
  -g, --global-cache
                  Also remove global per-user caches
                  (npm, yarn, pnpm store, pip, uv, cargo, go build,
                  gradle caches/wrapper), clear the mise cache, prune
                  unused mise tool versions, and offer a per-toolchain
                  choice to uninstall old rustup toolchains
  -h, --help      Show this help

Environment:
  CLEAN_ROOT      Directory to scan (default: /projects)

  Global cache locations are asked to the tools themselves when installed
  (npm config get cache, yarn cache dir, pnpm store path, pip cache dir,
  uv cache dir, go env GOCACHE), falling back to each tool's env var
  (NPM_CONFIG_CACHE / npm_config_cache, YARN_CACHE_FOLDER, PNPM_STORE_DIR,
  PIP_CACHE_DIR, UV_CACHE_DIR, CARGO_HOME, GOCACHE, MISE_CACHE_DIR),
  then to the standard defaults (XDG_CACHE_HOME-aware).
EOF
      exit 0 ;;
    *)
      printf "%s✗%s unknown option: %s\n" "$RED" "$RESET" "$arg" >&2
      exit 1 ;;
  esac
done

# ── Main ────────────────────────────────────────────────────────────────────
(( WITH_CACHE )) && TARGETS+=("${CACHE_TARGETS[@]}")

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
mapfile -t candidates < <(
  find "$ROOT" -type d \( "${find_expr[@]}" \) -prune 2>/dev/null | sort
)

# Keep a candidate only when its name matches the ecosystem of the project
# around it (e.g. a "target" without Cargo.toml is not a Rust target).
matches=()
for dir in "${candidates[@]}"; do
  if ! is_legit_build_dir "$dir"; then
    printf "  %s~%s skipping %s %s(no matching project marker)%s\n" \
      "$DIM" "$RESET" "$dir" "$DIM" "$RESET"
    continue
  fi
  matches+=("$dir")
done

# Global caches live under $HOME, outside the find scan.
global_matches=()
if (( WITH_GLOBAL )); then
  resolve_global_caches
  for entry in "${GLOBAL_CACHES[@]}"; do
    [[ -d "${entry#*|}" ]] && global_matches+=("$entry")
  done
fi

# mise's cache is global too, but it has official commands, so we use
# `mise cache clear` / `mise prune` (unused tool versions) instead of rm.
MISE_CACHE=""
MISE_PRUNE=0
if (( WITH_GLOBAL )) && command -v mise >/dev/null 2>&1; then
  MISE_CACHE="${MISE_CACHE_DIR:-${XDG_CACHE_HOME:-$HOME/.cache}/mise}"
  [[ -d "$MISE_CACHE" ]] || MISE_CACHE=""
  MISE_PRUNE=1
fi

# rustup toolchains pile up across updates; we never remove them blindly —
# the user picks per toolchain after the main confirmation.
RUSTUP_TCS=()
RUSTUP_DEFAULT=""
RUSTUP_TC_DIR="${RUSTUP_HOME:-$HOME/.rustup}/toolchains"
if (( WITH_GLOBAL )) && command -v rustup >/dev/null 2>&1; then
  RUSTUP_DEFAULT=$(rustup default 2>/dev/null | awk '{print $1}')
  while read -r tc _; do
    [[ -n "$tc" && -d "$RUSTUP_TC_DIR/$tc" ]] && RUSTUP_TCS+=("$tc")
  done < <(rustup toolchain list 2>/dev/null)
fi

if (( ${#matches[@]} == 0 && ${#global_matches[@]} == 0 && ! MISE_PRUNE \
      && ${#RUSTUP_TCS[@]} == 0 )) && [[ -z "$MISE_CACHE" ]]; then
  printf "%s✓%s nothing to clean — you're already tidy.\n" "$GREEN" "$RESET"
  exit 0
fi

# Report what we found, tallying total disk usage in KiB.
total_kib=0
if (( ${#matches[@]} > 0 )); then
  printf "%sFound %d director%s:%s\n" \
    "$BOLD" "${#matches[@]}" "$([[ ${#matches[@]} -eq 1 ]] && echo y || echo ies)" "$RESET"

  for dir in "${matches[@]}"; do
    kib=$(du -sk "$dir" 2>/dev/null | cut -f1 || echo 0)
    total_kib=$(( total_kib + kib ))
    printf "  %s•%s %s %s(%s)%s\n" \
      "$DIM" "$RESET" "$dir" "$YELLOW" "$(dir_size "$dir")" "$RESET"
  done
fi

if (( ${#global_matches[@]} > 0 )) || [[ -n "$MISE_CACHE" ]]; then
  printf "%sGlobal caches:%s\n" "$BOLD" "$RESET"
  for entry in "${global_matches[@]}"; do
    label=${entry%%|*}; dir=${entry#*|}
    kib=$(du -sk "$dir" 2>/dev/null | cut -f1 || echo 0)
    total_kib=$(( total_kib + kib ))
    printf "  %s•%s %-14s %s %s(%s)%s\n" \
      "$DIM" "$RESET" "$label" "$dir" "$YELLOW" "$(dir_size "$dir")" "$RESET"
  done
  if [[ -n "$MISE_CACHE" ]]; then
    kib=$(du -sk "$MISE_CACHE" 2>/dev/null | cut -f1 || echo 0)
    total_kib=$(( total_kib + kib ))
    printf "  %s•%s %-14s %s %s(%s)%s\n" \
      "$DIM" "$RESET" "mise" "$MISE_CACHE" "$YELLOW" "$(dir_size "$MISE_CACHE")" "$RESET"
  fi
  if (( MISE_PRUNE )); then
    mise_installs="${MISE_DATA_DIR:-$HOME/.local/share/mise}/installs"
    # Not counted in the total: `mise prune` only drops unused versions.
    printf "  %s•%s %-14s %s %s(%s, unused versions only)%s\n" \
      "$DIM" "$RESET" "mise installs" "$mise_installs" \
      "$YELLOW" "$(dir_size "$mise_installs")" "$RESET"
  fi
fi

if (( ${#RUSTUP_TCS[@]} > 0 )); then
  printf "%sRust toolchains%s %s(you will pick which to uninstall)%s\n" \
    "$BOLD" "$RESET" "$DIM" "$RESET"
  for tc in "${RUSTUP_TCS[@]}"; do
    note=""
    [[ "$tc" == "$RUSTUP_DEFAULT" ]] && note=" ${GREEN}(default — kept)${RESET}"
    printf "  %s•%s %s %s(%s)%s%b\n" \
      "$DIM" "$RESET" "$tc" "$YELLOW" "$(dir_size "$RUSTUP_TC_DIR/$tc")" "$RESET" "$note"
  done
fi

if (( WITH_GLOBAL )) && [[ -d "$HOME/.vscode-server" ]]; then
  printf "%s! note:%s ~/.vscode-server holds %s%s%s (old CLI/server builds pile up;\n" \
    "$YELLOW" "$RESET" "$YELLOW" "$(dir_size "$HOME/.vscode-server")" "$RESET"
  printf "  not touched automatically — clean while no IDE session is running)\n"
fi

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

# Global caches: some tools (go modules) write read-only files, so retry
# with a chmod when a plain rm fails.
for entry in "${global_matches[@]}"; do
  label=${entry%%|*}; dir=${entry#*|}
  if rm -rf -- "$dir" 2>/dev/null \
     || { chmod -R u+w "$dir" 2>/dev/null; rm -rf -- "$dir"; }; then
    printf "  %s✓%s removed %s cache (%s)\n" "$GREEN" "$RESET" "$label" "$dir"
    (( ++removed ))
  else
    printf "  %s✗%s failed   %s cache (%s)\n" "$RED" "$RESET" "$label" "$dir"
  fi
done

if [[ -n "$MISE_CACHE" ]]; then
  if mise cache clear >/dev/null 2>&1; then
    printf "  %s✓%s cleared mise cache\n" "$GREEN" "$RESET"
  else
    printf "  %s✗%s failed to clear mise cache\n" "$RED" "$RESET"
  fi
fi

if (( MISE_PRUNE )); then
  if mise prune --yes >/dev/null 2>&1 || mise prune >/dev/null 2>&1; then
    printf "  %s✓%s pruned unused mise tool versions\n" "$GREEN" "$RESET"
  else
    printf "  %s✗%s failed to prune mise tool versions\n" "$RED" "$RESET"
  fi
fi

# Rust toolchains: always an explicit per-toolchain choice (even with -y) —
# removing the wrong one costs a multi-GB re-download.
if (( ${#RUSTUP_TCS[@]} > 0 )); then
  printf "\n%sRust toolchains:%s\n" "$BOLD" "$RESET"
  for tc in "${RUSTUP_TCS[@]}"; do
    if [[ "$tc" == "$RUSTUP_DEFAULT" ]]; then
      printf "  %s-%s keeping %s %s(default)%s\n" "$DIM" "$RESET" "$tc" "$DIM" "$RESET"
      continue
    fi
    printf "  %sUninstall %s %s(%s)%s? %s[y/N]%s " \
      "$BOLD" "$tc" "$YELLOW" "$(dir_size "$RUSTUP_TC_DIR/$tc")" "$RESET" "$DIM" "$RESET"
    read -r reply
    case "$reply" in
      [yY]|[yY][eE][sS])
        if rustup toolchain uninstall "$tc" >/dev/null 2>&1; then
          printf "  %s✓%s uninstalled %s\n" "$GREEN" "$RESET" "$tc"
        else
          printf "  %s✗%s failed to uninstall %s\n" "$RED" "$RESET" "$tc"
        fi ;;
      *)
        printf "  %s-%s keeping %s\n" "$DIM" "$RESET" "$tc" ;;
    esac
  done
fi

total_dirs=$(( ${#matches[@]} + ${#global_matches[@]} ))
printf "\n%s✓%s done — %d/%d removed, %s%s%s reclaimed.\n" \
  "$GREEN" "$RESET" "$removed" "$total_dirs" "$GREEN" "$total_human" "$RESET"
