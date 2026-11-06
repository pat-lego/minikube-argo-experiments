#!/usr/bin/env bash
# Shared helpers for the exercise check scripts. Source it, don't run it.

pass() { printf "\033[32m  PASS  %s\033[0m\n" "$*"; }
fail() { printf "\033[31m  FAIL  %s\033[0m\n" "$*"; exit 1; }
info() { printf "\033[36m  ....  %s\033[0m\n" "$*"; }
hint() { printf "\033[33m  HINT  %s\033[0m\n" "$*"; }

require_cluster() {
  # Safety net: never run exercise commands against a real (work) cluster.
  local expected="${KUBE_CONTEXT:-minikube}" current
  current=$(kubectl config current-context 2>/dev/null || true)
  [[ "$current" == "$expected" ]] || {
    hint "Switch with:  kubectl config use-context $expected"
    fail "Current kubectl context is '$current', expected '$expected'."
  }
  kubectl cluster-info >/dev/null 2>&1 \
    || fail "Cannot reach the cluster. Run ./setup/install.sh first."
}

require_workflows_installed() {
  kubectl get crd workflows.argoproj.io >/dev/null 2>&1 \
    || fail "Argo Workflows is not installed. Run ./setup/install.sh first."
}

require_rollouts_installed() {
  kubectl get crd rollouts.argoproj.io >/dev/null 2>&1 \
    || fail "Argo Rollouts is not installed. Run ./setup/install.sh first."
}

# submit_workflow <file> [param=value ...] -> prints the generated workflow name
# Same idea as "argo submit -p key=value", but with kubectl only.
submit_workflow() {
  local file=$1; shift
  kubectl create -n argo -f "$file" --dry-run=client -o json \
    | python3 -c '
import json, sys
wf = json.load(sys.stdin)
for kv in sys.argv[1:]:
    key, value = kv.split("=", 1)
    params = wf["spec"].setdefault("arguments", {}).setdefault("parameters", [])
    for p in params:
        if p["name"] == key:
            p["value"] = value
            break
    else:
        params.append({"name": key, "value": value})
print(json.dumps(wf))
' "$@" \
    | kubectl create -n argo -f - -o jsonpath='{.metadata.name}'
}

# wait_for_workflow <name> [timeout-seconds] -> prints Succeeded|Failed|Error|Timeout
wait_for_workflow() {
  local name=$1 timeout=${2:-180} phase="" waited=0
  while (( waited < timeout )); do
    phase=$(kubectl -n argo get wf "$name" -o jsonpath='{.status.phase}' 2>/dev/null || true)
    case "$phase" in Succeeded|Failed|Error) echo "$phase"; return 0 ;; esac
    sleep 2; waited=$((waited + 2))
  done
  echo "Timeout"
}

# explain_workflow_failure <name> -> prints the messages Argo recorded
explain_workflow_failure() {
  local name=$1
  local msg
  msg=$(kubectl -n argo get wf "$name" -o jsonpath='{.status.message}')
  [[ -n "$msg" ]] && info "Workflow message: $msg"
  kubectl -n argo get wf "$name" -o json | python3 -c '
import json, sys
nodes = json.load(sys.stdin).get("status", {}).get("nodes", {})
for n in nodes.values():
    if n.get("phase") in ("Failed", "Error") and n.get("message"):
        print("  ....  step %-12s -> %s" % (n.get("displayName"), n["message"]))
'
}

# workflow_logs <name> -> all container logs of the workflow
workflow_logs() {
  kubectl -n argo logs -l "workflows.argoproj.io/workflow=$1" -c main \
    --tail=-1 --prefix --max-log-requests=20 2>/dev/null
}
