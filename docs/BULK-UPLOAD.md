# Immich Bulk Upload — runbook

Self-serve guide for uploading photos to Immich from a folder, HDD, or Google Takeout zips. No coding agent required.

**On this page:** [One-time setup (per machine)](#one-time-setup-per-machine) · [Pause mobile auto-backup during bulk uploads](#pause-mobile-auto-backup-during-bulk-uploads) · [Scale ML pods AFTER upload, not before](#scale-ml-pods-after-upload-not-before) · [Basic upload (single folder)](#basic-upload-single-folder) · [Bulk upload from external HDD](#bulk-upload-from-external-hdd) · [Long-running uploads — run in background](#long-running-uploads--run-in-background) · [Google Takeout exports (zipped photos)](#google-takeout-exports-zipped-photos) · [Auto-create albums from folder names](#auto-create-albums-from-folder-names) · [After upload — watch ML jobs drain](#after-upload--watch-ml-jobs-drain) · [Duplicate detection (run AFTER bulk uploads)](#duplicate-detection-run-after-bulk-uploads) · [Verifying upload completeness, then deleting source](#verifying-upload-completeness-then-deleting-source) · [Upload + verify + delete (all-in-one)](#upload--verify--delete-all-in-one) · [Quick reference](#quick-reference) · [Troubleshooting](#troubleshooting)

---

## One-time setup (per machine)

```zsh
# 1. Install the CLI
npm install -g @immich/cli

# 2. Get an API key (browser):
#    open http://localhost:2283  ← Immich web UI (via launchd port-forward)
#    Account Settings → API Keys → "+ New API Key" → Name: "cli" → Create
#    COPY THE KEY (only shown once)

# 3. Login the CLI — use the CLUSTER DNS URL, not localhost.
#    The cluster DNS bypasses kubectl port-forward, so uploads don't
#    fail when the port-forward dies under load.
#    (key never echoes to screen, never lands in shell history)
read -s "IMMICH_KEY?Immich API Key: "; echo
immich login http://immich-server.homelab.svc.cluster.local:2283 "$IMMICH_KEY"
unset IMMICH_KEY
```

The CLI caches your auth in `~/.config/immich/auth.yml`. You don't need to re-login on this machine.

---

## Pause mobile auto-backup during bulk uploads

Before kicking off a big CLI upload, **pause Immich auto-backup on every phone in the household** — yours and every kid/family member's. Each phone is its own parallel writer.

- Your CLI upload writes to `/data/upload` (exFAT HDD via OrbStack FUSE bridge)
- Each phone simultaneously POSTs photos which also write to `/data/upload`
- 3+ concurrent uploaders blow past the FUSE bridge's system-wide file-descriptor budget within seconds
- Result: `ENFILE: file table overflow, mkdir '/data/upload/...'` → 500 errors from every uploader, FUSE bridge wedges until OrbStack is bounced

Phone-side queues are safe to pause: when you re-enable auto-backup later, each phone's Immich app catches up its own queue incrementally. No photos are lost — just deferred.

Symptoms when this happens:
```
Failed to upload asset, error: Internal Server Error, statusCode: 500
```
And inside the pod:
```
mkdir: cannot create directory '/data/upload/...': Too many open files in system
```

**Pause mobile backup, run your CLI upload, then re-enable mobile backup.** The mobile app catches up incrementally afterwards.

If the bridge already wedged, recovery is:
```bash
kubectl scale deployment/immich-server deployment/immich-machine-learning -n homelab --replicas=0
orbctl stop && orbctl start
# Wait for node Ready
kubectl scale deployment/immich-server deployment/immich-machine-learning -n homelab --replicas=1
# Verify: pod can mkdir on /data/upload (no ENFILE)
```

---

## Scale ML pods AFTER upload, not before

ML jobs (face recognition, smart search, thumbnails) queue as photos arrive. More pods = parallel processing.

**But** scaling ML up *during* the upload can overload the OrbStack VM. We saw the k3s node flip `NotReady` mid-upload because:
- Active CLI upload hashing 40k files + transferring (heavy I/O)
- 3× ML pods × 6 GB limit = up to 18 GB
- + immich-server (8 GB), Postgres (4 GB), Jellyfin (12 GB), Tailscale operator + proxies
- Total potential demand exceeded headroom on the 40 GB VM → kubelet missed heartbeats → node NotReady → port-forwards died

Recommended order:
```bash
# 1. Leave ML at 1 replica during upload (default)
kubectl get deployment immich-machine-learning -n homelab

# 2. Run the upload (see below). ML jobs queue up in the background.

# 3. AFTER upload finishes, scale up to drain the queued ML jobs faster
kubectl scale deployment immich-machine-learning -n homelab --replicas=3

# 4. Watch web UI → Administration → Jobs until all queues are 0
# 5. Scale back to save memory
kubectl scale deployment immich-machine-learning -n homelab --replicas=1
```

---

## Basic upload (single folder)

```bash
immich upload --recursive --concurrency 8 "/path/to/photos"
```

- `--recursive` — **mandatory if there are subfolders.** Default is non-recursive (top level only).
- `--concurrency 8` — 8 files in parallel. Default is 9 in current CLI versions but lower (4-8) for USB HDDs is safer.

---

## Bulk upload from external HDD

⚠️ **ALWAYS include `--recursive`** — without it, the CLI only scans top-level files and silently skips subfolders (prints `No files found, exiting` if the top level has none).

```bash
HDD="/Volumes/Seeni's HDD"

immich upload --recursive --concurrency 8 \
  "$HDD/Pictures" \
  "$HDD/Phone backups" \
  "$HDD/Family photos"
```

Multiple folders in one command. CLI hashes everything first, uploads after.

**Already-uploaded files are skipped automatically** (server-side hash check). Re-running the same command is safe and resumable.

**Concurrency suggestion:** start with `8` on USB HDDs. Bumping to 16 risks overloading the OrbStack VM (we saw the node go NotReady at 16 + 3 ML pods during a large run).

---

## Long-running uploads — run in background

For uploads that'll take hours:

```bash
mkdir -p ~/homelab/upload-logs
LOG=~/homelab/upload-logs/upload-$(date +%Y%m%d-%H%M%S).log

nohup immich upload --concurrency 16 \
  "/Volumes/Seeni's HDD/Pictures" \
  > "$LOG" 2>&1 &

echo "PID: $!"
echo "Log: $LOG"
```

Monitor:
```bash
tail -f "$LOG"
```

Or watch Immich storage grow:
```bash
du -sh "/Volumes/Seeni's HDD/immich/upload/library/"
```

Stop an in-flight upload:
```bash
pkill -f "immich upload"
# Resume with the same command — already-uploaded files will be skipped.
```

---

## Google Takeout exports (zipped photos)

Google Takeout produces `.zip` files with `.json` sidecars (date, location, album metadata). Immich reads the sidecars if uploaded alongside the photos.

```bash
# 1. Unzip into a staging folder
mkdir -p ~/Pictures/_unzipped
for z in ~/Pictures/*.zip; do
  target=~/Pictures/_unzipped/$(basename "$z" .zip)
  mkdir -p "$target"
  unzip -oq "$z" -d "$target"
done

# 2. Upload everything
immich upload --concurrency 16 --recursive ~/Pictures/_unzipped
```

---

## Auto-create albums from folder names

```bash
immich upload --concurrency 16 --album --recursive "/path/to/photos"
```

Each top-level folder becomes an album. Great for "Family Trip Italy 2024" style organisation.

---

## After upload — watch ML jobs drain

**Automated (recommended):** run the watcher script — it polls the Immich API every 60s, scales ML back to 1 once all queues hit 0, and posts a macOS notification. Survives terminal close.

```bash
nohup ~/homelab/immich-wait-jobs-drained.sh --scale \
  > ~/homelab/upload-logs/jobs-watch.log 2>&1 &
disown
tail -f ~/homelab/upload-logs/jobs-watch.log   # optional live view
```

Script is at `/Users/nila/homelab/immich-wait-jobs-drained.sh`. Without `--scale` it just waits and notifies. Override poll interval with `INTERVAL=30 ...`.

**Manual:** open http://localhost:2283 → **Administration** → **Jobs**. Wait until all queues (Thumbnail / Face Recognition / Smart Search / Library / Storage Template) hit 0.

---

## Duplicate detection (run AFTER bulk uploads)

Immich auto-dedupes byte-identical files (same hash, different name). For visually-similar near-duplicates (same photo at different resolutions or compression):

1. Web UI → **Administration → Jobs → Duplicate Detection → Run**
2. Wait for it to finish
3. Your account → **Duplicates** page → side-by-side comparisons → pick which to keep

Immich never auto-deletes — you decide.

---

## Verifying upload completeness, then deleting source

Don't delete source folders blindly. Verify first:

```bash
# 1. Count source files
find "/path/to/source" -type f \
  \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.heic" \
     -o -iname "*.png" -o -iname "*.mp4" -o -iname "*.mov" \) | wc -l

# 2. Compare with Immich asset count in web UI (top-right counter)

# 3. If close enough (dedup may reduce the Immich count), delete source:
rm -rf "/path/to/source"
```

**Strongly recommended:** ensure your weekly backup is running (see `backup-immich.sh`) before deleting any originals — your primary HDD is a single point of failure.

---

## Upload + verify + delete (all-in-one)

`immich-upload-and-delete.sh` is a safe wrapper that uploads one or more source folders, verifies the result, and **only deletes the source if every file was confirmed uploaded** (zero failures or verify errors).

### How it works

1. Runs `immich upload --recursive --concurrency 4 <source>` and captures the full log.
2. Scans the log for failure signals:
   - `Failed to verify` lines → **keep source**
   - `Error:` / `throw ` / `unhandledRejection` / `ENOENT` / `ENXIO` → **keep source**
   - No confirmation line (`All assets were already uploaded` / `Successfully uploaded` / `new files and N duplicates`) → **keep source**
3. Only deletes source via `rm -rf` when all three checks pass clean.
4. Logs go to `~/homelab/upload-logs/upload-<timestamp>-<slug>.log` — one file per source path.

### Usage

```zsh
# Single folder
~/homelab/immich-upload-and-delete.sh "/Volumes/Seeni's HDD/Family Photos 2023"

# Multiple folders in one call
~/homelab/immich-upload-and-delete.sh \
  "/Volumes/Seeni's HDD/Family Photos 2023" \
  "/Volumes/Seeni's HDD/Family Photos 2024" \
  "/Volumes/Seeni's HDD/WhatsApp exports"
```

Output for a clean run:
```
=== /Volumes/Seeni's HDD/Family Photos 2023 ===
log: /Users/nila/homelab/upload-logs/upload-20260601-143022-Volumes-Seeni-s-HDD-Family-Photos-2023.log
... (immich CLI output) ...
✅ Upload clean — deleting source
🗑  deleted: /Volumes/Seeni's HDD/Family Photos 2023
```

Output when an error is detected:
```
❌ KEEPING /Volumes/Seeni's HDD/Family Photos 2024 — upload had failed-to-verify files. See ...
```

### Script locations

| Location | Purpose |
|---|---|
| `~/homelab/immich-upload-and-delete.sh` | User-local copy — run from here |
| `scripts/immich-upload-and-delete.sh` | Canonical repo copy — stays in sync |

> **Tip:** Concurrency is fixed at 4 in the script (conservative, safe for USB HDDs and OrbStack FUSE). Edit the `--concurrency` flag in the script if you want to go faster on a fast drive.

---

## Quick reference

| Task | Command |
|---|---|
| Login | `read -s "K?Key: "; immich login http://immich-server.homelab.svc.cluster.local:2283 "$K"; unset K` |
| Upload folder | `immich upload --recursive --concurrency 8 /path/` |
| Upload + auto-albums | `immich upload --recursive --album --concurrency 8 /path/` |
| Background upload | `nohup immich upload … > log 2>&1 &` |
| Stop upload | `pkill -f "immich upload"` |
| Scale ML up | `kubectl scale deployment immich-machine-learning -n homelab --replicas=3` |
| Scale ML down | `kubectl scale deployment immich-machine-learning -n homelab --replicas=1` |
| Watch ML queue | Web UI → Administration → Jobs |
| Find duplicates | Web UI → Administration → Jobs → Duplicate Detection |
| Logs of a deployment | `kubectl logs -f deployment/immich-server -n homelab` |
| Storage on HDD | `du -sh "/Volumes/Seeni's HDD/immich/upload/library/"` |

---

## Troubleshooting

**Upload stalls on "Crawling for assets..."**
The CLI hashes every file before uploading. For 40k+ files on a USB HDD this can take 10-30 min. Be patient. You'll see file counts and progress once it finishes.

**"Connection refused" / login fails**
Check the localhost port-forward is running:
```bash
launchctl list | grep homelab-localhost
curl http://immich-server.homelab.svc.cluster.local:2283/api/server/ping  # should return {"res":"pong"}
```
If not running:
```bash
launchctl load ~/Library/LaunchAgents/com.nila.homelab-localhost.plist
```

**Upload very slow despite high `--concurrency`**
Bottleneck is the HDD write speed (exFAT over USB ~100-200 MB/s). More concurrency won't help past that. Drop concurrency to 8 if you see I/O thrashing.

**Photos uploaded but face recognition empty**
ML queue still running. Check Administration → Jobs. Each ML pod processes ~100-300 photos/hour depending on resolution.

**Want to undo a bulk upload**
There's no batch delete from CLI. Use the web UI → select photos → delete. Or use the API directly if scripting.
