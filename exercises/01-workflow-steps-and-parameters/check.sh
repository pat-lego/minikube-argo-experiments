#!/usr/bin/env bash
# Submits workflow.yaml (or the file you pass), waits, and verifies the result.
#   ./check.sh                 # checks your workflow.yaml
#   ./check.sh other.yaml      # checks another file
set -euo pipefail
cd "$(dirname "$0")"
source ../../scripts/lib.sh

FILE="${1:-workflow.yaml}"
echo "Exercise 01 - steps and parameters ($FILE)"
require_cluster
require_workflows_installed

info "Submitting $FILE with -p name=Checker"
# We pass a custom name so we can prove the parameter really flows through.
NAME=$(submit_workflow "$FILE" name=Checker)
info "Workflow: $NAME   (watch it: kubectl -n argo get wf $NAME -w)"

PHASE=$(wait_for_workflow "$NAME" 180)
if [[ "$PHASE" != "Succeeded" ]]; then
  explain_workflow_failure "$NAME"
  hint "Does say-goodbye pass a 'message' parameter to print-message?"
  fail "Workflow finished with phase: $PHASE"
fi
pass "Workflow Succeeded"

LOGS=$(workflow_logs "$NAME")
grep -q "Hello, Checker!" <<<"$LOGS"   || fail "Expected a pod to print 'Hello, Checker!'"
pass "say-hello printed 'Hello, Checker!'"

grep -q "Goodbye, Checker!" <<<"$LOGS" || {
  hint "Use {{workflow.parameters.name}} in the goodbye message, not a hard-coded name."
  fail "Expected a pod to print 'Goodbye, Checker!'"
}
pass "say-goodbye printed 'Goodbye, Checker!'"

echo
pass "Exercise 01 complete! Try the bonus tasks in the README."
