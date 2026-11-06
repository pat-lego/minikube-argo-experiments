# Argo in 5 minutes

## What is "Argo"?

**Argo** is a family of open-source Kubernetes tools (a CNCF project). They are
separate products that share a name and an API group (`argoproj.io`):

| Project | Answers the question | Covered here |
|---------|----------------------|--------------|
| **Argo Workflows** | "Run these containers in this order (or graph)." | Exercises 01 and 02 |
| **Argo Rollouts** | "Release a new version of my app *gradually and safely*." | Exercise 03 |
| Argo CD | "Keep the cluster in sync with what is in Git (GitOps)." | not covered |
| Argo Events | "When X happens (webhook, message, cron), trigger Y." | not covered |

## The shared idea: CRD + controller

Kubernetes understands built-in kinds such as `Pod` and `Deployment`. Argo
adds **new kinds** (Custom Resource Definitions, or CRDs) and a **controller**
that watches them:

```
you:        kubectl apply -f my.yaml   (kind: Workflow / Rollout)
                    │
                    ▼
API server  stores the object
                    │  (watch)
                    ▼
controller  reads it, creates Pods / ReplicaSets, updates .status
                    │
                    ▼
you:        kubectl get workflow|rollout ...   reads .status
```

The controllers live in their own namespaces:

```bash
kubectl get pods -n argo            # workflow-controller, argo-server (UI)
kubectl get pods -n argo-rollouts   # argo-rollouts (controller)
```

Because everything is a Kubernetes object, your usual tools keep working:
`kubectl get`, `describe`, `logs`, `-o yaml`.

## Argo Workflows vocabulary

| Term | Meaning |
|------|---------|
| **Workflow** | One *run*. A CRD (`kind: Workflow`). Usually created with `generateName`. |
| **template** | A reusable unit, like a function. Types: `container`, `script`, `steps`, `dag`, and others. |
| **entrypoint** | The template that runs first (like `main`). |
| **steps** | A list of lists: groups run in order, and steps within a group run in parallel. |
| **dag** | Tasks plus `depends`. Argo runs everything it can, as early as possible. |
| **parameters** | String inputs and outputs. Written as `{{workflow.parameters.x}}`, `{{inputs.parameters.x}}`, `{{tasks.t.outputs.parameters.x}}`. |
| **artifacts** | File inputs and outputs (stored in S3, GCS, and similar). Not covered here. |
| **WorkflowTemplate / CronWorkflow** | A stored, reusable workflow definition, and a scheduled one. |

**Every step = one Pod.** That is the most useful thing to remember when debugging.

Typical uses: CI/CD pipelines, data and ML pipelines, batch jobs, load and
performance test orchestration, and infrastructure automation.

## Argo Rollouts vocabulary

| Term | Meaning |
|------|---------|
| **Rollout** | A drop-in replacement for `Deployment`, with a programmable release `strategy`. |
| **stable / canary** | The current good version, and the new version being tested. |
| **canary strategy** | Shift traffic (or Pods) to the new version in `setWeight` steps. |
| **blueGreen strategy** | Start the new version at full size, then switch traffic all at once. |
| **pause** | `pause: {}` waits for a human; `pause: {duration: 30s}` waits for a set time. |
| **promote** | "Looks good, continue to the next step." |
| **abort** | "Bad release, go back to stable now." The Rollout becomes `Degraded`. |
| **AnalysisTemplate** | Automated checks (Prometheus, Datadog, a Job, and others) that promote or abort for you. |
| **traffic routing** | With Istio, NGINX, or ALB, the weight becomes a real traffic percentage. Without one, it is done by Pod count. |

Rollout phases you will see: `Healthy`, `Progressing`, `Paused`, `Degraded`.

## Where to go next

- Argo Workflows docs: <https://argo-workflows.readthedocs.io/en/latest/>
- Workflow examples: <https://github.com/argoproj/argo-workflows/tree/main/examples>
- Argo Rollouts docs: <https://argo-rollouts.readthedocs.io/en/stable/>
- Rollouts getting started: <https://argo-rollouts.readthedocs.io/en/stable/getting-started/>
