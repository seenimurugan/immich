#!/bin/zsh
# Find Immich assets whose thumbnail generation failed (typically corrupt uploads).
# Lists candidate asset IDs and originalPaths to /tmp/immich-broken-assets.txt
# Does NOT delete — review the list, then run immich-delete-broken.sh.
#
# Uses the metadata search endpoint paginated by page size 1000.

set -u
KEY=$(awk '/^key:/{print $2}' ~/.config/immich/auth.yml)
API="http://immich-server.homelab.svc.cluster.local:2283/api"
OUT=/tmp/immich-broken-assets.txt
: > "$OUT"

page=1
total=0
broken=0
while :; do
  resp=$(curl -fsS -H "x-api-key: $KEY" -H "Content-Type: application/json" \
    -X POST "$API/search/metadata" \
    -d "{\"page\":$page,\"size\":1000}")
  items=$(echo "$resp" | python3 -c '
import json,sys
d=json.load(sys.stdin)
items=d.get("assets",{}).get("items",[])
for a in items:
    # broken indicators: no thumbhash, or originalFileName empty, or fileCreatedAt null
    if not a.get("thumbhash") or not a.get("originalPath"):
        print(a["id"], a.get("originalPath",""), sep="\t")
print("__COUNT__", len(items), sep="\t")
')
  count=$(echo "$items" | awk -F'\t' '/^__COUNT__/{print $2}')
  echo "$items" | grep -v '^__COUNT__' >> "$OUT"
  total=$((total + count))
  echo "page $page: scanned $count, total $total"
  [[ "$count" -lt 1000 ]] && break
  page=$((page + 1))
done

broken=$(wc -l < "$OUT" | tr -d ' ')
echo
echo "Scanned $total assets total"
echo "Found $broken candidate broken assets → $OUT"
echo
echo "Review with: head $OUT"
echo "Then delete with: ~/homelab/immich-delete-broken.sh"
