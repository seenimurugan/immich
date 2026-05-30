#!/usr/bin/env bash
# deploy.sh — idempotent deploy for Immich (photo server)
# Usage: ./deploy.sh
# Safe to re-run; existing resources are patched, not replaced.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── 1. Load .env ─────────────────────────────────────────────────────────────
ENV_FILE="$SCRIPT_DIR/.env"
if [[ ! -f "$ENV_FILE" ]]; then
  echo "ERROR: .env not found."
  echo "       Copy .env.example to .env and fill in real values, then re-run."
  echo "         cp .env.example .env && \$EDITOR .env"
  exit 1
fi
# shellcheck disable=SC1090
set -a; source "$ENV_FILE"; set +a

# ── 2. Prereq checks ─────────────────────────────────────────────────────────
for cmd in kubectl helm envsubst; do
  if ! command -v "$cmd" &>/dev/null; then
    echo "ERROR: '$cmd' not found in PATH."
    [[ "$cmd" == "envsubst" ]] && echo "       Install via: brew install gettext"
    [[ "$cmd" == "helm" ]]     && echo "       Install via: brew install helm"
    exit 1
  fi
done
if ! kubectl cluster-info &>/dev/null; then
  echo "ERROR: Cannot reach the Kubernetes cluster. Is OrbStack running?"
  exit 1
fi

# ── 3. Validate required env vars ────────────────────────────────────────────
: "${HOMELAB_NAMESPACE:?HOMELAB_NAMESPACE must be set in .env}"
: "${HOMELAB_HDD_PATH:?HOMELAB_HDD_PATH must be set in .env}"
: "${HOMELAB_TIER_HDD_PATH:?HOMELAB_TIER_HDD_PATH must be set in .env}"
: "${IMMICH_DB_PASSWORD:?IMMICH_DB_PASSWORD must be set in .env (never commit this)}"

if [[ "$IMMICH_DB_PASSWORD" == "change-me" ]]; then
  echo "ERROR: IMMICH_DB_PASSWORD is still set to 'change-me' — please set a real password."
  exit 1
fi

# ── 4. Ensure namespace exists ───────────────────────────────────────────────
if ! kubectl get namespace "$HOMELAB_NAMESPACE" &>/dev/null; then
  echo "Namespace '$HOMELAB_NAMESPACE' not found — creating it."
  kubectl create namespace "$HOMELAB_NAMESPACE"
else
  echo "Namespace '$HOMELAB_NAMESPACE' already exists."
fi

# ── 5. Add Helm repo ─────────────────────────────────────────────────────────
echo "Ensuring Helm repo immich/immich..."
helm repo add immich https://immich-app.github.io/immich-charts 2>/dev/null || true
helm repo update immich

# ── 6. Apply k8s manifests via envsubst ──────────────────────────────────────
# Note: postgres.yaml contains the immich-postgres-secret. The Secret's
# POSTGRES_PASSWORD is sourced from IMMICH_DB_PASSWORD in your .env.
K8S_DIR="$SCRIPT_DIR/k8s"
echo "Applying k8s manifests (envsubst → kubectl apply)..."
for f in "$K8S_DIR/postgres.yaml" "$K8S_DIR/photos-readonly-pv.yaml" "$K8S_DIR/backup-cronjob.yaml"; do
  echo "  → $(basename "$f")"
  envsubst < "$f" | kubectl apply -f -
done

# ── 7. Helm upgrade --install ─────────────────────────────────────────────────
echo "Running envsubst on values/immich-values.yaml..."
TMPVALS="$(mktemp /tmp/immich-values-XXXXXX.yaml)"
envsubst < "$SCRIPT_DIR/values/immich-values.yaml" > "$TMPVALS"

echo "Deploying Immich via Helm..."
helm upgrade --install immich immich/immich \
  --namespace "$HOMELAB_NAMESPACE" \
  --version 0.11.1 \
  -f "$TMPVALS" \
  --wait \
  --timeout 10m
rm -f "$TMPVALS"

# ── 8. Done ───────────────────────────────────────────────────────────────────
echo ""
echo "Immich deployed successfully."
echo ""
echo "  Tailnet URL:   https://immich.stoat-perch.ts.net"
echo "  Local URL:     http://localhost:2283  (if port-forward is active)"
echo ""
echo "  Bulk upload guide:  docs/BULK-UPLOAD.md"
echo "  Upgrade guide:      docs/UPGRADE.md"
echo "  Maintenance guide:  docs/MAINTENANCE.md"
echo ""
echo "  NOTE: If IMMICH_UPLOAD_PV_PATH is blank in .env, run:"
echo "    kubectl get pv | grep immich-upload"
echo "  to discover the local-path PV backing the library PVC."
echo "  See README.md 'Non-portable bits' for details."
