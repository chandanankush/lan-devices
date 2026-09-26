#!/usr/bin/env bash
set -euo pipefail

if ! command -v fswatch >/dev/null 2>&1; then
  echo "fswatch not found. Install with: brew install fswatch"
  exit 1
fi

echo "Watching for changes... (Ctrl+C to stop)"
fswatch -o App Models Services ViewModels Views | while read -r _; do
  clear
  date
  make build || true
done

