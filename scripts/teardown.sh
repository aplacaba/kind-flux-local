#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

echo "========================================="
echo "  Tearing down clusters..."
echo "========================================="

for cluster in dev prod; do
  if kind get clusters 2>/dev/null | grep -q "^${cluster}$"; then
    echo "→ Deleting kind cluster: ${cluster}"
    kind delete cluster --name "${cluster}"
    echo "✓ Deleted"
  else
    echo "→ kind cluster '${cluster}' does not exist, skipping"
  fi
done

echo ""
echo "✓ All clusters torn down."
echo ""
echo "Remaining kind clusters:"
kind get clusters 2>/dev/null || echo "  (none)"
