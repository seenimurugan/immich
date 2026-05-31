# Immich — Deployment & Maintenance

**On this page:** [Deploy / redeploy](#deploy--redeploy) · [Common operations](#common-operations) · [Storage](#storage) · [Backup](#backup) · [Upgrade](#upgrade) · [Troubleshooting](#troubleshooting)

## Deploy / redeploy

Immich runs via the official Helm chart (`immich/immich`), with our own Postgres StatefulSet alongside (the chart doesn't bundle Postgres).

```bash
# Postgres (one-time)
kubectl apply -f ~/homelab/immich-postgres.yaml

# Immich (from local chart copy)
helm upgrade immich /tmp/immich --namespace homelab -f ~/homelab/immich-values.yaml
```

For a fresh chart: `helm pull immich/immich` (chart 0.12.0 may 404 — fall back to 0.11.1).

## Common operations

### Restart
```bash
kubectl rollout restart deployment/immich-server -n homelab
kubectl rollout restart deployment/immich-machine-learning -n homelab
```

### Scale machine-learning pods (for faster post-upload processing)
```bash
# After a big upload finishes, scale up to crunch face/object recognition:
kubectl scale deployment immich-machine-learning -n homelab --replicas=3

# When queue is empty, scale back:
kubectl scale deployment immich-machine-learning -n homelab --replicas=1
```
⚠️ Scale up only AFTER uploads finish — not during. Concurrent upload + 3 ML pods overload the VM.

### Trigger background jobs manually
Web UI → Administration → Jobs → click ▶ on any queue (Thumbnail Generation, Face Recognition, Smart Search, Duplicate Detection).

### Logs
```bash
kubectl logs -n homelab deployment/immich-server --tail=50 -f
kubectl logs -n homelab deployment/immich-machine-learning --tail=50 -f
```

### Pod resource usage
```bash
kubectl top pod -n homelab | grep immich
```

## Storage

Two PVCs:

| PVC | Backing | Purpose |
|---|---|---|
| `immich-upload-pvc` (1 Ti) | hostPath → `/Volumes/Seeni's HDD/immich/upload/` | Actual photo files + thumbs + encoded video |
| `immich-postgres-pvc` (20 Gi) | local-path (VM ext4) | Postgres DB with metadata, albums, faces |

⚠️ Postgres is **on local-path NOT the HDD** because exFAT can't handle Postgres correctly. **The DB is lost if you `orbctl reset` the OrbStack VM.** Run the weekly backup script.

## Backup

Weekly automated via `~/homelab/backup-immich.sh` (launchd, Sundays 03:00). Backs up photo files + Postgres dump.

Manual DB dump:
```bash
PG_POD=$(kubectl get pod -n homelab -l app=immich-postgres -o jsonpath='{.items[0].metadata.name}')
kubectl exec -n homelab "$PG_POD" -- pg_dump -U immich -d immich --no-owner --clean --if-exists \
  | gzip > "/Volumes/Seeni's HDD/immich/manual-backup-$(date +%Y%m%d-%H%M%S).sql.gz"
```

## Upgrade

See [UPGRADE.md](UPGRADE.md) — pre-flight checks, DB backup, image tag bump, migration watch, rollback.

## Troubleshooting

### Upload CLI fails with "fetch failed"
kubectl port-forward dying under load. Fix once: edit `~/.config/immich/auth.yml` to use cluster DNS:
```yaml
url: http://immich-server.homelab.svc.cluster.local:2283/api
```

### Immich pod CrashLoopBackOff
Usually probe timeouts (mitigated by relaxed probes now). Check logs:
```bash
kubectl logs -n homelab deployment/immich-server --previous --tail=30
```

### Localhost returns HTTP 000
Port-forward died:
```bash
~/homelab/refresh-localhost.sh
```

### Machine-learning pod restarting
Usually OOM. Bump memory:
```bash
kubectl set resources deployment/immich-machine-learning -n homelab --limits=memory=8Gi
```

### Photos uploaded but not appearing in timeline
Server is processing thumbnails/metadata. Check Administration → Jobs. Wait until queues hit 0.

### "Too many open files in system" on the HDD
OrbStack exFAT passthrough wedged. Fix:
```bash
orbctl stop && orbctl start
```
