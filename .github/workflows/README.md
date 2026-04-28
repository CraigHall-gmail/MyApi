# GitHub Actions Pipelines

This directory contains all CI/CD and platform provisioning workflows for the **MyApi** project targeting the **development** environment on Azure Container Apps (ACA).

---

## Workflow Overview

| File | Purpose | Triggered by |
|---|---|---|
| [`development-CI.yml`](development-CI.yml) | Build, test, push image to ACR | Push / PR to `development` |
| [`development-CD.yml`](development-CD.yml) | Blue/green deploy to ACA | CI workflow or manual dispatch |
| [`development-Platform-Terraform.yml`](development-Platform-Terraform.yml) | Provision Azure infrastructure | `infra/development/**` changes or manual |
| [`_shared-aca-dev.yml`](_shared-aca-dev.yml) | Reusable Terraform plan + apply | Called by Terraform workflow |

---

## Pipeline Architecture

### CI/CD Flow (Application)

```
Push to development branch
        │
        ▼
┌───────────────┐
│   test job    │  dotnet restore → build → test → upload TRX results
└──────┬────────┘
       │ pass
       ▼
┌───────────────┐
│  build-push   │  az acr build → push image tagged with full git SHA
│     job       │  (skipped on pull requests)
└──────┬────────┘
       │ outputs: image-tag (SHA)
       ▼
┌───────────────┐
│  deploy job   │  calls development-CD.yml ──────────────────────────────┐
└───────────────┘                                                          │
                                                                           ▼
                                                          ┌────────────────────────────┐
                                                          │  Blue/Green Deploy (ACA)   │
                                                          │                            │
                                                          │  1. Deploy green @ 0%      │
                                                          │  2. Wait for Running state │
                                                          │  3. Smoke test /health     │
                                                          │  4. Promote to 100%        │
                                                          │  5. Deactivate old revs    │
                                                          │  6. Rollback on failure    │
                                                          └────────────────────────────┘
```

### Infrastructure Flow (Terraform)

```
Push to development (infra/development/** changed)
        │
        ▼
┌────────────────────────────────┐
│  development-Platform-         │
│  Terraform.yml                 │
│                                │
│  calls _shared-aca-dev.yml     │
└────────────────┬───────────────┘
                 │
                 ▼
┌────────────────────────────────┐
│  _shared-aca-dev.yml           │
│                                │
│  1. Break orphaned state lock  │
│  2. terraform init             │  ◄── backend config injected at runtime
│  3. terraform fmt -check       │
│  4. terraform validate         │
│  5. terraform plan             │
│     ├── PR? → post to PR       │  ◄── plan only, no apply on PRs
│     └── push? → apply          │  ◄── apply only when changes detected
└────────────────────────────────┘
```

---

## Blue/Green Deployment Detail

The CD workflow uses Azure Container Apps' built-in revision model to implement zero-downtime blue/green deployments.

| Phase | Description |
|---|---|
| **Deploy** | New revision created with target image at **0% ingress traffic** |
| **Health check** | Polls `properties.runningState` every 10 s, up to 200 s |
| **Smoke test** | Hits `/health/ready` and `/version` on the **revision-specific FQDN** — no real traffic involved |
| **Promote** | Atomically shifts **100% of ingress** to the green revision |
| **Cleanup** | Deactivates old revisions; the most recent old revision is **retained for fast rollback** |
| **Rollback** | If steps 1–4 fail, the green revision is **deactivated automatically** — traffic never leaves the previous revision. Step 5 (cleanup) uses `continue-on-error` so a housekeeping failure after a successful promotion does not roll back a live revision |

### Manual Rollback

If a bad deploy is detected after promotion, reactivate the retained old revision:

```bash
# List active revisions
az containerapp revision list \
  --name myapi \
  --resource-group rg-myapi-dev \
  --query "[?properties.active].{name:name, created:properties.createdTime, traffic:properties.trafficWeight}" \
  --output table

# Shift traffic back to the previous revision
az containerapp ingress traffic set \
  --name myapi \
  --resource-group rg-myapi-dev \
  --revision-weight <previous-revision-name>=100
```

---

## Terraform State

Remote state is stored in Azure Blob Storage using OIDC authentication (no storage account keys required).

| Setting | Value |
|---|---|
| Storage account | `myapiterraformstate` |
| Container | `tfstate` |
| State key | `development/api.tfstate` |
| Auth method | OIDC via `ARM_USE_OIDC=true` |

Backend config is injected at `terraform init` time — there is no `backend.tf` file with hardcoded values, making the shared workflow reusable across environments.

### State Lock

Azure Blob Storage uses lease-based locking. If a Terraform run crashes mid-apply, the lock may remain. The shared workflow breaks this lease pre-emptively on each run. The Terraform caller enforces a concurrency group (`cancel-in-progress: false`) to serialise runs and minimise the chance of a live run being interrupted.

---

## GitHub Secrets Required

All secrets are scoped to the **`development`** GitHub environment.

| Secret | Description |
|---|---|
| `AZURE_CLIENT_ID` | App Registration client ID configured for OIDC federation |
| `AZURE_TENANT_ID` | Azure AD tenant ID |
| `AZURE_SUBSCRIPTION_ID` | Azure subscription ID containing all resources |

### OIDC Federation Setup

The App Registration must have a federated credential for each subject that requires Azure access:

| Workflow | Subject |
|---|---|
| CI build-push job | `repo:<org>/MyApi:environment:development` |
| CD deploy job | `repo:<org>/MyApi:environment:development` |
| Terraform apply | `repo:<org>/MyApi:environment:development` |

---

## Image Naming

Images are tagged with the **full Git SHA** and pushed to ACR:

```
acrimagereg.azurecr.io/myapi:<full-40-char-git-sha>
```

The `latest` tag is intentionally not pushed. Every deployment references an immutable SHA tag, which guarantees:
- Full traceability from deployment back to commit
- Safe rollbacks to any previous SHA
- No ambiguity when multiple deploys occur in quick succession

---

## Manual Triggers

### Re-deploy a specific image

Navigate to **Actions → development CD - Blue/Green Deploy to ACA → Run workflow** and enter the full Git SHA of the image to deploy.

```bash
# Or trigger via GitHub CLI
gh workflow run development-CD.yml \
  -f image_sha=<full-git-sha>
```

### Run Terraform manually

Navigate to **Actions → development - Platform Terraform Provision → Run workflow**.

To destroy infrastructure, set the `destroy` input to `true`. This is a manual-only action — destroy is never triggered automatically.

```bash
gh workflow run "development-Platform-Terraform.yml" \
  -f destroy=false
```

---

## Path Filters

| Workflow | Watches | Ignores |
|---|---|---|
| CI | everything | `infra/**` |
| Terraform | `infra/development/**` | everything else |

This ensures infrastructure changes never trigger an application build, and application changes never trigger Terraform.

---

## Concurrency Controls

| Workflow | Group | Behaviour |
|---|---|---|
| CD | `deploy-development` | Queues; never cancels a running deploy |
| Terraform | `terraform-${{ github.ref }}` | Queues per branch; never cancels a running apply |

Both use `cancel-in-progress: false` to prevent a newer run from interrupting a partially complete state-changing operation.
