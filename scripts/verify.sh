#!/usr/bin/env bash
set -euo pipefail

echo "========================================="
echo "  Verification — Flux status per cluster"
echo "========================================="

for cluster in dev prod; do
  ctx="kind-${cluster}"
  echo ""
  echo "─── [${cluster}] ───────────────────────"

  # Cluster reachable?
  if ! kubectl --context "$ctx" cluster-info 2>/dev/null | head -1 >/dev/null; then
    echo "  ✗ Cluster '${cluster}' not reachable"
    continue
  fi
  echo "  ✓ Cluster reachable"

  # Flux Operator
  op_pods=$(kubectl --context "$ctx" get pods -n flux-operator -o json 2>/dev/null)
  if echo "$op_pods" | grep -q '"Running"'; then
    echo "  ✓ Flux Operator running"
  else
    echo "  ✗ Flux Operator not running"
  fi

  # FluxInstance
  if kubectl --context "$ctx" get fluxinstance -A 2>/dev/null | grep -q .; then
    echo "  ✓ FluxInstance exists"
    kubectl --context "$ctx" get fluxinstance -A
  else
    echo "  ✗ No FluxInstance found"
  fi

  # Flux components in flux-system
  if kubectl --context "$ctx" get pods -n flux-system 2>/dev/null | grep -q .; then
    echo "  ✓ Flux components in flux-system:"
    kubectl --context "$ctx" get pods -n flux-system \
      -o custom-columns=NAME:.metadata.name,STATUS:.status.phase
  else
    echo "  ✗ No Flux components in flux-system"
  fi
done

echo ""
echo "========================================="
echo "  Verification complete"
echo "========================================="
