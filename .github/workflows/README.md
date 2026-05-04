# GitHub Actions Pipelines

This directory contains all CI/CD and platform provisioning workflows for the **MyApi** project, targeting Azure Container Apps (ACA) across **development**, **staging**, and **production** environments.

---

## Workflow Overview

| File | Purpose | Triggered by |
|---|---|---|
| [`application-ci.yml`](application-ci.yml) | Build, test, Sonar scan, push image, deploy | Push / PR to `development` or `main` |
| [`rollback.yml`](rollback.yml) | Manually restore a previous ACA revision | Manual dispatch only |
| [`provision.yml`](provision.yml) | Manual Terraform run — any environment | Manual dispatch only |
| [`development-Azure-Terraform.yml`](development-Azure-Terraform.yml) | Auto-provision development infrastructure | `infra/development/**` changes on `development` |
| [`staging-Azure-Terraform.yml`](staging-Azure-Terraform.yml) | Auto-provision staging infrastructure | `infra/staging/**` changes on `main` |
| [`production-Azure-Terraform.yml`](production-Azure-Terraform.yml) | Auto-provision production infrastructure | `infra/production/**` changes on `main` |
| [`drift.yml`](drift.yml) | Nightly drift check — all environments | Scheduled 01:00 UTC / manual |
| [`_shared-aca-terraform.yml`](_shared-aca-terraform.yml) | Reusable Terraform plan + apply | Called by Terraform workflows |
| [`_shared-cd.yml`](_shared-cd.yml) | Reusable ACA blue/green deploy | Called by `application-ci.yml` |

---

## Pipeline Architecture

### CI/CD Flow (Application)

```
Push to development                        Push to main
        │                                        │
        ▼                                        ▼
┌───────────────────────────────────────────────────────────┐
│                   build-test-scan                         │
│  dotnet restore → build → test → SonarCloud scan         │
│  upload TRX test results                                  │
└──────────────────────┬────────────────────────────────────┘
                       │ pass
                       ▼
              ┌─────────────────┐
              │   build-push    │  az acr build → push :sha + :semver tags
              │  (skipped PRs)  │
              └────────┬────────┘
            ┌──────────┴──────────┐
            │                     │
      development branch        main branch
            │                     │
            ▼                     ▼
     ┌────────────┐      ┌──────────────────┐
     │ deploy-dev │      │  deploy-staging  │  (auto, no gate)
     └────────────┘      └────────┬─────────┘
                                  │ pass
                                  ▼
                         ┌──────────────────────┐
                         │  deploy-production   │  (requires manual approval
                         └──────────────────────┘   via GitHub Environment gate)
```

Each deploy job calls `_shared-cd.yml`, which runs a zero-downtime blue/green deployment:

1. Deploy new revision at **0% traffic**
2. Poll `runningState` until healthy (up to 200 s)
3. Smoke test `/health/ready` and `/version` on the revision-specific FQDN
4. Shift **100% of ingress** to the new revision
5. Deactivate old revisions; retain the most recent for fast rollback
6. Auto-rollback on any failure in steps 1–4

### Infrastructure Flow (Terraform)

```
Automatic (push/PR)                        Manual
        │                                    │
        ├── development branch               │
        │   infra/development/** changed     │
        │           │                        │
        │           ▼                        │
        │   development-Azure-Terraform.yml  │
        │                                    ▼
        ├── main branch                 provision.yml
        │   infra/staging/** changed    (environment
        │           │                    selector)
        │           ▼                        │
        │   staging-Azure-Terraform.yml      │
        │                                    │
        └── main branch                      │
            infra/production/** changed      │
                    │                        │
                    ▼                        │
            production-Azure-Terraform.yml   │
                    │                        │
                    └──────────┬─────────────┘
                               ▼
                   _shared-aca-terraform.yml
                   1. Break orphaned state lock
                   2. terraform init
                   3. terraform fmt -check
                   4. terraform validate
                   5. terraform plan
                      ├── PR?   → post plan as PR comment, no apply
                      └── push? → apply only when changes detected (exit 2)
```

---

## Blue/Green Deployment Detail

| Phase | Description |
|---|---|
| **Deploy** | New revision created with target image at **0% ingress traffic** |
| **Health check** | Polls `properties.runningState` every 10 s, up to 200 s |
| **Smoke test** | Hits `/health/ready` and `/version` on the **revision-specific FQDN** — no real traffic involved |
| **Promote** | Atomically shifts **100% of ingress** to the new revision |
| **Cleanup** | Deactivates old revisions; the most recent old revision is **retained for fast rollback** |
| **Rollback** | If steps 1–4 fail, the new revision is **deactivated automatically** — traffic never leaves the previous revision |

### Manual Rollback

Use [`rollback.yml`](rollback.yml) — no inputs required:

1. Go to **Actions → Rollback ACA Revision → Run workflow**
2. Click **Run workflow**

The workflow identifies the live revision and the most recent previous active revision, shifts traffic, deactivates the bad revision, and enforces a maximum of 2 active revisions. It shares the `deploy-development` concurrency group with the CD workflow so a rollback and a deploy can never run simultaneously.

---

## Terraform State

Remote state is stored in Azure Blob Storage using OIDC authentication (no storage account keys required).

| Setting | Value |
|---|---|
| Storage account | `myapiterraformstate` |
| Container | `tfstate` |
| Auth method | OIDC via `ARM_USE_OIDC=true` |

| Environment | State key |
|---|---|
| development | `development/api.tfstate` |
| staging | `staging/api.tfstate` |
| production | `production/api.tfstate` |

Backend config is injected at `terraform init` time — there is no `backend.tf` with hardcoded values, keeping `_shared-aca-terraform.yml` environment-agnostic.

### State Lock

Azure Blob Storage uses lease-based locking. If a Terraform run crashes mid-apply, the lock may remain. The shared workflow breaks this lease pre-emptively on each run. All Terraform callers use `cancel-in-progress: false` to serialise runs and avoid interrupting a live apply.

---

## Infrastructure Drift Detection

[`drift.yml`](drift.yml) runs a nightly `terraform plan` against all three environments in parallel at **01:00 UTC**. It never applies changes.

| Exit code | Action |
|---|---|
| `0` — no changes | Closes any open drift issue for that environment |
| `1` — plan error | Opens / updates a GitHub Issue labelled `infrastructure-drift-<env>` |
| `2` — drift detected | Opens / updates a GitHub Issue labelled `infrastructure-drift-<env>` |

Issues are tracked per-environment using separate labels (`infrastructure-drift-development`, `infrastructure-drift-staging`, `infrastructure-drift-production`).

---

## GitHub Environments & Secrets

| GitHub Environment | Used by | Secrets required |
|---|---|---|
| `development` | CI deploy-dev, Terraform dev, drift dev | `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID` |
| `staging` | CI build-push (main), CI deploy-staging, Terraform staging | `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID` |
| `production` | CI deploy-production, Terraform production | `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID` |
| `environments-drift` | Drift checks (staging + production) | `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID` |

> **Production approval gate:** Configure **Required reviewers** on the `production` GitHub Environment in **Settings → Environments → production**. No workflow changes needed — the environment gate pauses `deploy-production` until approved.

### OIDC Federation Setup

Each environment's App Registration must have a federated credential for its subject:

| Workflow | GitHub Environment | Subject |
|---|---|---|
| CI build-push (development branch) | `development` | `repo:<org>/MyApi:environment:development` |
| CI build-push (main branch) | `staging` | `repo:<org>/MyApi:environment:staging` |
| CI deploy-dev | `development` | `repo:<org>/MyApi:environment:development` |
| CI deploy-staging | `staging` | `repo:<org>/MyApi:environment:staging` |
| CI deploy-production | `production` | `repo:<org>/MyApi:environment:production` |
| Terraform (development) | `development` | `repo:<org>/MyApi:environment:development` |
| Terraform (staging) | `staging` | `repo:<org>/MyApi:environment:staging` |
| Terraform (production) | `production` | `repo:<org>/MyApi:environment:production` |
| Drift (staging + production) | `environments-drift` | `repo:<org>/MyApi:environment:environments-drift` |

---

## Semantic Versioning

The version is defined in `MyApi.csproj` as the single source of truth:

```xml
<Version>1.2.0</Version>
```

| Change type | Bump |
|---|---|
| Breaking API change | MAJOR (`2.0.0`) |
| New feature, backwards-compatible | MINOR (`1.1.0`) |
| Bug fix | PATCH (`1.0.1`) |

### How it flows through the pipeline

| Artifact | Format | Example |
|---|---|---|
| ACR image (immutable) | `myapi:<full-sha>` | `myapi:abc123...` |
| ACR image (version pointer) | `myapi:<version>` | `myapi:1.2.0` |
| ACA revision suffix | `v<version dots→hyphens>-<7-char-sha>` | `v1-2-0-abc1234` |
| ACA revision name | `myapi--<suffix>` | `myapi--v1-2-0-abc1234` |

The SHA tag is immutable and used for all deployments. The version tag is a mutable pointer updated on every build — useful for identifying what's in ACR at a glance.

---

## Manual Triggers

### Re-deploy a specific image

Navigate to **Actions → CI – Build, Test & Deploy → Run workflow**, or via CLI:

```bash
gh workflow run application-ci.yml
```

### Run Terraform manually

Navigate to **Actions → Azure Provision - Manual → Run workflow** and select the target environment. To destroy, toggle the `destroy` input.

```bash
gh workflow run provision.yml \
  -f environment=development \
  -f destroy=false
```

### On-demand drift check

```bash
gh workflow run drift.yml
```

---

## Path Filters

| Workflow | Watches | Ignores |
|---|---|---|
| `application-ci.yml` | everything | `infra/**`, `.github/workflows/**` |
| `development-Azure-Terraform.yml` | `infra/development/**` | everything else |
| `staging-Azure-Terraform.yml` | `infra/staging/**` | everything else |
| `production-Azure-Terraform.yml` | `infra/production/**` | everything else |

Infrastructure changes never trigger an application build; application changes never trigger Terraform.

---

## Concurrency Controls

| Workflow | Group | Behaviour |
|---|---|---|
| CI deploy | `deploy-<env>` (per environment) | Queues; never cancels a running deploy |
| Terraform (auto) | `terraform-<env>-${{ github.ref }}` | Queues per branch; never cancels a running apply |
| Terraform (manual) | `terraform-<env>` | Queues per environment; never cancels a running apply |
| Drift check | `drift-check-<env>` (per environment) | Cancels a running scheduled check when superseded by a manual run |

All state-changing operations use `cancel-in-progress: false` to prevent a newer run from interrupting a partially complete apply.
