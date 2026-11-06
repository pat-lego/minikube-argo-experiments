# The minikube cluster: what it is and how to run it

## What minikube is

- **minikube** runs a complete, single-node Kubernetes cluster on your laptop.
- On macOS it uses the **Docker driver**: the whole "server" is **one Docker
  container** named `minikube`. Inside it run the Kubernetes API server, the
  kubelet, and every Pod you create.
- Nothing runs in the cloud. Deleting the container deletes the cluster.

```
your Mac
└── Docker Desktop
    └── container "minikube"          ← the Kubernetes "server" (one node)
        ├── kube-apiserver, etcd, scheduler, ...
        ├── namespace argo            ← Argo Workflows (installed by setup/install.sh)
        ├── namespace argo-rollouts   ← Argo Rollouts controller
        └── namespace rollouts-lab    ← exercise 03
```

`kubectl` on your Mac talks to that API server through the `minikube` context
in `~/.kube/config` (see [exercise 01, step 0](../exercises/01-workflow-steps-and-parameters/README.md#0-point-kubectl-at-minikube-do-this-first-every-new-terminal)).

## First-time setup

1. Install the tools:
   ```bash
   brew install minikube kubectl argo argoproj/tap/kubectl-argo-rollouts
   ```
2. Start **Docker Desktop** and wait until it says it is running.
   - Give Docker enough resources: Docker Desktop → Settings → Resources,
     at least **4 CPUs and 8 GB of memory** (minikube asks for 6 GB of it).
3. Create the cluster and install Argo:
   ```bash
   ./setup/install.sh
   ```
   It runs `minikube start --cpus=4 --memory=6g` if no cluster is running,
   then installs Argo Workflows and Argo Rollouts. The first start downloads
   about 1 GB of images and takes a few minutes; later starts take about 30 seconds.
4. Check it:
   ```bash
   minikube status
   kubectl get nodes          # one node called "minikube", STATUS Ready
   kubectl get pods -n argo             # workflow-controller, argo-server: Running
   kubectl get pods -n argo-rollouts    # argo-rollouts: Running
   ```

   ```
   $ minikube status
   minikube
   type: Control Plane
   host: Running
   kubelet: Running
   apiserver: Running
   kubeconfig: Configured
   ```

## Day-to-day commands

| Goal | Command | Notes |
|------|---------|-------|
| Is it running? | `minikube status` | `host: Stopped` means you need to start it |
| Start (or resume) the cluster | `minikube start` | Keeps everything you installed: Argo, workflows, rollouts |
| Pause it to free CPU/RAM | `minikube stop` | The container stops; nothing is lost |
| Delete everything | `minikube delete` (or `./setup/teardown.sh --all`) | Run `./setup/install.sh` to rebuild from scratch |
| Open a shell on the "server" | `minikube ssh` | You are inside the node container |
| List clusters (profiles) | `minikube profile list` | Each profile is a separate cluster and context |
| See the container | `docker ps --filter name=minikube` | |
| Fix kubectl after an IP/port change | `minikube update-context` | Rewrites the `minikube` entry in `~/.kube/config` |

> CPU and memory are only set when the cluster is **created**. To change them:
> `minikube delete`, then `minikube start --cpus=4 --memory=6g` (or `./setup/install.sh`).

## Reaching apps in the cluster from your Mac

Pods get IPs inside the minikube container, which your Mac cannot reach directly.
Three ways in:

| Method | Example | Load-balances across pods? |
|--------|---------|----------------------------|
| `kubectl port-forward` | `kubectl -n argo port-forward svc/argo-server 2746:2746` | **No.** It picks one pod. Fine for UIs with a single pod. |
| `minikube service` (needs a NodePort Service) | `minikube service <svc> -n <ns>` | Yes, per connection. Keep the terminal open on macOS. |
| From inside the cluster | `kubectl run tmp --rm -i --image=busybox:1.36 -- wget -qO- http://<svc>.<ns>` | Yes, per request. This is what `watch-traffic.sh` does. |

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| `Cannot connect to the Docker daemon` | Start Docker Desktop. |
| `The connection to the server ... was refused` | The cluster is stopped: `minikube start`. Or you are on another context: `kubectl config use-context minikube`. |
| `minikube status` shows an error for a profile | That profile's container was removed. `minikube delete -p <profile>` cleans it up. |
| Pods stuck `Pending` | Not enough CPU/memory. Check `kubectl describe pod <pod>` (Events), then give Docker and minikube more resources. |
| `ImagePullBackOff` | Check your internet/VPN; minikube pulls images from Docker Hub. |
| Rollouts dashboard stuck on **Loading...** | It opened on the `default` namespace, which has no rollouts. Type `rollouts-lab` in the NAMESPACE box, or start it with `kubectl argo rollouts dashboard -n rollouts-lab`. |
