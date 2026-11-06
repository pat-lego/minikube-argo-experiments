# minikube-argo-experiments

A beginner, hands-on introduction to **Argo Workflows** and **Argo Rollouts**,
running on a local `minikube` cluster.

There are three short exercises. Each one is **about 90% done**: you read the
YAML (every line is commented), fill in a small `TODO`, run it, and check it
with a script. Plan for about an hour for all three.

| # | Exercise | Argo project | You learn | Your work |
|---|----------|--------------|-----------|-----------|
| 01 | [Steps and parameters](exercises/01-workflow-steps-and-parameters/README.md) | Workflows | Workflow anatomy, templates, `steps`, parameters | 1 TODO (about 5 lines) |
| 02 | [CI pipeline as a DAG](exercises/02-workflow-dag/README.md) | Workflows | `dag`, `depends`, output parameters, parallelism | 2 TODOs (2 lines) |
| 03 | [Canary release](exercises/03-rollout-canary/README.md) | Rollouts | Rollout vs. Deployment, canary steps, promote and abort | 1 TODO (1 line) and a few CLI commands |

New to Argo? Read [docs/concepts.md](docs/concepts.md) first (5 minutes).

## Prerequisites (macOS)

```bash
brew install minikube kubectl          # required
brew install argo                      # Argo Workflows CLI (recommended)
brew install argoproj/tap/kubectl-argo-rollouts   # Rollouts kubectl plugin (needed for ex. 03)
```

Docker Desktop must be running. The cluster uses 4 CPUs and 6 GB of RAM.

## Make sure kubectl points at minikube

```bash
kubectl config use-context minikube && kubectl get nodes   # one node: "minikube"
```

See [exercise 01, step 0](exercises/01-workflow-steps-and-parameters/README.md#0-point-kubectl-at-minikube-do-this-first-every-new-terminal)
for how contexts work. The scripts refuse to run on any other context.

## Setup (once, about 3 minutes)

```bash
./setup/install.sh
```

The script starts minikube (if it is not already running) and installs:

| Component | Namespace | Version (override with environment variables) |
|-----------|-----------|-----------------------------------|
| Argo Workflows (controller + UI) | `argo` | `WORKFLOWS_VERSION=v4.1.6` |
| Argo Rollouts (controller) | `argo-rollouts` | `ROLLOUTS_VERSION=v1.10.2` |
| Playground for exercise 03 | `rollouts-lab` | |

Re-running it is safe.

## The learning loop

```
read README  →  read the YAML  →  run it unchanged (see it fail)  →  fill the TODO  →  ./check.sh  ✅
```

- Every exercise has a `check.sh` that prints `PASS` / `FAIL` and a hint.
- Stuck? Answers are in [`solutions/`](solutions/README.md). Try first, then compare.
- Each check uses `kubectl` only. The `argo` CLI is optional but nicer to use.

## Your answers stay local (git hook)

A pre-commit hook in `.githooks/` **blocks any commit that changes**
`exercises/*/workflow.yaml` or `exercises/*/rollout.yaml`, so you never push
your answers by accident. `setup/install.sh` enables it. To enable it by hand:

```bash
git config core.hooksPath .githooks
```

- Edit the exercise files freely; just don't commit them. To unstage one: `git restore --staged <file>`
- Start an exercise over: `git restore exercises/01-workflow-steps-and-parameters/workflow.yaml`
- Intentionally changing an exercise: `ALLOW_EXERCISE_EDITS=1 git commit ...`
- The hook is local: `git commit --no-verify` skips it, and GitHub does not enforce it.

## Command cheat sheet

Argo adds new resource types to Kubernetes, so plain `kubectl` works on them
just like on pods. The Argo CLIs add views that are easier to read.

### Find the Argo resource types (and their short names)

```bash
kubectl api-resources --api-group=argoproj.io
```

```
NAME                SHORTNAMES      KIND
workflows           wf              Workflow
workflowtemplates   wftmpl          WorkflowTemplate
cronworkflows       cwf,cronwf      CronWorkflow
rollouts            ro              Rollout
analysistemplates   at              AnalysisTemplate
analysisruns        ar              AnalysisRun
...
```

### Argo Workflows

| Goal | kubectl | argo CLI (`brew install argo`) |
|------|---------|--------------------------------|
| List workflows in a namespace | `kubectl get wf -n argo` | `argo list -n argo` |
| List in all namespaces | `kubectl get wf -A` | `argo list -A` |
| Only failed ones | `kubectl get wf -n argo -l workflows.argoproj.io/phase=Failed` | `argo list -n argo --status Failed` |
| Only running ones | `kubectl get wf -n argo -l workflows.argoproj.io/phase=Running` | `argo list -n argo --running` |
| Filter by your own label | `kubectl get wf -n argo -l exercise=02` | `argo list -n argo -l exercise=02` |
| Newest last | `kubectl get wf -n argo --sort-by=.metadata.creationTimestamp` | (already newest first) |
| Watch for changes | `kubectl get wf -n argo -w` | `argo watch -n argo @latest` |
| Step tree + failure messages | `kubectl get wf -n argo <name> -o yaml` (see `status.nodes`) | `argo get -n argo <name>` (or `@latest`) |
| Logs of every step | `kubectl logs -n argo -l workflows.argoproj.io/workflow=<name> -c main --prefix` | `argo logs -n argo <name>` |
| The pods behind a workflow | `kubectl get pods -n argo -l workflows.argoproj.io/workflow=<name>` | |
| Reusable / scheduled workflows | `kubectl get wftmpl,cwf -n argo` | `argo template list`, `argo cron list` |
| Delete a workflow | `kubectl delete wf -n argo <name>` | `argo delete -n argo <name>` |

Example (`argo list` adds duration and a cleaner status):

```
NAME                STATUS      AGE   DURATION   PRIORITY   MESSAGE
ci-pipeline-bjpsg   Failed      23m   30s        0
ci-pipeline-8l99b   Succeeded   25m   40s        0
```

`argo get` shows which step failed and why:

```
STEP                  TEMPLATE   PODNAME                                 DURATION  MESSAGE
 ✖ ci-pipeline-bjpsg  pipeline
 ├─✔ build            build      ci-pipeline-bjpsg-build-4047544995      5s
 ├─✖ lint             run-check  ci-pipeline-bjpsg-run-check-2823916388  3s        main: Error (exit code 1)
 ├─✔ unit-test        run-check  ci-pipeline-bjpsg-run-check-497967494   10s
```

Notes:

- `kubectl get wf --field-selector status.phase=Failed` does **not** work (the
  API server can't filter custom resources by status). Use the
  `workflows.argoproj.io/phase` label instead; the controller keeps it up to date.
- `kubectl logs` also prints Argo's own helper lines (`... argo=true`). Add
  `| grep -v 'argo=true'` to hide them, or use `argo logs`.

### Argo Rollouts

| Goal | kubectl | rollouts plugin (`kubectl argo rollouts ...`) |
|------|---------|-----------------------------------------------|
| List rollouts in a namespace | `kubectl get ro -n rollouts-lab` | `kubectl argo rollouts list rollouts -n rollouts-lab` |
| List in all namespaces | `kubectl get ro -A` | `kubectl argo rollouts list rollouts -A` |
| Live view: step, weight, stable/canary | | `kubectl argo rollouts get rollout <name> -n <ns> --watch` |
| Wait until done (scripts) | | `kubectl argo rollouts status <name> -n <ns> --timeout 120s` |
| Full spec + status | `kubectl get ro <name> -n <ns> -o yaml` | |
| Events / why it is stuck | `kubectl describe ro <name> -n <ns>` | |
| The ReplicaSets per version | `kubectl get rs -n <ns> -L rollouts-pod-template-hash` | |
| Change the image | edit YAML + `kubectl apply -f` | `kubectl argo rollouts set image <name> <container>=<image> -n <ns>` |
| Continue / go back to stable | | `kubectl argo rollouts promote <name> -n <ns>` / `abort <name> -n <ns>` |
| Web dashboard | | `kubectl argo rollouts dashboard` → <http://localhost:3100> |

Example (the plugin adds `STATUS`, `STEP` and `SET-WEIGHT`, which tell you how far a release has gone):

```
$ kubectl get ro -A
NAMESPACE      NAME            DESIRED   CURRENT   UP-TO-DATE   AVAILABLE   AGE
rollouts-lab   rollouts-demo   5         5         5            5           17m

$ kubectl argo rollouts list rollouts -A
NAMESPACE     NAME           STRATEGY   STATUS   STEP  SET-WEIGHT  READY  DESIRED  UP-TO-DATE  AVAILABLE
rollouts-lab  rollouts-demo  Canary     Healthy  4/4   100         5/5    5        5           5
```

### UIs

```bash
kubectl -n argo port-forward svc/argo-server 2746:2746   # Workflows UI: https://localhost:2746
kubectl argo rollouts dashboard                          # Rollouts UI:  http://localhost:3100
```

These commands work the same on any cluster that runs Argo (for example a
load-testing or CI platform built on Argo Workflows). Only the namespace and
`--context` change.

## Cleanup

```bash
./setup/teardown.sh         # delete exercise resources, keep Argo installed
./setup/teardown.sh --all   # delete the whole minikube cluster
```

## Repository layout

```
.githooks/    pre-commit, blocks commits of your answers
setup/        install.sh, teardown.sh
scripts/      lib.sh, shared helpers for the check scripts
docs/         concepts.md, the 5-minute mental model
exercises/    the three exercises (README + YAML with TODOs + check.sh)
solutions/    completed YAML for each exercise
```
