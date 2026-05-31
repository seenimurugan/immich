# Immich — User Manual

How to use Immich day-to-day. See [README](README.md) for access URLs.

**On this page:** [Initial setup (first visit)](#initial-setup-first-visit) · [Add family members](#add-family-members) · [Mobile app — auto-backup from iPhone/Android](#mobile-app--auto-backup-from-iphoneandroid) · [Browse & search](#browse--search) · [Sharing](#sharing) · [Bulk upload from the Mac (CLI)](#bulk-upload-from-the-mac-cli) · [Upgrade Immich to a newer version](#upgrade-immich-to-a-newer-version)

## Initial setup (first visit)

1. Open https://immich.stoat-perch.ts.net
2. Create admin account (your email + password)
3. Admin → Settings → walk through the wizard (storage template, smart search, etc. — defaults are fine)

## Add family members

Administration → Users → **+ Create User** — each gets username + password.

Now each family member can:
- Install the **Immich** mobile app
- Connect to `https://immich.stoat-perch.ts.net`
- Log in with their own credentials
- Their phone backs up to their own library (with optional sharing)

## Mobile app — auto-backup from iPhone/Android

1. App Store → install **Immich** → open
2. Add server: `https://immich.stoat-perch.ts.net`
3. Log in
4. Settings → **Backup** → choose albums (Camera Roll = everything) → enable
5. Optional: turn on **Background backup**

Photos upload automatically as you take them. The mobile app shows progress in the upload queue.

## Browse & search

- **Timeline** — scroll by date, default view
- **Albums** — manually grouped collections
- **Library** → **People** — faces auto-detected (after ML processing runs)
- **Library** → **Places** — map of geotagged photos
- **Library** → **Memories** — "this day N years ago"
- **Smart search** — top search bar: try "beach" or "sunset" or "dog" — uses CLIP embeddings, no tagging needed
- **Duplicates** — Administration → Jobs → Duplicate Detection → resolve in your account → Duplicates page

## Sharing

- **Share a single photo/album link** — open it → ⋮ menu → Share → Create link. Anyone with the link can view (no Immich account needed).
- **Share with family on Immich** — open album → ⋮ → Share with users → pick from your Immich users.

## Bulk upload from the Mac (CLI)

See [BULK-UPLOAD.md](BULK-UPLOAD.md) — covers Immich CLI install, bulk uploads from HDD folders, Google Takeout zips, ML scaling tips.

## Upgrade Immich to a newer version

See [UPGRADE.md](UPGRADE.md) — covers safe pre-upgrade backup, image tag bump, DB migration, rollback.
