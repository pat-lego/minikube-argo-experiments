#!/usr/bin/env bash
# Submits workflow.yaml (or the file you pass), waits, and verifies the result.
set -euo pipefail
cd "$(dirname "$0")"
source ../../scripts/lib.sh

FILE="${1:-workflow.yaml}"
echo "Exercise 02 - DAG pipeline ($FILE)"
require_cluster
require_workflows_installed

info "Submitting $FILE"
NAME=$(submit_workflow "$FILE")
info "Workflow: $NAME   (watch it: kubectl -n argo get wf $NAME -w)"

PHASE=$(wait_for_workflow "$NAME" 240)
if [[ "$PHASE" != "Succeeded" ]]; then
  explain_workflow_failure "$NAME"
  hint "Read the message above, then check both TODOs:"
  hint "  TODO 1: does deploy have a 'depends' line listing unit-test and lint?"
  hint "  TODO 2: does the version value reference the build task's output parameter?"
  fail "Workflow finished with phase: $PHASE"
fi
pass "Workflow Succeeded"

# Inspect status.nodes to prove deploy started only after BOTH checks finished.
kubectl -n argo get wf "$NAME" -o json | python3 -c '
import json, sys
nodes = {n["displayName"]: n for n in json.load(sys.stdin)["status"]["nodes"].values()}
for t in ("build", "unit-test", "lint", "deploy"):
    if t not in nodes:
        print("missing task: " + t); sys.exit(1)
deploy_start = nodes["deploy"]["startedAt"]
late = [t for t in ("unit-test", "lint") if nodes[t]["finishedAt"] > deploy_start]
if late:
    print("deploy started before " + ", ".join(late) + " finished"); sys.exit(2)
' || {
  hint "TODO 1: deploy needs   depends: \"unit-test && lint\""
  fail "deploy must start only after unit-test AND lint have finished"
}
pass "deploy waited for unit-test and lint"

LOGS=$(workflow_logs "$NAME")
grep -q "Deploying v1\." <<<"$LOGS" \
  || fail "deploy did not receive the version from build"
pass "deploy received the version output by build"

echo
pass "Exercise 02 complete! Try the bonus tasks in the README."
