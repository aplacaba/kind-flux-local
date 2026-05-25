# Flux GitOps — Multi-Cluster with Flux Operator

Manage two local Kubernetes clusters (`dev`, `prod`) using the **Flux Operator** from
[controlplaneio-fluxcd](https://github.com/controlplaneio-fluxcd/flux-operator). The operator
bootstraps Flux CD on each cluster — no manual `flux bootstrap` commands needed.

## Architecture

```
┌─────────────────────────┐     ┌─────────────────────────┐
│  kind cluster "dev"     │     │  kind cluster "prod"    │
│                         │     │                         │
│  ┌───────────────────┐  │     │  ┌───────────────────┐  │
│  │ Flux Operator     │  │     │  │ Flux Operator     │  │
│  │ (Helm chart)      │  │     │  │ (Helm chart)      │  │
│  └────────┬──────────┘  │     │  └────────┬──────────┘  │
│           │             │     │           │             │
│  ┌────────▼──────────┐  │     │  ┌────────▼──────────┐  │
│  │ FluxInstance      │  │     │  │ FluxInstance      │  │
│  │ → creates Flux    │  │     │  │ → creates Flux    │  │
│  │   (source + kust  │  │     │  │   (source + kust  │  │
│  │    + helm + notif)│  │     │  │    + helm + notif)│  │
│  └────────┬──────────┘  │     │  └────────┬──────────┘  │
│           │             │     │           │             │
│  ┌────────▼──────────┐  │     │  ┌────────▼──────────┐  │
│  │ Flux syncs from   │  │     │  │ Flux syncs from   │  │
│  │ this git repo     │◄─┼─────┼──┤ this git repo     │  │
│  │ path: clusters/dev│  │     │  │ path: clusters/prod│  │
│  └───────────────────┘  │     │  └───────────────────┘  │
└─────────────────────────┘     └─────────────────────────┘
```

## Prerequisites

| Tool      | Version | Install                                     |
| --------- | ------- | ------------------------------------------- |
| kind      | ≥0.23   | `brew install kind` / `choco install kind`   |
| kubectl   | ≥1.28   | `brew install kubectl` / `choco install kubernetes-cli` |
| helm      | ≥3.14   | `brew install helm` / `choco install kubernetes-helm` |
| kustomize | ≥5      | `brew install kustomize`                    |
| Docker    | (any)   | Docker Desktop or Rancher Desktop            |

## Quickstart

```bash
# 1. Clone or init this repo
git clone <your-repo-url> && cd flux-gitops

# 2. Bootstrap everything (creates 2 kind clusters + installs Flux)
make setup

# 3. Verify Flux is running on both clusters
make verify
```

## What `make setup` does

1. **Initialises a local git repo** (required for Flux to sync)
2. **Creates 2 kind clusters** — `kind-dev` (port 30080) and `kind-prod` (port 30180)
3. **Installs the Flux Operator** on each cluster via Helm
4. **Creates a FluxInstance** on each cluster — the operator bootstraps Flux (source-controller, kustomize-controller, helm-controller, notification-controller) and configures it to sync from `clusters/<env>/` in this repo

## Per-cluster operations

```bash
make dev-only      # Bootstrap only the dev cluster
make prod-only     # Bootstrap only the prod cluster
```

## Day-2 operations

```bash
make verify        # Check Flux status on both clusters
make teardown      # Delete both kind clusters (clean slate)

# Individual cluster access
kubectl --context kind-dev get pods -A
kubectl --context kind-prod get pods -A

# Watch Flux reconciliation on dev
kubectl --context kind-dev -n flux-system get kustomizations --watch
```

## Customising the git repo URL

Edit `clusters/dev/flux-instance.yaml` and `clusters/prod/flux-instance.yaml` — replace
`<YOUR-ORG>/<YOUR-REPO>.git` with your actual git repository URL:

```yaml
spec:
  sync:
    url: https://github.com/my-org/my-infra.git
    branch: main
    path: clusters/dev   # or clusters/prod
    interval: 1m
```

After updating, the Flux instance will re-sync automatically. Changes made directly in
your git repo under `clusters/dev/` or `clusters/prod/` will be applied to the respective
cluster by Flux — that's GitOps.

## Forgejo on dev

The dev cluster includes a [Forgejo](https://forgejo.org/) instance (Git hosting + CI/CD via
Forgejo Actions) and a persistent Actions runner.

### Access

After bootstrapping, Forgejo is available at:

```
http://127.0.0.1:30090
```

Credentials: `forgejo-admin` / `admin123`

### Register the runner

The runner HelmRelease references a Kubernetes secret for the registration token. After first
login to Forgejo, create a runner token in the UI, then create the secret:

```bash
kubectl --context kind-dev create secret generic runner-secret \
  --namespace forgejo-runner \
  --from-literal=token=<your-runner-token>
```

Flux will detect the secret and the runner pod will start.

### Storage

Forgejo data is stored at `/data/forgejo` on the kind worker node (hostPath). This survives
pod restarts but not cluster deletion (`make teardown`).

## Troubleshooting

| Symptom | Check |
| ------- | ----- |
| `kind` not found | Install kind (see prerequisites) |
| Docker not running | Start Docker Desktop / Rancher Desktop |
| `kubectl` context errors | Run `kind get clusters` — do both exist? |
| FluxInstance not reconciling | `kubectl --context kind-dev describe fluxinstance -n flux-system flux` |
| No pods in flux-system | The operator takes ~60s to bootstrap Flux after the FluxInstance is created |

## Cleanup

```bash
make teardown
```
