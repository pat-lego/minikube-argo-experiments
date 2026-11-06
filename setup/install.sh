#!/usr/bin/env bash
# Installs everything the exercises need into a local minikube cluster:
#   - Argo Workflows  (namespace: argo)
#   - Argo Rollouts   (namespace: argo-rollouts)
#   - a playground namespace for exercise 03 (namespace: rollouts-lab)
#
# Safe to re-run: every step is idempotent.
set -euo pipefail

WORKFLOWS_VERSION="${WORKFLOWS_VERSION:-v4.1.6}"
ROLLOUTS_VERSION="${ROLLOUTS_VERSION:-v1.10.2}"

say()  { printf "\033[36m==> %s\033[0m\n" "$*"; }
warn() { printf "\033[33m!!  %s\033[0m\n" "$*"; }
die()  { printf "\033[31mxx  %s\033[0m\n" "$*"; exit 1; }

# --- 1. Tools -----------------------------------------------------------------
for tool in docker minikube kubectl; do
  command -v "$tool" >/dev/null || die "'$tool' is required. Install it with: brew install $tool"
done
command -v argo >/dev/null \
  || warn "Optional: the 'argo' CLI is missing (nicer than kubectl for workflows). Install: brew install argo"
command -v kubectl-argo-rollouts >/dev/null \
  || warn "Recommended: the rollouts kubectl plugin is missing. Install: brew install argoproj/tap/kubectl-argo-rollouts"

docker info >/dev/null 2>&1 || die "Docker is not running. Start Docker Desktop first."

# --- 2. Cluster ---------------------------------------------------------------
if minikube status >/dev/null 2>&1; then
  say "minikube is already running"
else
  say "Starting minikube (4 CPUs, 6 GB RAM)..."
  minikube start --cpus=4 --memory=6g
fi
kubectl config use-context minikube >/dev/null

ensure_ns() { kubectl create namespace "$1" --dry-run=client -o yaml | kubectl apply -f - >/dev/null; }

# --- 3. Argo Workflows --------------------------------------------------------
say "Installing Argo Workflows ${WORKFLOWS_VERSION} into namespace 'argo'"
ensure_ns argo
# quick-start-minimal = controller + UI server + RBAC so workflows can run as
# the 'default' service account in the 'argo' namespace. Perfect for learning,
# NOT for production.
kubectl apply -n argo --server-side --force-conflicts \
  -f "https://github.com/argoproj/argo-workflows/releases/download/${WORKFLOWS_VERSION}/quick-start-minimal.yaml" >/dev/null
kubectl -n argo rollout status deploy/workflow-controller --timeout=300s
kubectl -n argo rollout status deploy/argo-server --timeout=300s

# --- 4. Argo Rollouts ---------------------------------------------------------
say "Installing Argo Rollouts ${ROLLOUTS_VERSION} into namespace 'argo-rollouts'"
ensure_ns argo-rollouts
kubectl apply -n argo-rollouts --server-side --force-conflicts \
  -f "https://github.com/argoproj/argo-rollouts/releases/download/${ROLLOUTS_VERSION}/install.yaml" >/dev/null
kubectl -n argo-rollouts rollout status deploy/argo-rollouts --timeout=300s

# --- 5. Playground namespace --------------------------------------------------
ensure_ns rollouts-lab

say "All set! Start with: exercises/01-workflow-steps-and-parameters/README.md"
cat <<'EOF'

Handy UIs (run each in its own terminal):
  Argo Workflows UI : kubectl -n argo port-forward svc/argo-server 2746:2746
                      then open https://localhost:2746  (accept the self-signed cert)
  Argo Rollouts UI  : kubectl argo rollouts dashboard
                      then open http://localhost:3100
EOF
