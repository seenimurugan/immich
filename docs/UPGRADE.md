# Immich upgrade runbook — v2.6.3 → v2.7.5

Goal: bring the cluster from Immich v2.6.3 to v2.7.5, safely.

**Current state (Pinned to this homelab):**
- Helm chart: `immich/immich 0.11.1` (chart appVersion is v2.6.3)
- The **chart maintainers haven't released a v2.7.x chart yet** — chart 0.12.0 still has appVersion v2.6.3. So we can't get to v2.7.x via a chart upgrade.
- Strategy: **override just the container image tag** to v2.7.5, keep the chart at 0.11.1.
- We also have an unhealthy helm history (revisions 2-3 `failed` from earlier conflicts) — to bypass helm entirely, we use `kubectl set image`. The pods get the new image; helm release state stays as-is. We're already drifting from helm (probes were patched directly), so this isn't a regression.

**Do this AFTER bulk uploads + dedup are done** — image change kills the immich-server pod and crashes any in-flight CLI upload.

**On this page:** [0. Pre-flight checks](#0-pre-flight-checks) · [1. Backup BEFORE upgrade (mandatory)](#1-backup-before-upgrade-mandatory) · [2. Check what target version is safe](#2-check-what-target-version-is-safe) · [3. Bump image tags (kubectl set image — simple, bypasses helm)](#3-bump-image-tags-kubectl-set-image--simple-bypasses-helm) · [4. Watch the migration](#4-watch-the-migration) · [5. Refresh port-forward (immich-server got recreated)](#5-refresh-port-forward-immich-server-got-recreated) · [6. Verify](#6-verify) · [7. If something goes wrong — rollback](#7-if-something-goes-wrong--rollback) · [8. Don't forget — keep snapshots in sync](#8-dont-forget--keep-snapshots-in-sync) · [Quick reference](#quick-reference)

---

## 0. Pre-flight checks

Open Immich web UI → **Administration → Jobs**. Confirm all queues are 0:
- Thumbnail Generation
- Face Recognition
- Smart Search
- Library Sync
- Duplicate Detection (any active jobs)

Then in terminal:

```bash
# Verify everything healthy
kubectl get pods -n homelab

# Verify no active immich CLI uploads
pgrep -af "immich upload" && echo "WAIT — uploads in flight" || echo "No active uploads — safe to proceed"

# Note current versions
kubectl get deploy immich-server -n homelab -o jsonpath='{.spec.template.spec.containers[0].image}'
echo ""
kubectl get deploy immich-machine-learning -n homelab -o jsonpath='{.spec.template.spec.containers[0].image}'
echo ""
helm list -n homelab
```

---

## 1. Backup BEFORE upgrade (mandatory)

```bash
# Postgres dump → HDD (in case the migration fails or corrupts something)
BACKUP_FILE="/Volumes/Seeni's HDD/immich/pre-upgrade-backup-$(date +%Y%m%d-%H%M%S).sql.gz"
PG_POD=$(kubectl get pod -n homelab -l app=immich-postgres -o jsonpath='{.items[0].metadata.name}')

kubectl exec -n homelab "$PG_POD" -- \
  pg_dump -U immich -d immich --no-owner --clean --if-exists \
  | gzip > "$BACKUP_FILE"

ls -lh "$BACKUP_FILE"
echo "Backup written to: $BACKUP_FILE"

# Snapshot current Helm values
helm get values immich -n homelab > ~/homelab/immich-values-pre-upgrade-$(date +%Y%m%d).yaml
```

If the upgrade goes wrong, restore Postgres with:
```bash
gunzip -c "$BACKUP_FILE" | kubectl exec -i -n homelab "$PG_POD" -- psql -U immich -d immich
```

---

## 2. Check what target version is safe

The immich chart `immich/immich` doesn't always have the latest app version. As of writing, chart 0.11.1 → app v2.6.3. Newer chart releases bump appVersion.

```bash
# Refresh and list available chart versions
helm repo update immich
helm search repo immich/immich --versions | head -10

# To pick a target: read the corresponding chart's appVersion column.
# Cross-reference with Immich's release notes:
#   https://github.com/immich-app/immich/releases
# Look especially for BREAKING CHANGES sections.
```

If the chart's released tarball gives 404 (we hit this before — chart 0.12.0 had a missing GitHub release artifact), fall back to downloading manually:

```bash
# Find a chart version that has a working tarball
CHART_VER="0.11.x"   # ← replace with desired version
curl -sL -o /tmp/immich-chart.tgz \
  "https://github.com/immich-app/immich-charts/releases/download/immich-$CHART_VER/immich-$CHART_VER.tgz"
[ -s /tmp/immich-chart.tgz ] && echo "Got chart tarball" || echo "Tarball missing on GitHub"
tar xzf /tmp/immich-chart.tgz -C /tmp
```

---

## 3. Bump image tags (kubectl set image — simple, bypasses helm)

```bash
TARGET=v2.7.5

# Server
kubectl set image deployment/immich-server \
  -n homelab \
  main=ghcr.io/immich-app/immich-server:$TARGET

# Machine learning
kubectl set image deployment/immich-machine-learning \
  -n homelab \
  main=ghcr.io/immich-app/immich-machine-learning:$TARGET
```

This triggers rolling restart of both deployments. Postgres + Valkey + Jellyfin are unchanged.

**Also update the persisted Helm values file** so future `helm upgrade` doesn't revert the image. Edit `~/homelab/immich-values.yaml`:

```yaml
controllers:
  main:
    containers:
      main:
        image:
          tag: v2.7.5

machine-learning:
  controllers:
    main:
      containers:
        main:
          image:
            tag: v2.7.5
```

(No `helm upgrade` needed right now — kubectl already changed the live state. The values file is for future helm runs only.)

---

## 4. Watch the migration

After helm upgrade kicks off:

```bash
# Watch pods come up (immich-server runs DB migrations on startup)
kubectl get pods -n homelab -w

# Tail server logs to see migration progress
kubectl logs -n homelab -l app.kubernetes.io/name=server --tail=50 -f
```

DB migrations on first start can take 10-30 min for 40k+ photos. The pod will be `0/1 Running` (failing readiness) during this — that's normal. Look for log lines like:
- `Running migration ...`
- `Database migrated successfully`
- `Immich Server is listening on http://[::1]:2283`

When you see "is listening" + no further errors → migration done.

---

## 5. Refresh port-forward (immich-server got recreated)

```bash
launchctl unload ~/Library/LaunchAgents/com.nila.homelab-localhost.plist
sleep 2
launchctl load ~/Library/LaunchAgents/com.nila.homelab-localhost.plist
sleep 5

curl -s http://localhost:2283/api/server/ping
# Expected: {"res":"pong"}
```

---

## 6. Verify

```bash
# Pod state
kubectl get pods -n homelab

# New version
kubectl get deploy immich-server -n homelab -o jsonpath='{.spec.template.spec.containers[0].image}'

# Web UI — should now show the new version, no "update available" badge
open http://localhost:2283

# Mobile app — log out and back in if needed
```

Sanity checks in the web UI:
- Photos still visible (timeline loads)
- Albums intact
- Faces still recognized
- Search works
- Admin → System → Version Check should be green

---

## 7. If something goes wrong — rollback

### Quick: roll the image back to v2.6.3

```bash
kubectl set image deployment/immich-server -n homelab main=ghcr.io/immich-app/immich-server:v2.6.3
kubectl set image deployment/immich-machine-learning -n homelab main=ghcr.io/immich-app/immich-machine-learning:v2.6.3
```

If v2.6.3 won't start because the DB schema is now at v2.7.5 (migration ran but failed app-side), do the **full restore** below.

### If DB migration corrupted data — full restore

```bash
# 1. Scale immich-server to 0 to stop it from writing
kubectl scale deployment immich-server -n homelab --replicas=0

# 2. Drop and recreate database
PG_POD=$(kubectl get pod -n homelab -l app=immich-postgres -o jsonpath='{.items[0].metadata.name}')
kubectl exec -n homelab "$PG_POD" -- psql -U immich -d postgres -c "DROP DATABASE immich;"
kubectl exec -n homelab "$PG_POD" -- psql -U immich -d postgres -c "CREATE DATABASE immich;"

# 3. Restore from the pre-upgrade dump
gunzip -c "/Volumes/Seeni's HDD/immich/pre-upgrade-backup-YYYYMMDD-HHMMSS.sql.gz" \
  | kubectl exec -i -n homelab "$PG_POD" -- psql -U immich -d immich

# 4. Pin image back to v2.6.3
kubectl set image deployment/immich-server -n homelab main=ghcr.io/immich-app/immich-server:v2.6.3

# 5. Scale server back up
kubectl scale deployment immich-server -n homelab --replicas=1
```

---

## 8. Don't forget — keep snapshots in sync

After the upgrade succeeds, copy the new live config back to docs:

```bash
cp ~/homelab/immich-values.yaml /Users/nila/Developer/agents/docs/homelab-k8s-setup/configs/immich-values.yaml
```

And update `session-state.md` and `command-log.md` in the docs folder if you want a record.

---

## Quick reference

| Action | Command |
|---|---|
| Backup DB | `kubectl exec -n homelab $PG_POD -- pg_dump -U immich -d immich --no-owner --clean --if-exists | gzip > backup.sql.gz` |
| Check current image | `kubectl get deploy immich-server -n homelab -o jsonpath='{.spec.template.spec.containers[0].image}'` |
| List chart versions | `helm search repo immich/immich --versions` |
| Upgrade (minimal) | `helm upgrade immich /tmp/immich -n homelab -f ~/homelab/immich-values.yaml` |
| Watch rollout | `kubectl rollout status deployment/immich-server -n homelab` |
| Check logs | `kubectl logs -n homelab -l app.kubernetes.io/name=server -f` |
| List helm revisions | `helm history immich -n homelab` |
| Rollback | `helm rollback immich <rev> -n homelab` |
| Restore DB | `gunzip -c backup.sql.gz | kubectl exec -i -n homelab $PG_POD -- psql -U immich -d immich` |
