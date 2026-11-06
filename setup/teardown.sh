#!/usr/bin/env bash
# Two levels of cleanup:
#   ./setup/teardown.sh          -> delete exercise resources only (keep Argo installed)
#   ./setup/teardown.sh --all    -> delete the whole minikube cluster
set -euo pipefail

if [[ "${1:-}" == "--all" ]]; then
  read -r -p "This deletes the entire minikube cluster. Continue? [y/N] " answer
  [[ "$answer" =~ ^[Yy]$ ]] || { echo "Aborted."; exit 0; }
  minikube delete
  exit 0
fi

# Safety net: only ever delete things from the local minikube cluster.
EXPECTED="${KUBE_CONTEXT:-minikube}"
CURRENT=$(kubectl config current-context 2>/dev/null || true)
if [[ "$CURRENT" != "$EXPECTED" ]]; then
  echo "Refusing to run: current kubectl context is '$CURRENT', expected '$EXPECTED'."
  echo "Switch with:  kubectl config use-context $EXPECTED"
  exit 1
fi

echo "Deleting exercise workflows (namespace argo)..."
kubectl -n argo delete workflows -l learning=minikube-argo-experiments --ignore-not-found

echo "Deleting exercise 03 rollout (namespace rollouts-lab)..."
kubectl -n rollouts-lab delete rollout,service -l learning=minikube-argo-experiments --ignore-not-found

echo "Done. Argo Workflows and Argo Rollouts are still installed."
