#!/bin/zsh
# Polls Immich job queues; exits 0 the moment all waiting+active counts hit 0.
# Optionally scales ML back to --replicas=1 and sends a macOS notification.
#
# Usage:
#   ~/homelab/immich-wait-jobs-drained.sh             # just wait, then notify
#   ~/homelab/immich-wait-jobs-drained.sh --scale     # also scale ML to 1
#
# Run in background:  nohup ~/homelab/immich-wait-jobs-drained.sh --scale > ~/homelab/upload-logs/jobs-watch.log 2>&1 &

set -u
INTERVAL=${INTERVAL:-60}
API_URL="http://immich-server.homelab.svc.cluster.local:2283/api"
KEY=$(awk '/^key:/{print $2}' ~/.config/immich/auth.yml)
SCALE=0
[[ "${1:-}" == "--scale" ]] && SCALE=1

start=$(date +%s)
while :; do
  total=$(curl -fsS -H "x-api-key: $KEY" "$API_URL/jobs" \
    | python3 -c 'import json,sys; d=json.load(sys.stdin); print(sum(v["jobCounts"]["waiting"]+v["jobCounts"]["active"] for v in d.values()))' \
    2>/dev/null)
  if [[ -z "$total" ]]; then
    echo "$(date '+%H:%M:%S') API error, retrying..."
  else
    echo "$(date '+%H:%M:%S') pending=$total"
    [[ "$total" -eq 0 ]] && break
  fi
  sleep "$INTERVAL"
done

elapsed=$(( $(date +%s) - start ))
mins=$(( elapsed / 60 ))
echo "All Immich queues drained after ${mins}m"

if [[ "$SCALE" -eq 1 ]]; then
  kubectl scale deployment immich-machine-learning -n homelab --replicas=1
  echo "Scaled immich-machine-learning to 1"
fi

osascript -e "display notification \"Immich queues drained (${mins}m). ML scaled to 1.\" with title \"Immich\"" 2>/dev/null || true
