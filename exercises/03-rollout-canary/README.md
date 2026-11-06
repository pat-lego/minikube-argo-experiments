# Exercise 03: Canary release with Argo Rollouts

**Time:** about 20 minutes · **Your job:** fill in 1 TODO (1 line of YAML), then run a
release by hand: **promote** a good version and **abort** a bad one.

## What you will learn

- What a `Rollout` is and how it differs from a `Deployment`.
- **Canary** strategy: send a small slice of users to the new version first.
- The release lifecycle: `setWeight` → `pause` → `promote` / `abort`.
- The `kubectl argo rollouts` plugin and its dashboard.

## Deployment vs. Rollout

| Deployment (built into Kubernetes)  | Rollout (Argo Rollouts CRD)                        |
|-------------------------------------|----------------------------------------------------|
| `RollingUpdate`: replaces Pods as fast as they get ready | Canary or BlueGreen, controlled **step by step** |
| No built-in "stop at 20% and wait"  | `pause` steps, manual `promote`, `abort`            |
| Rollback = run a new rollout        | Abort = instantly scale back to the **stable** version |
| Can't check metrics during the rollout | `AnalysisTemplate` can auto-promote or auto-abort  |

The Pod template is identical. You change `kind: Deployment` to `kind: Rollout`
and add a `strategy`.

## Canary with no traffic router

```
image changes to :yellow
  step 1  setWeight: 20   → 1 yellow Pod + 4 blue Pods   (about 20% of requests)
  step 2  pause: {}       → waits until YOU run "promote"   ◄── your TODO
  step 3  setWeight: 60   → 3 yellow + 2 blue
  step 4  pause: 10s      → waits 10 seconds, then continues by itself
  done                    → 5 yellow, yellow becomes the new "stable"
```

## Steps

> Tip: keep a second terminal open with the live view:
> `kubectl argo rollouts get rollout rollouts-demo -n rollouts-lab --watch`

### 1. Fix the TODO in `rollout.yaml` and apply it

```bash
kubectl apply -f rollout.yaml
kubectl argo rollouts get rollout rollouts-demo -n rollouts-lab
```

The **first** deploy skips the steps (there is no old version to compare with),
so all 5 Pods start as `blue` and the status is `✔ Healthy`.

### 2. (Recommended) Open the visual demo

```bash
kubectl -n rollouts-lab port-forward svc/rollouts-demo 8080:80
```

Open <http://localhost:8080>. Each square is a request, painted with the color of
the Pod that answered it. Keep it open during step 3.

You can also open the Rollouts dashboard: `kubectl argo rollouts dashboard`, then
<http://localhost:3100>.

### 3. Release a new version (yellow) and promote it

```bash
kubectl argo rollouts set image rollouts-demo -n rollouts-lab \
  rollouts-demo=argoproj/rollouts-demo:yellow
```

Watch the live view. The rollout reaches `SetWeight: 20` and then shows
**`॥ Paused`**: one yellow Pod (`canary`) and four blue Pods (`stable`). About 1 in 5
squares in the demo turns yellow.

This is the moment where, in real life, you check dashboards and error rates.
It looks good, so continue:

```bash
kubectl argo rollouts promote rollouts-demo -n rollouts-lab
```

The rollout goes to 60%, waits 10 seconds by itself, and finishes at 100% yellow.
`yellow` is now the **stable** version.

### 4. Release a bad version and abort it

`bad-red` is a demo image that returns HTTP errors on part of its requests.

```bash
kubectl argo rollouts set image rollouts-demo -n rollouts-lab \
  rollouts-demo=argoproj/rollouts-demo:bad-red
```

It stops at 20% again. In the demo, some squares turn red or show errors. Do not
promote it. Abort instead:

```bash
kubectl argo rollouts abort rollouts-demo -n rollouts-lab
```

Every Pod goes back to yellow right away. The rollout is now **`✖ Degraded`**.
That is expected: the spec still asks for `bad-red`, but the controller refuses
to keep it. Point the spec back at the stable version:

```bash
kubectl argo rollouts set image rollouts-demo -n rollouts-lab \
  rollouts-demo=argoproj/rollouts-demo:yellow
```

Because `yellow` *is* the stable version, the steps are skipped and the
rollout is `✔ Healthy` immediately.

### 5. Verify

```bash
./check.sh
```

The check reads the Rollout from the cluster. It does not change anything.

## Bonus (optional)

1. Run `kubectl get replicasets -n rollouts-lab` during a paused rollout. A
   Rollout manages ReplicaSets, just like a Deployment.
2. Change the strategy to `blueGreen` (see the [docs](https://argo-rollouts.readthedocs.io/en/stable/features/bluegreen/)):
   the new version starts at full size *next to* the old one, and traffic switches all at once.
3. Read about [Analysis](https://argo-rollouts.readthedocs.io/en/stable/features/analysis/):
   replace the manual `pause: {}` with an `analysis` step that checks a metric and
   promotes or aborts **by itself**. This is how Rollouts is used in production.

## Key takeaways

- A **Rollout** is a Deployment with a programmable release strategy.
- `setWeight` sets how much traffic (or how many Pods) gets the new version; `pause` stops the release.
- **promote** = "looks good, continue"; **abort** = "go back to stable now".
- After an abort, the Rollout is `Degraded` until the spec matches a good version again.

## Clean up

```bash
../../setup/teardown.sh        # remove exercise resources, keep Argo installed
../../setup/teardown.sh --all  # delete the whole minikube cluster
```
