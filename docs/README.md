# Immich — photo server

[Immich](https://immich.app) is a self-hosted Google Photos replacement with AI face recognition, smart search, and mobile auto-backup. Off-the-shelf app via Helm chart — no custom code.

Source: `/Users/nila/Developer/apps/immich/`

**On this page:** [Access](#access) · [Initial credentials](#initial-credentials) · [What it does](#what-it-does) · [Stack & framework](#stack--framework) · [Storage](#storage) · [See also](#see-also) · [File reference](#file-reference)

---

## Access

| Where | URL |
|---|---|
| **iPhone / family on Tailscale** | https://immich.stoat-perch.ts.net |
| **This Mac (browser, localhost)** | http://localhost:2283 *(only when the port-forward is running)* |
| **LAN devices (without Tailscale)** | http://192.168.68.57:2283 *(same condition)* |
| **Cluster DNS** (other pods / Mac shell) | http://immich-server.homelab.svc.cluster.local:2283 |
| **Ad-hoc debug port-forward** | `kubectl -n homelab port-forward svc/immich-server 2283:2283` |

---

## Initial credentials

Immich is set up on first visit via the web wizard — create an admin account with any username and password. There is no pre-seeded default. See [USAGE → Initial setup](USAGE.md#initial-setup) for the walkthrough.

---

## What it does

- Mobile auto-backup — Immich mobile app silently backs up new photos/videos.
- AI face recognition and smart search (powered by `immich-machine-learning` + pgvector).
- Family sharing — each person has their own account; albums can be shared.
- Web and mobile (iOS/Android) apps with timeline, album, map, and explore views.
- Large-file tiering: files >2 GB are moved to the external HDD by the Storage Console CronJob.

---

## Stack & framework

| Layer | Tech |
|---|---|
| App | Immich (NestJS + Python ML) — official Docker images |
| Components | `immich-server`, `immich-machine-learning`, `valkey` (Redis fork), `immich-postgres` |
| Deploy | Helm chart `immich/immich 0.11.1` |
| Postgres | `ghcr.io/immich-app/postgres:17-vectorchord0.4.3-pgvector0.8.0` (custom extensions for vector search) |
| Ingress | Tailscale Ingress (HTTPS) + LAN via launchd port-forward |

---

## Storage

| PVC / Volume | Purpose |
|---|---|
| `immich-library-pv` (hostPath → HDD) | Photo + video library (large files tiered here from the Mac) |
| `immich-postgres-pvc` (local-path, ext4) | PostgreSQL data dir — must be on ext4 (not exFAT) |
| `immich-model-cache-pvc` (local-path) | Machine learning model cache |

---

## See also

- [Usage guide](USAGE.md) — initial setup, mobile app, family users, browse/search/share
- [Bulk upload](BULK-UPLOAD.md) — CLI uploads from HDD folders + Google Takeout
- [Upgrade guide](UPGRADE.md) — version upgrades with DB migration safety
- [Maintenance](MAINTENANCE.md) — restart, scale, backup, troubleshooting
- [Architecture](ARCHITECTURE.md) — tech stack, why separate Postgres, component topology

## File reference

| File | Purpose |
|---|---|
| `/Users/nila/Developer/apps/immich/k8s/postgres.yaml` | Immich-specific Postgres StatefulSet + Secret + PVC |
| `/Users/nila/Developer/apps/immich/k8s/backup-cronjob.yaml` | Periodic `pg_dump` to HDD (managed by Storage Console) |
| `/Users/nila/Developer/apps/immich/values/` | Helm values file (chart config) |
