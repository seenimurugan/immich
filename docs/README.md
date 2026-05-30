# Immich — photo server

[Immich](https://immich.app) is a self-hosted Google Photos replacement with AI face recognition, smart search, and mobile auto-backup.

## Access

| Where | URL |
|---|---|
| **iPhone / family on Tailscale** | https://immich.stoat-perch.ts.net |
| **This Mac (browser, localhost)** | http://localhost:2283 |
| **LAN devices (without Tailscale)** | http://192.168.68.57:2283 |
| **This Mac (cluster DNS — most reliable, used by CLI)** | http://immich-server.homelab.svc.cluster.local:2283 |

## Detailed docs

- [📋 USAGE](USAGE.md) — initial setup, mobile app, family users, browse/search/share
- [📤 BULK-UPLOAD](BULK-UPLOAD.md) — CLI uploads from HDD folders + Google Takeout
- [⬆️ UPGRADE](UPGRADE.md) — version upgrades with DB migration safety
- [🛠 MAINTENANCE](MAINTENANCE.md) — restart, scale, backup, troubleshooting
- [🏛 ARCHITECTURE](ARCHITECTURE.md) — tech stack, why separate Postgres, source code locations
