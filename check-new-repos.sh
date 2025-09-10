#!/usr/bin/env bash
# Discover *new* repos in your GitHub org, optionally clone them, and show quick git status.
# Usage:
#   bash check-new-repos.sh                # list new repos since last run
#   bash check-new-repos.sh --clone        # clone any new repos into ~/Projects
#   bash check-new-repos.sh --status-all   # 'git status -s' for every local repo in ~/Projects
#   bash check-new-repos.sh --reset-cache  # rebuild cache from current org state
set -euo pipefail

ORG="${ORG:-AustralianMycology}"          # override: ORG=MyOrg bash check-new-repos.sh
WORKDIR="${WORKDIR:-$HOME/Projects}"      # override: WORKDIR=/c/Users/Admin/Projects
CACHE="${CACHE:-$HOME/.am_repo_cache.txt}"

command -v gh >/dev/null || { echo "❌ 'gh' not found in PATH"; exit 1; }
mkdir -p "$WORKDIR"

# Flags
CLONE=0; STATUS_ALL=0; RESET=0
for a in "${@:-}"; do
  case "$a" in
    --clone) CLONE=1 ;;
    --status-all) STATUS_ALL=1 ;;
    --reset-cache) RESET=1 ;;
    *) echo "Unknown flag: $a"; exit 2 ;;
  esac
done

# Current repos (non-archived, non-fork)
TMP_CUR="$(mktemp)"
gh repo list "$ORG" --limit 500 --json name,isFork,archived \
  --jq '.[] | select(.archived==false and .isFork==false) | .name' \
  | sort -u > "$TMP_CUR"
COUNT_CUR=$(wc -l < "$TMP_CUR" | tr -d ' ')
echo "🏷️  Org: $ORG | Active repos: $COUNT_CUR"

# Init cache on first run / reset
if [[ ! -f "$CACHE" || $RESET -eq 1 ]]; then
  cp "$TMP_CUR" "$CACHE"
  echo "🧰 Cache initialized at $CACHE"
  echo "No 'new' repos to report on first run."
fi

# Compare
TMP_NEW="$(mktemp)"
comm -13 "$CACHE" "$TMP_CUR" > "$TMP_NEW" || true
NEW_COUNT=$(wc -l < "$TMP_NEW" | tr -d ' ')
if [[ $NEW_COUNT -gt 0 ]]; then
  echo "🆕 New repos since last check: $NEW_COUNT"
  cat "$TMP_NEW"
else
  echo "✅ No new repos since last check."
fi

# Clone new ones
if [[ $CLONE -eq 1 && $NEW_COUNT -gt 0 ]]; then
  echo "📥 Cloning into $WORKDIR ..."
  while read -r R; do
    [[ -z "$R" ]] && continue
    TARGET="$WORKDIR/$R"
    if [[ -d "$TARGET/.git" ]]; then
      echo "↩️  Already cloned: $R"
    else
      git clone "https://github.com/$ORG/$R.git" "$TARGET"
    fi
  done < "$TMP_NEW"
fi

# Optional status of all local repos
if [[ $STATUS_ALL -eq 1 ]]; then
  echo "🔎 git status (short) for repos in $WORKDIR:"
  find "$WORKDIR" -maxdepth 2 -type d -name ".git" | while read -r g; do
    REPO_DIR="$(dirname "$g")"; NAME="$(basename "$REPO_DIR")"
    echo "------------------------------"
    echo "📂 $NAME"
    git -C "$REPO_DIR" remote -v | head -n1 || true
    git -C "$REPO_DIR" status -s || true
  done
fi

# Update cache and exit code
cp "$TMP_CUR" "$CACHE"
echo "📝 Cache updated."
[[ $NEW_COUNT -gt 0 ]] && exit 10 || exit 0
