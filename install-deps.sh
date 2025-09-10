#!/usr/bin/env bash
set -euo pipefail
ROOT="${1:-$HOME/Projects}"

echo "🔎 Scanning for Node projects under: $ROOT"
find "$ROOT" -maxdepth 2 -type f -name package.json | while read -r pkg; do
  dir="$(dirname "$pkg")"
  echo -e "\n📦 $dir"
  if [[ -f "$dir/pnpm-lock.yaml" ]]; then
    echo "→ pnpm install (frozen lockfile if possible)"
    (cd "$dir" && pnpm install --frozen-lockfile || pnpm install)
  elif [[ -f "$dir/package-lock.json" ]]; then
    echo "→ npm ci"
    (cd "$dir" && npm ci || npm install)
  elif [[ -f "$dir/yarn.lock" ]]; then
    echo "→ yarn install"
    (cd "$dir" && yarn install || corepack yarn install)
  else
    echo "→ no lockfile; defaulting to pnpm install"
    (cd "$dir" && pnpm install)
  fi
done
echo -e "\n✅ Done."
