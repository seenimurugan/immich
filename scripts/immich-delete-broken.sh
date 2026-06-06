#!/bin/zsh
# Bulk delete assets listed in /tmp/immich-broken-assets.txt
# Reads the IDs (first tab-separated column) and calls DELETE /assets in batches of 100.

set -u
KEY=$(awk '/^key:/{print $2}' ~/.config/immich/auth.yml)
API="http://immich-server.homelab.svc.cluster.local:2283/api"
LIST=${1:-/tmp/immich-broken-assets.txt}

[[ -s "$LIST" ]] || { echo "No file or empty: $LIST"; exit 1; }
total=$(wc -l < "$LIST" | tr -d ' ')
echo "About to delete $total assets from $LIST"
read "ok?Type YES to confirm: "
[[ "$ok" == "YES" ]] || { echo "Aborted."; exit 1; }

ids=()
deleted=0
while IFS=$'\t' read -r id _; do
  ids+=("$id")
  if (( ${#ids[@]} >= 100 )); then
    payload=$(printf '"%s",' "${ids[@]}" | sed 's/,$//')
    curl -fsS -X DELETE -H "x-api-key: $KEY" -H "Content-Type: application/json" \
      "$API/assets" -d "{\"ids\":[$payload],\"force\":true}" >/dev/null
    deleted=$((deleted + ${#ids[@]}))
    echo "deleted $deleted / $total"
    ids=()
  fi
done < "$LIST"

if (( ${#ids[@]} > 0 )); then
  payload=$(printf '"%s",' "${ids[@]}" | sed 's/,$//')
  curl -fsS -X DELETE -H "x-api-key: $KEY" -H "Content-Type: application/json" \
    "$API/assets" -d "{\"ids\":[$payload],\"force\":true}" >/dev/null
  deleted=$((deleted + ${#ids[@]}))
fi

echo "Done. Deleted $deleted assets."
