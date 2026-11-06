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

## Handy commands

```bash
# Argo Workflows
argo list -n argo                         # list workflows
argo get -n argo @latest                  # tree view of the latest workflow
argo logs -n argo @latest                 # logs of all its steps
kubectl -n argo port-forward svc/argo-server 2746:2746   # UI at https://localhost:2746

# Argo Rollouts
kubectl argo rollouts get rollout rollouts-demo -n rollouts-lab --watch
kubectl argo rollouts dashboard           # UI at http://localhost:3100
```

## Cleanup

```bash
./setup/teardown.sh         # delete exercise resources, keep Argo installed
./setup/teardown.sh --all   # delete the whole minikube cluster
```

## Repository layout

```
setup/        install.sh, teardown.sh
scripts/      lib.sh, shared helpers for the check scripts
docs/         concepts.md, the 5-minute mental model
exercises/    the three exercises (README + YAML with TODOs + check.sh)
solutions/    completed YAML for each exercise
```
