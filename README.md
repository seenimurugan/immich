# immich

Self-hosted Google Photos replacement — Immich photo server on homelab k3s.  
Helm chart + custom Postgres (pgvector/vectorchord) + backup CronJob.

## Depends on

- **cluster-setup** — `homelab` namespace, Tailscale ingress controller, storage-tier mover:  
  [`github.com/seenimurugan/homelab-cluster-setup`](https://github.com/seenimurugan/homelab-cluster-setup)

## Quick start

```bash
git clone https://github.com/seenimurugan/immich
cd immich

# 1. Set up your env
cp .env.example .env
$EDITOR .env   # fill in IMMICH_DB_PASSWORD, HDD paths, etc.

# 2. Deploy
./deploy.sh
```

`deploy.sh` is idempotent — safe to re-run. It adds the Helm repo, creates/updates
secrets, applies manifests via `envsubst`, and waits for rollout.

## Access

| | |
|---|---|
| **Tailnet URL** | https://immich.stoat-perch.ts.net |
| **LAN (no Tailscale)** | http://192.168.68.57:2283 |
| **Debug port-forward** | `kubectl -n homelab port-forward svc/immich-server 2283:2283` |
| **Cluster DNS (for CLI)** | http://immich-server.homelab.svc.cluster.local:2283 |

## Tear down

```bash
./undeploy.sh   # removes Helm release + Postgres workload + cronjob; preserves PVCs + HDD photos
```

## Docs

- [docs/README.md](docs/README.md) — app overview, access URLs
- [docs/USAGE.md](docs/USAGE.md) — initial setup, mobile app, family users, browse/search/share
- [docs/BULK-UPLOAD.md](docs/BULK-UPLOAD.md) — CLI uploads from HDD folders + Google Takeout
- [docs/UPGRADE.md](docs/UPGRADE.md) — version upgrades with DB migration safety
- [docs/MAINTENANCE.md](docs/MAINTENANCE.md) — restart, scale, backup, troubleshooting
- [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) — tech stack, why separate Postgres, storage-tier integration

Also rendered live at https://docs.stoat-perch.ts.net (sidebar → Immich).

---

## !! NON-PORTABLE BITS — read before deploying on a new machine/cluster !!

The following items are machine- or cluster-specific and require manual
intervention on every new deployment.

### 1. PVC UUID — `immich-upload-localpath-pvc` (HIGH PRIORITY)

The library PVC name `immich-upload-localpath-pvc` in `values/immich-values.yaml`
is specific to this cluster's local-path provisioner. On a new cluster, the PVC
will be created with a different UUID-based path.

**Steps on a new cluster:**

```bash
# Option A — let Helm create a fresh PVC (recommended for a clean install)
# 1. Remove the existingClaim line from values/immich-values.yaml (or comment it out)
# 2. Deploy: ./deploy.sh
# 3. Discover the new PVC and PV:
kubectl get pvc -n homelab | grep immich
kubectl get pv | grep immich-upload
# 4. Note the PV name/path, update IMMICH_UPLOAD_PV_PATH in .env
# 5. If you want to reuse the hardcoded PVC name, patch the PVC name and re-add existingClaim

# Option B — reuse existing PVC from a migrated cluster
# 1. Export PVC yaml from old cluster, apply to new cluster
# 2. Set existingClaim in values/immich-values.yaml to the new PVC name
```

### 2. HDD paths (machine-specific)

| Variable | Default | What it points to |
|---|---|---|
| `HOMELAB_HDD_PATH` | `/Volumes/Seeni's HDD` | Primary HFS+ HDD — Immich photo library + Jellyfin RO mount |
| `HOMELAB_TIER_HDD_PATH` | `/Volumes/homelab-hdd` | Tier HDD — tiered symlink targets + backup destination |

On a new Mac, HDDs may mount under different volume names. Update `.env` to match.

**Pre-create directories on the HDD before first deploy:**

```bash
# For backup-cronjob.yaml to work:
mkdir -p "${HOMELAB_TIER_HDD_PATH}/backups/postgres"
mkdir -p "${HOMELAB_TIER_HDD_PATH}/backups/library"

# For the tier HDD mount in immich-values.yaml:
mkdir -p "${HOMELAB_TIER_HDD_PATH}/immich-library"
```

### 3. Storage-tier symlinks

Photos >2 GiB are moved to `${HOMELAB_TIER_HDD_PATH}/immich-library/` by the
tier-mover CronJob and replaced with symlinks in the SSD library PVC. On a new
cluster you must:

1. Deploy cluster-setup first (sets up the tier-mover CronJob and `tier-now.sh`).
2. Ensure `${HOMELAB_TIER_HDD_PATH}/immich-library/` exists and is populated
   (either by copying from the old HDD or by re-running `tier-now.sh`).
3. The server pod must have the `/data-hdd` mount active (configured in
   `values/immich-values.yaml` under `server.persistence.hdd`) before Immich
   can serve tiered photos — broken symlinks cause blank images in the web UI.

Tier-mover docs and `tier-now.sh`:
[github.com/seenimurugan/homelab-cluster-setup](https://github.com/seenimurugan/homelab-cluster-setup)

### 4. Postgres DB is NOT on the HDD

The `immich-postgres-pvc` uses `local-path` storageClass (VM ext4 inside OrbStack).
**This data is lost if you reset the OrbStack VM** (`orbctl reset`).

Protect it:
- Run the backup CronJob manually before any destructive operations:  
  `kubectl create job --from=cronjob/immich-backup immich-backup-manual -n homelab`
- Restore from backup using `gunzip -c backup.sql.zst | kubectl exec -i ... psql`
- See [docs/MAINTENANCE.md](docs/MAINTENANCE.md) for full procedure.

### 5. Tailscale ingress hostname

`immich.stoat-perch.ts.net` is specific to this Tailnet. The Tailscale Ingress
resource lives in the cluster-setup repo — no Ingress manifest is in this repo.
On a new Tailnet, update the Ingress hostname in cluster-setup.

### 6. OrbStack HDD mount fd limit

Fresh hostPath PVs on external HDDs can hit `ENFILE (too many open files)` on
first mount in OrbStack. If this happens:

```bash
orbctl stop && orbctl start
# Wait for node Ready, then redeploy
```

The `hostPathType: ""` setting in `photos-readonly-pv.yaml` and the HDD mounts
in `values/immich-values.yaml` is intentional — using `DirectoryOrCreate`
triggers the fd limit bug. Do not change it.
