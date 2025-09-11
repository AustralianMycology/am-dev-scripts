#!/usr/bin/env bash
# Run the same npm/pnpm/yarn script across all Node projects under a root.
# Usage: bash run-node-script.sh <script-name> [root]
set -euo pipefail

SCRIPT="${1:-}"
ROOT="${2:-$HOME/Projects}"
[[ -z "$SCRIPT" ]] && { echo "Usage: $0 <script-name> [root]"; exit 2; }

ok=0; fail=0
echo "🔎 Searching for package.json under: $ROOT"
find "$ROOT" -maxdepth 2 -type f -name package.json | while read -r pkg; do
  dir="$(dirname "$pkg")"
  pushd "$dir" >/dev/null

  mgr="npm"
  [[ -f pnpm-lock.yaml ]] && mgr="pnpm"
  [[ -f yarn.lock ]] && mgr="yarn"

  has_script="$(node -p "try{(require('./package.json').scripts||{})['$SCRIPT']?'yes':'no'}catch(e){'no'}")"
  if [[ "$has_script" != "yes" ]]; then
    echo "⏭  $dir — no '$SCRIPT' script (skip)"
    popd >/dev/null
    continue
  fi

  echo "▶  $dir — $mgr run $SCRIPT"
  if { [[ "$mgr" == "npm"  ]] && npm run -s "$SCRIPT"; } \
  || { [[ "$mgr" == "pnpm" ]] && pnpm run -s "$SCRIPT"; } \
  || { [[ "$mgr" == "yarn" ]] && yarn "$SCRIPT"; }; then
    echo "✅  $dir"
    ((ok++)) || true
  else
    echo "❌  $dir"
    ((fail++)) || true
  fi

  popd >/dev/null
done

echo -e "\nSummary: $ok ok, $fail failed"
[[ $fail -gt 0 ]] && exit 1 || exit 0
