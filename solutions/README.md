# Solutions

Try the exercise first. These are the completed files. Each change is marked
with a `SOLUTION` comment.

Compare your work with the solution:

```bash
diff exercises/01-workflow-steps-and-parameters/workflow.yaml solutions/01-workflow-steps-and-parameters/workflow.yaml
diff exercises/02-workflow-dag/workflow.yaml                  solutions/02-workflow-dag/workflow.yaml
diff exercises/03-rollout-canary/rollout.yaml                 solutions/03-rollout-canary/rollout.yaml
```

The workflow check scripts can run a solution directly:

```bash
exercises/01-workflow-steps-and-parameters/check.sh ../../solutions/01-workflow-steps-and-parameters/workflow.yaml
exercises/02-workflow-dag/check.sh ../../solutions/02-workflow-dag/workflow.yaml
```

The file path is relative to the exercise folder, because each check script
changes into its own directory first.
