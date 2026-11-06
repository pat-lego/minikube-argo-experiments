# Exercise 02: A CI pipeline as a DAG

**Time:** about 15 minutes · **Your job:** fill in 2 TODOs (2 lines of YAML)

## What you will learn

- The **DAG** template: you declare dependencies, and Argo works out what can run in parallel.
- **Output parameters**: one task produces a value, and a later task uses it.
- Why Argo is a good fit for pipelines such as CI, data processing, and load tests.

## The pipeline

```
               ┌──► unit-test (8s) ──┐
   build ──────┤                     ├──► deploy  (needs build's version)
               └──► lint (8s) ───────┘
```

## Steps vs. DAG (when to use which)

| `steps` (exercise 01)              | `dag` (this exercise)                         |
|------------------------------------|-----------------------------------------------|
| You write the order explicitly     | You write dependencies; Argo works out the order |
| Good for short, linear scripts     | Good for graphs with fan-out and fan-in       |
| `{{steps.NAME.outputs...}}`        | `{{tasks.NAME.outputs...}}`                   |

## Steps

### 1. Read `workflow.yaml`

Focus on the `pipeline` template (the wiring) and the `outputs` section of
`build` (how a file becomes an output parameter).

### 2. Submit it as-is and watch it fail

```bash
argo submit -n argo --watch workflow.yaml
# or: kubectl create -n argo -f workflow.yaml && kubectl get wf -n argo -w
```

Without `depends`, `deploy` starts **immediately**, at the same time as `build`,
and its version is the literal text `TODO`, so it exits with an error. Look at it:

```bash
argo logs -n argo @latest
```

### 3. Fix TODO 1: the dependency

Make `deploy` wait for both checks:

```yaml
depends: "unit-test && lint"
```

`depends` is a small boolean expression. You can also write
`unit-test.Succeeded || lint.Failed`, and so on, which is useful for cleanup tasks.

### 4. Fix TODO 2: use the build output

Replace `"TODO"` with a reference to the build task's output parameter
(see the comment in the file for the syntax).

> Note: Argo only lets a task read outputs from tasks it **depends on**,
> directly or indirectly. If you do TODO 2 without TODO 1, the workflow fails
> straight away with: `missing dependency 'build' for parameter 'version'`.

### 5. Verify

```bash
./check.sh
```

The check confirms three things: the workflow succeeded, `deploy` started only
after both checks *finished* (it reads the timestamps in `status.nodes`), and the
version reached `deploy`.

## Look around (recommended)

- In the UI (<https://localhost:2746>), open the workflow. `unit-test` and `lint`
  run side by side.
- Click the `build` node and open the **Outputs** tab. You can see the `version` value.
- `argo get -n argo @latest` prints the same tree in the terminal with durations.

## Bonus (optional)

1. Make `lint` fail (`exit 1`) and run it again. What happens to `deploy`? (It is
   *Omitted*, because its dependency failed.)
2. Add a `notify` task with `depends: "deploy.Succeeded || deploy.Failed"` so it
   always runs at the end.
3. Add a `retryStrategy: {limit: 2}` to `run-check`, make it fail randomly, and
   watch Argo retry it.

## Key takeaways

- A `dag` is made of tasks plus `depends`. Argo runs everything it can, as early as it can.
- `outputs.parameters` (often read from a file) is how data moves between tasks.
- Data references follow dependencies: you can only read from tasks you depend on.
- This is the same pattern real platforms use when they *generate* Argo Workflows
  (CI systems, ML pipelines, load-test orchestrators).

Next: [Exercise 03: Canary release with Argo Rollouts](../03-rollout-canary/README.md)
