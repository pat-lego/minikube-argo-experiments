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

echo "Deleting exercise workflows (namespace argo)..."
kubectl -n argo delete workflows -l learning=minikube-argo-experiments --ignore-not-found

echo "Deleting exercise 03 rollout (namespace rollouts-lab)..."
kubectl -n rollouts-lab delete rollout,service -l learning=minikube-argo-experiments --ignore-not-found

echo "Done. Argo Workflows and Argo Rollouts are still installed."
