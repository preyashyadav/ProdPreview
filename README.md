# ProdPreview

Production-like preview environments for every PR. This repo deploys a React frontend, Node.js API, and Python worker into per-PR Kubernetes namespaces using Argo CD + GitHub Actions.

**Core idea**: PR opens → build/push images tagged by PR head SHA → Argo CD deploys `pr-<number>` namespace → review in a production-like cluster → merge to `main`.

## Repo Layout

- `services/api/` Node.js + Express API
- `services/frontend/` React + Vite UI + Express server (`/health.json`)
- `services/worker/` Python worker that polls the API
- `deploy/helm/services/` Source Helm charts for each service
- `deploy/helm/app/` Umbrella chart used by Argo CD (vendored subcharts in `charts/`)
- `deploy/argocd/` Argo CD ApplicationSet for PR previews
- `infra/terraform/` AWS VPC + EKS + RDS
- `scripts/sync-helm-charts.sh` Sync service charts into the umbrella chart

## Preview Flow (PR Environments)

1. **PR opened/updated** → GitHub Actions builds and pushes images with tag `PR_HEAD_SHA`.
2. **Argo CD ApplicationSet** watches PRs and deploys `deploy/helm/app` into `pr-<number>` namespace.
3. **Frontend service** is `LoadBalancer` in preview. Get the external IP with:

```bash
kubectl -n pr-<number> get svc frontend
```

## Setup

### 1) Docker Hub

Create Docker Hub repos:
- `preyash29/prod-preview-api`
- `preyash29/prod-preview-frontend`
- `preyash29/prod-preview-worker`

Add GitHub Actions secrets in your repo:
- `DOCKERHUB_USERNAME`
- `DOCKERHUB_TOKEN`

### 1b) Local Env Files

Copy env templates if you run services locally:

```bash
cp services/api/.env.example services/api/.env
cp services/frontend/.env.example services/frontend/.env
cp services/worker/.env.example services/worker/.env
```

### 2) Argo CD

Install Argo CD in your cluster (namespace `argocd` assumed).

Create a GitHub token (read access to the repo) and store it in a secret for ApplicationSet:

```bash
kubectl -n argocd create secret generic github-token \
  --from-literal=token=YOUR_GITHUB_TOKEN
```

Apply the ApplicationSet:

```bash
kubectl apply -f deploy/argocd/applicationset-preview.yaml
```

If your Argo CD namespace is not `argocd`, update:
- `deploy/argocd/applicationset-preview.yaml`

### 3) Keep Helm Charts In Sync

The umbrella chart uses vendored subcharts. If you modify charts under `deploy/helm/services/`, run:

```bash
./scripts/sync-helm-charts.sh
```

## How It Works

- **Terraform** creates your AWS network, database, and EKS cluster. (`infra/terraform/`)
- **Docker** builds images for each service and pushes to Docker Hub.
- **Argo CD** deploys per-PR environments using the umbrella chart in `deploy/helm/app`.

## Diagram

![ProdPreview Flowchart](flowchart.png)
