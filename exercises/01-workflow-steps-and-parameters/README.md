# Exercise 01: Your first workflow (steps and parameters)

**Time:** about 15 minutes · **Your job:** fill in 1 TODO (about 5 lines of YAML)

## What you will learn

- What a `Workflow` object looks like, and how Argo turns it into Pods.
- The two most common template types:
  - **container template**: runs one container (like a function).
  - **steps template**: calls other templates in order.
- How **parameters** pass values between templates.
- How to submit and watch a workflow, and read its logs.

## The idea in one picture

```
Workflow "hello-steps-abcde"
└── main (steps template)
    ├── group 1: say-hello   ──► Pod: busybox echo "Hello, Argo learner!"
    └── group 2: say-goodbye ──► Pod: busybox echo "Goodbye, Argo learner!"   ◄── you finish this
```

Each step becomes its own Pod. The workflow-controller (installed in the
`argo` namespace) starts them in the right order and records the result in
the Workflow's `status`.

## Steps

### 0. Point kubectl at minikube (do this first, every new terminal)

`kubectl` does not "know" about minikube by itself. It reads a config file
(`~/.kube/config`, the *kubeconfig*) that can hold many clusters, and it sends
every command to the **current context**.

| Word | Meaning | For this project |
|------|---------|------------------|
| **cluster** | An API server address plus its certificate | `minikube` (for example `https://127.0.0.1:59118`) |
| **user** (authinfo) | The credentials used to talk to it | `minikube` |
| **context** | A named pair: cluster + user (+ default namespace) | **`minikube`** ◄── the one you select |

`minikube start` creates all three entries, named after the **minikube profile**
(the default profile is `minikube`). It also switches your current context to
it. If you later switch to another cluster, you have to switch back yourself.

```bash
# Which context am I on right now?
kubectl config current-context            # expect: minikube

# List all contexts. The * marks the current one.
kubectl config get-contexts

# Switch to minikube
kubectl config use-context minikube

# Prove it: you should see ONE node called "minikube"
kubectl get nodes
# NAME       STATUS   ROLES           AGE   VERSION
# minikube   Ready    control-plane   ...   v1.35.x
```

Useful variants:

```bash
# Run one command against minikube WITHOUT changing the current context
kubectl --context minikube get pods -n argo

# Optional: make "argo" the default namespace of the minikube context,
# so you can skip "-n argo" in exercises 01 and 02
kubectl config set-context minikube --namespace=argo

# Context missing or broken (e.g. after "minikube delete")? Re-create it:
minikube start                     # creates/starts the cluster and the context
minikube update-context            # only rewrites the kubeconfig entry (new IP or port)

# Several minikube clusters? Each profile has its own context name:
minikube profile list              # PROFILE column = context name
```

> ⚠️ **Why this matters:** if your kubeconfig also holds work clusters, every
> `kubectl create`/`apply`/`delete` in these exercises goes to **whatever context
> is current**. Always run `kubectl config current-context` before you start.
> As a safety net, the `check.sh` scripts and `setup/teardown.sh` refuse to run
> unless the current context is `minikube` (to use another minikube profile,
> set `KUBE_CONTEXT=<profile>`).

### 1. Read `workflow.yaml`

Read it from top to bottom. Every line has a comment. Find the `TODO`.

### 2. Submit it before you change anything (you will see an error)

Pick the tool you prefer:

```bash
# Option A: the argo CLI (brew install argo)
argo submit -n argo --watch workflow.yaml

# Option B: plain kubectl
kubectl create -n argo -f workflow.yaml
kubectl get wf -n argo -w          # Ctrl+C when it stops changing
```

The workflow **fails**. Read why:

```bash
argo get -n argo @latest           # Option A
kubectl get wf -n argo -o wide     # Option B (see the MESSAGE column)
```

Expect a message like `inputs.parameters.message was not supplied`. The
`print-message` template declares a required input, and `say-goodbye`
does not give it one. Argo checks this before it starts any Pod.

### 3. Fix the TODO

Add an `arguments` block to `say-goodbye`. It should look like the one on
`say-hello`, with the message `Goodbye, {{workflow.parameters.name}}!`.

### 4. Run it again, with your own name this time

```bash
argo submit -n argo --watch workflow.yaml -p name=Pat
argo logs -n argo @latest
```

With kubectl only (it has no `-p`, so you get the default name):

```bash
kubectl create -n argo -f workflow.yaml
kubectl logs -n argo -l workflows.argoproj.io/workflow=<workflow-name> -c main --prefix
```

### 5. Verify

```bash
./check.sh
```

The check submits the workflow with `name=Checker` and confirms that both
messages print with that name.

## Look around (recommended)

- **UI:** `kubectl -n argo port-forward svc/argo-server 2746:2746`, then open
  <https://localhost:2746> and accept the self-signed certificate. Click your
  workflow to see the graph.
- **Pods:** `kubectl get pods -n argo -l workflows.argoproj.io/workflow`.
  There is one Pod per step, and each is `Completed`.
- **Status:** `kubectl get wf -n argo <name> -o yaml`. Look at `status.nodes`.
  This is where Argo records each step's phase and start and finish times.

## Bonus (optional, 2 minutes each)

1. Make both steps run **in parallel**: move `say-goodbye` into the same inner
   list as `say-hello`, so the two are in one group. Check the timestamps in the UI.
2. Add a third step that prints `I ran last` and runs after both.
3. Give the `message` input a default value (`value: "..."` under `inputs.parameters`)
   and remove the arguments from one step. What prints?

## Key takeaways

- A **Workflow** is a list of **templates** plus an **entrypoint**.
- `steps` uses a list of lists: the outer list runs in order, and the inner list runs in parallel.
- `{{workflow.parameters.X}}` and `{{inputs.parameters.X}}` are filled in by Argo
  before a Pod runs.
- Every step is a real Kubernetes Pod, so normal `kubectl` debugging still works.

Next: [Exercise 02: DAG pipelines](../02-workflow-dag/README.md)
