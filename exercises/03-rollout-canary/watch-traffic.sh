#!/usr/bin/env bash
# Shows the REAL traffic split of the rollouts-demo Service while a rollout runs.
#
# Every second it sends 20 separate requests to the Service from INSIDE the
# cluster and counts which version (color) answered each one:
#
#   20:41:07  blue  ████████████████      16
#             yellow ████                  4
#
# Why not the browser + "kubectl port-forward"? port-forward pins every request
# to ONE pod, and browsers reuse open connections, so you only see one color.
# Separate requests through the Service are spread across all pods by
# kube-proxy, so this shows what users would really get.
#
# Ctrl+C to stop. The helper pod is deleted on exit, even after Ctrl+C or a
# closed terminal. Each run uses its own pod name, so two terminals can watch
# at the same time. Leftovers (if any): ../../setup/teardown.sh
set -euo pipefail
cd "$(dirname "$0")"
source ../../scripts/lib.sh
require_cluster

POD="traffic-watcher-$$"   # unique per run ($$ = this script's process id)

# kubectl run --rm only cleans up when the session ends normally. Ctrl+C or a
# closed terminal kills kubectl first, so delete the pod ourselves on any exit.
cleanup() {
  trap - EXIT INT TERM HUP
  kubectl -n rollouts-lab delete pod "$POD" --ignore-not-found --grace-period=1 --wait=false >/dev/null 2>&1 || true
}
trap cleanup EXIT
trap 'cleanup; exit 130' INT TERM HUP

echo "Watching http://rollouts-demo/color in namespace rollouts-lab (Ctrl+C to stop)..."
kubectl -n rollouts-lab run "$POD" -i --quiet --restart=Never \
  --image=busybox:1.36 --labels=learning=minikube-argo-experiments,app=traffic-watcher -- sh -c '
while true; do
  results=""
  for i in $(seq 20); do
    # A request that fails or times out counts as "error" (useful with bad-red)
    c=$(wget -qO- -T 2 http://rollouts-demo/color 2>/dev/null | tr -d "\"") || c=error
    [ -z "$c" ] && c=error
    results="$results $c"
  done
  first=1
  for c in $(echo $results | tr " " "\n" | sort | uniq); do
    n=$(echo $results | tr " " "\n" | grep -cx "$c")
    bar=$(printf "%${n}s" | tr " " "#")
    if [ $first = 1 ]; then t=$(date +%T); first=0; else t="        "; fi
    printf "%s  %-7s %-20s %2d\n" "$t" "$c" "$bar" "$n"
  done
  echo
  sleep 1
done'
