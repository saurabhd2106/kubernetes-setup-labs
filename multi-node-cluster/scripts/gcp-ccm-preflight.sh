#!/usr/bin/env bash
# Pre-flight checks before enabling GCP Cloud Controller Manager (read-only).
# Usage: ./gcp-ccm-preflight.sh [GCP_PROJECT_ID]
set -euo pipefail

PROJECT="${1:-}"
echo "=== GCP CCM pre-flight ==="

if ! command -v kubectl >/dev/null 2>&1; then
  echo "ERROR: kubectl not found."
  exit 1
fi

echo "--- Kubernetes version ---"
kubectl version --short 2>/dev/null || kubectl version -o yaml | head -20

echo "--- Nodes vs providerID ---"
kubectl get nodes -o custom-columns='NAME:.metadata.name,INTERNAL-IP:.status.addresses[?(@.type=="InternalIP")].address,PROVIDER-ID:.spec.providerID' || true

echo "--- Calico ---"
kubectl -n kube-system get pods -l k8s-app=calico-node -o wide 2>/dev/null || echo "(no calico-node pods — check CNI)"

echo "--- kube-apiserver cloud-provider flag ---"
kubectl -n kube-system get pod -l component=kube-apiserver -o yaml 2>/dev/null | grep -E 'cloud-provider|--cloud-provider' || echo "(none — OK for external CCM)"

echo "--- kube-controller-manager cloud-provider flag ---"
kubectl -n kube-system get pod -l component=kube-controller-manager -o yaml 2>/dev/null | grep -E 'cloud-provider|--cloud-provider' || echo "(none — OK)"

if [[ -n "${PROJECT}" ]] && command -v gcloud >/dev/null 2>&1; then
  echo "--- GCE instances (compare names to kubectl node NAME) ---"
  gcloud compute instances list --project="${PROJECT}" --format='table(name,zone,networkInterfaces[0].networkIP)' || true

  echo ""
  echo "Ensure each Kubernetes Node .metadata.name equals the GCE instance name,"
  echo "e.g. inventory hostname demo-vm-1 matches instance demo-vm-1."
else
  echo "--- Skipping gcloud instance list (set PROJECT arg or install gcloud) ---"
fi

echo "=== Done ==="
