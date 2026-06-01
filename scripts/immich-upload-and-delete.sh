#!/bin/zsh
# Upload a folder (or multiple) to Immich, verify no failures, then rm -rf the source.
#
# Usage:
#   ~/homelab/immich-upload-and-delete.sh "/path/to/folder1" ["/path/to/folder2" ...]
#
# For each path:
#   1. Run immich upload --recursive --concurrency 4 (cluster DNS, already-logged-in CLI)
#   2. Parse the log:
#        - if "Failed to verify" lines present  → KEEP source, print warning
#        - if "Found N new files and M duplicates" + 0 failed
#          AND the final summary lines look clean → rm -rf source
#   3. Move on
#
# Sources are NEVER deleted if any upload failure occurred. Logs go to
# ~/homelab/upload-logs/upload-<timestamp>-<slug>.log

set -u
LOGDIR=~/homelab/upload-logs
mkdir -p "$LOGDIR"

if (( $# == 0 )); then
  echo "Usage: $0 <folder> [<folder> ...]" >&2
  exit 1
fi

for SRC in "$@"; do
  if [[ ! -d "$SRC" ]]; then
    echo "SKIP (not a directory): $SRC"
    continue
  fi

  slug=$(echo "$SRC" | tr -c '[:alnum:]' '-' | sed -E 's/-+/-/g; s/^-+|-+$//g' | cut -c1-60)
  ts=$(date +%Y%m%d-%H%M%S)
  LOG="$LOGDIR/upload-$ts-$slug.log"

  echo "=== $SRC ==="
  echo "log: $LOG"

  immich upload --recursive --concurrency 4 "$SRC" 2>&1 | tee "$LOG"

  # Decide: any failure means keep source.
  if grep -q "Failed to verify" "$LOG"; then
    echo "❌ KEEPING $SRC — upload had failed-to-verify files. See $LOG"
    continue
  fi
  if grep -qE "(Error:|throw |unhandledRejection|ENOENT|ENXIO)" "$LOG"; then
    echo "❌ KEEPING $SRC — upload had errors. See $LOG"
    continue
  fi
  if ! grep -qE "(All assets were already uploaded|Successfully uploaded|new files and .* duplicates)" "$LOG"; then
    echo "❌ KEEPING $SRC — could not confirm upload success. See $LOG"
    continue
  fi

  echo "✅ Upload clean — deleting source"
  rm -rf "$SRC"
  if [[ -e "$SRC" ]]; then
    echo "⚠️  delete partial (perms?) — manual cleanup needed: $SRC"
  else
    echo "🗑  deleted: $SRC"
  fi
done
