#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

echo "========================================="
echo "  Flux GitOps — Cluster Setup"
echo "========================================="

# ──────────────────────────────────────────────
# 1. Create kind clusters
# ──────────────────────────────────────────────
for cluster in dev prod; do
  config="$ROOT_DIR/kind/kind-config-${cluster}.yaml"
  if ! kind get clusters 2>/dev/null | grep -q "^${cluster}$"; then
    echo "→ Creating kind cluster: ${cluster}"
    kind create cluster --config "$config"
    echo "✓ kind cluster '${cluster}' created"
  else
    echo "→ kind cluster '${cluster}' already exists, skipping creation"
  fi
done

echo ""
echo "→ Waiting for clusters to be ready..."
for cluster in dev prod; do
  kubectl cluster-info --context "kind-${cluster}" 2>/dev/null | head -1
done

# ──────────────────────────────────────────────
# 2. Install Flux Operator on each cluster
# ──────────────────────────────────────────────
echo ""
echo "→ Installing Flux Operator on each cluster..."
for cluster in dev prod; do
  ctx="kind-${cluster}"
  echo "--- [${cluster}] ---"
  helm upgrade --install flux-operator oci://ghcr.io/controlplaneio-fluxcd/charts/flux-operator \
    --kube-context "$ctx" \
    --namespace flux-system \
    --create-namespace \
    --wait \
    --timeout 5m
  echo "✓ Flux Operator installed on '${cluster}'"
done

echo ""
echo "→ Flux Operator status per cluster..."
for cluster in dev prod; do
  ctx="kind-${cluster}"
  echo "--- [${cluster}] ---"
  kubectl get pods --context "$ctx" \
    --namespace flux-system \
    -o custom-columns=NAME:.metadata.name,STATUS:.status.phase 2>/dev/null || true
done

echo ""
echo "→ Waiting for FluxInstance CRD to be established..."
for cluster in dev prod; do
  ctx="kind-${cluster}"
  echo "--- [${cluster}] ---"
  for i in $(seq 1 30); do
    if kubectl --context "$ctx" get crd fluxinstances.fluxcd.controlplane.io &>/dev/null 2>&1; then
      echo "  ✓ FluxInstance CRD ready"
      break
    fi
    sleep 2
  done
done

# ──────────────────────────────────────────────
# 3. Apply FluxInstance on each cluster
# ──────────────────────────────────────────────
echo ""
echo "→ Bootstrapping Flux on each cluster (FluxInstance)..."
for cluster in dev prod; do
  ctx="kind-${cluster}"
  echo "--- [${cluster}] ---"
  kubectl apply --context "$ctx" -f "$ROOT_DIR/clusters/${cluster}/flux-instance.yaml"
  echo "✓ FluxInstance applied on '${cluster}'"
done

echo ""
echo "→ Waiting for Flux components + CRDs to be ready..."
for cluster in dev prod; do
  ctx="kind-${cluster}"
  echo "--- [${cluster}] ---"
  # Wait for flux-system namespace
  for i in $(seq 1 30); do
    if kubectl get ns --context "$ctx" flux-system &>/dev/null; then
      echo "  ✓ flux-system namespace ready"
      break
    fi
    sleep 2
  done
  # Wait for HelmRelease CRD (from helm-controller)
  for i in $(seq 1 30); do
    if kubectl --context "$ctx" get crd helmreleases.helm.toolkit.fluxcd.io &>/dev/null 2>&1; then
      echo "  ✓ HelmRelease CRD ready"
      break
    fi
    sleep 2
  done
  kubectl get pods --context "$ctx" \
    --namespace flux-system \
    -o custom-columns=NAME:.metadata.name,STATUS:.status.phase 2>/dev/null \
    || echo "  (no pods in flux-system yet — still bootstrapping)"
done

# ──────────────────────────────────────────────
# 4. Apply remaining cluster resources (HelmReleases etc.)
# ──────────────────────────────────────────────
echo ""
echo "→ Applying remaining cluster resources (Traefik, Forgejo, etc)..."
for cluster in dev prod; do
  ctx="kind-${cluster}"
  echo "--- [${cluster}] ---"
  kubectl apply --context "$ctx" -k "$ROOT_DIR/clusters/${cluster}/"
  echo "✓ Cluster resources applied on '${cluster}'"
done

echo ""
echo "========================================="
echo "  Setup complete!"
echo ""
echo "  Contexts:"
echo "    kind-dev     → kubectl --context kind-dev <cmd>"
echo "    kind-prod    → kubectl --context kind-prod <cmd>"
echo ""
echo "  Flux UI (dev):  http://127.0.0.1:30080"
echo "  Flux UI (prod): http://127.0.0.1:30180"
echo "========================================="
