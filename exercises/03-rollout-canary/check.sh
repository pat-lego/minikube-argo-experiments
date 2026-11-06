#!/usr/bin/env bash
# Verifies the state of the rollout in the cluster (it does not change anything).
# Run it at the END of the README walkthrough.
set -euo pipefail
cd "$(dirname "$0")"
source ../../scripts/lib.sh

NS=rollouts-lab
echo "Exercise 03 - canary rollout"
require_cluster
require_rollouts_installed

kubectl -n "$NS" get rollout rollouts-demo >/dev/null 2>&1 \
  || fail "Rollout 'rollouts-demo' not found. Did you run: kubectl apply -f rollout.yaml ?"
pass "Rollout exists"

ROLLOUT_JSON=$(kubectl -n "$NS" get rollout rollouts-demo -o json)

# 1. The strategy contains an indefinite pause right after setWeight: 20
python3 -c '
import json, sys
steps = json.loads(sys.argv[1])["spec"]["strategy"]["canary"]["steps"]
ok = any(
    "setWeight" in steps[i] and steps[i]["setWeight"] == 20
    and i + 1 < len(steps) and "pause" in steps[i + 1]
    and not steps[i + 1]["pause"].get("duration")
    for i in range(len(steps))
)
sys.exit(0 if ok else 1)
' "$ROLLOUT_JSON" || {
  hint "Add   - pause: {}   right after   - setWeight: 20   and re-apply rollout.yaml"
  fail "No indefinite pause after setWeight: 20"
}
pass "Canary strategy pauses indefinitely at 20%"

# 2. The rollout was taken through at least one update
REVISION=$(kubectl -n "$NS" get rollout rollouts-demo \
  -o jsonpath='{.metadata.annotations.rollout\.argoproj\.io/revision}')
(( REVISION >= 2 )) || {
  hint "Walk through README step 4: set the image to yellow and promote it."
  fail "Rollout was never updated (revision=$REVISION)"
}
pass "Rollout has been updated (revision $REVISION)"

# 3. End state: Healthy and running the yellow version
PHASE=$(kubectl -n "$NS" get rollout rollouts-demo -o jsonpath='{.status.phase}')
IMAGE=$(kubectl -n "$NS" get rollout rollouts-demo -o jsonpath='{.spec.template.spec.containers[0].image}')
[[ "$PHASE" == "Healthy" ]] || {
  hint "Current phase is '$PHASE'. Paused -> promote it. Degraded -> you aborted; set the image back to the stable one."
  fail "Rollout is not Healthy"
}
[[ "$IMAGE" == "argoproj/rollouts-demo:yellow" ]] || {
  hint "Finish README step 5: after aborting the bad release, set the image back to :yellow."
  fail "Expected the final image to be argoproj/rollouts-demo:yellow, got $IMAGE"
}
pass "Rollout is Healthy on argoproj/rollouts-demo:yellow"

echo
pass "Exercise 03 complete! Try the bonus tasks in the README."
