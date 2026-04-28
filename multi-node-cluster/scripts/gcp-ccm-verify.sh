#!/usr/bin/env bash
# Post-deploy verification for GCP CCM (requires working kubectl).
set -euo pipefail

echo "=== GCP CCM verification ==="
kubectl -n kube-system get daemonset cloud-controller-manager -o wide
kubectl -n kube-system get pods -l component=cloud-controller-manager -o wide
kubectl get nodes -o custom-columns='NAME:.metadata.name,PROVIDER-ID:.spec.providerID'

echo ""
echo "Optional: deploy a test LoadBalancer Service"
echo "  kubectl create deploy hello-cm-test --image=nginx"
echo "  kubectl expose deploy hello-cm-test --port=80 --type=LoadBalancer"
echo "  kubectl get svc hello-cm-test -w"
