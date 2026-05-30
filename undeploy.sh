#!/usr/bin/env bash
# undeploy.sh — tear down Immich deployments/services/cronjobs
# Preserves data: PVCs/PVs are NOT deleted. Photos on HDD NOT deleted.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── Load .env for HOMELAB_NAMESPACE ──────────────────────────────────────────
ENV_FILE="$SCRIPT_DIR/.env"
if [[ -f "$ENV_FILE" ]]; then
  # shellcheck disable=SC1090
  set -a; source "$ENV_FILE"; set +a
fi
HOMELAB_NAMESPACE="${HOMELAB_NAMESPACE:-homelab}"

echo "Undeploying Immich from namespace '$HOMELAB_NAMESPACE'..."
echo ""
echo "WARNING: Photos on HDD are NOT deleted."
echo "WARNING: PVCs (library + postgres) are NOT deleted."
echo "WARNING: The immich-postgres-secret is NOT deleted (holds DB password)."
echo ""

# ── Helm uninstall (removes server, machine-learning, valkey) ────────────────
echo "Uninstalling Helm release 'immich'..."
helm uninstall immich --namespace "$HOMELAB_NAMESPACE" --ignore-not-found || true

# ── Custom Postgres workload (keep the PVC) ───────────────────────────────────
echo "Deleting immich-postgres StatefulSet and Service (PVC retained)..."
kubectl -n "$HOMELAB_NAMESPACE" delete statefulset immich-postgres --ignore-not-found
kubectl -n "$HOMELAB_NAMESPACE" delete service     immich-postgres --ignore-not-found

# ── Backup CronJob ────────────────────────────────────────────────────────────
echo "Deleting immich-backup CronJob..."
kubectl -n "$HOMELAB_NAMESPACE" delete cronjob     immich-backup   --ignore-not-found
kubectl -n "$HOMELAB_NAMESPACE" delete serviceaccount immich-backup --ignore-not-found

# ── Photos readonly PV/PVC ────────────────────────────────────────────────────
echo "Deleting immich-photos-readonly PV/PVC..."
kubectl -n "$HOMELAB_NAMESPACE" delete pvc immich-photos-readonly-pvc --ignore-not-found
kubectl delete pv immich-photos-readonly-pv --ignore-not-found

echo ""
echo "Immich torn down."
echo ""
echo "  Kept (data):"
echo "    - PVC: immich-postgres-pvc  (Postgres DB — contains all metadata, albums, faces)"
echo "    - PVC: immich-upload-localpath-pvc  (SSD-backed photo library PVC)"
echo "    - Photos on HDD: ${HOMELAB_HDD_PATH:-/Volumes/Seeni's HDD}/immich/"
echo "    - Tiered photos: ${HOMELAB_TIER_HDD_PATH:-/Volumes/homelab-hdd}/immich-library/"
echo "    - Secret: immich-postgres-secret"
echo ""
echo "  To redeploy:  ./deploy.sh"
echo ""
echo "  To fully wipe (IRREVERSIBLE — destroys all photos + metadata):"
echo "    kubectl -n $HOMELAB_NAMESPACE delete pvc immich-postgres-pvc immich-upload-localpath-pvc"
echo "    rm -rf \"${HOMELAB_HDD_PATH:-/Volumes/Seeni's HDD}/immich/\""
echo "    kubectl -n $HOMELAB_NAMESPACE delete secret immich-postgres-secret"
