#!/usr/bin/env bash
# Build a zip of data/ for GitHub Releases (not for committing to the repo).
# GitHub warns above ~100MB per file; use Releases or split/LFS for huge corpora.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${ROOT}/AutomationForExoskeleton_data.zip"

cd "$ROOT"
if [[ ! -d data ]]; then
  echo "No data/ folder at ${ROOT}; nothing to zip." >&2
  exit 1
fi

rm -f "$OUT"
zip -r -q "$OUT" data -x "*.DS_Store" -x "**/.DS_Store"
echo "Created: $OUT"
ls -lh "$OUT"
