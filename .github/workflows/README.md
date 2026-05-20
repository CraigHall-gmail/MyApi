# GitHub Actions Pipelines

This directory contains the CI/CD workflows for the **MyApi** application, targeting Azure Container Apps (ACA) across **development**, **staging**, and **production** environments.

> **Infrastructure as Code has moved.**
> Terraform modules, environment configurations, and infrastructure provisioning workflows (provision, drift detection) now live in the [**MyApi-Infra**](https://github.com/HallCraig/MyApi-Infra) repository.

---

## Workflow Overview

| File | Purpose | Triggered by |
|---|---|---|
| [`App-CI.yml`](App-CI.yml) | Build, test, Sonar scan, push image, deploy | Push / PR to `development`, `main`, `feature/**`, `hotfix/**` |
| [`App-Hotfix-Backmerge.yml`](App-Hotfix-Backmerge.yml) | Open back-merge PR from `main` → `development` after a hotfix ships | `hotfix/**` merged into `main` |
| [`App-Rollback.yml`](App-Rollback.yml) | Manually restore a previous ACA revision | Manual dispatch only |
| [`App-EF-Migrate.yml`](App-EF-Migrate.yml) | Run EF Core migrations against target database | Called by `_shared-cd.yml` |
| [`_shared-cd.yml`](_shared-cd.yml) | Reusable ACA blue/green deploy | Called by `App-CI.yml` |
| [`codeql.yml`](codeql.yml) | CodeQL security analysis | Push / PR / scheduled |

---

## Pipeline Architecture

### Branching Strategy

| Branch | PR target | CI behaviour |
|---|---|---|
| `feature/**` | `development` | test only — no build or deploy |
| `hotfix/**` | `main` | test only — no build or deploy |
| `development` | — | test → build → deploy-dev |
| `main` | — | test → build → deploy-staging → deploy-production |

### CI/CD Flow (Application)

```
Push to feature/** or hotfix/**            Push to development    Push to main
        │                                        │                     │
        ▼                                        ▼                     ▼
┌───────────────────────────────────────────────────────────────────────────────┐
│                           build-test-scan                                     │
│  dotnet restore → build → test → SonarCloud scan → upload TRX results        │
└───────────────────────────────┬───────────────────────────────────────────────┘
        │ (test only; no         │ pass (development / main only)
        │  build on feature/     ▼
        │  hotfix branches)  ┌─────────────────┐
        │                    │   build-push    │  az acr build → push :sha + :semver tags
        │                    └────────┬────────┘
        │                  ┌──────────┴──────────┐
        │                  │                     │
        │            development branch        main branch
        │                  │                     │
        ▼                  ▼                     ▼
      (done)        ┌────────────┐      ┌──────────────────┐
                    │ deploy-dev │      │  deploy-staging  │  (auto, no gate)
                    └────────────┘      └────────┬─────────┘
                                                 │ pass
                                                 ▼
                                        ┌──────────────────────┐
                                        │  deploy-production   │  (requires manual approval
                                        └──────────────────────┘   via GitHub Environment gate)
```

Each deploy job calls `_shared-cd.yml`, which runs a zero-downtime blue/green deployment:

1. Run EF Core migrations against the target database
2. Deploy new revision at **0% traffic**
3. Poll `runningState` until healthy (up to 200 s)
4. Smoke test `/health/ready` and `/version` on the revision-specific FQDN
5. Shift **100% of ingress** to the new revision
6. Deactivate old revisions; retain the most recent for fast rollback
7. Auto-rollback on any failure in steps 2–4

---

## Blue/Green Deployment Detail

| Phase | Description |
|---|---|
| **Migrate** | EF Core migrations run against the target database before any new revision starts |
| **Deploy** | New revision created with target image at **0% ingress traffic** |
| **Health check** | Polls `properties.runningState` every 10 s, up to 200 s |
| **Smoke test** | Hits `/health/ready` and `/version` on the **revision-specific FQDN** — no real traffic involved |
| **Promote** | Atomically shifts **100% of ingress** to the new revision |
| **Cleanup** | Deactivates old revisions; the most recent old revision is **retained for fast rollback** |
| **Rollback** | If steps 2–4 fail, the new revision is **deactivated automatically** — traffic never leaves the previous revision |

### Hotfix Flow

```
hotfix/1.2.1 (branched from main)
        │
        │  push → CI runs tests only
        │
        ▼
   PR → main
        │  merged → CI builds, deploys staging → production
        │
        ├──► v1.2.1 git tag created automatically
        │
        └──► App-Hotfix-Backmerge.yml fires
                  │
                  ▼
             backmerge/hotfix/1.2.1 (branch created from main)
                  │
                  ▼
             PR → development  (opened automatically; resolve conflicts if any)
```

The back-merge PR must be reviewed and merged manually. If `development` has diverged, conflicts appear directly in the PR for resolution before merging.

---

### Manual Rollback

Use [`App-Rollback.yml`](App-Rollback.yml):

1. Go to **Actions → App - Rollback → Run workflow**
2. Select the target environment
3. Click **Run workflow**

The workflow identifies the live revision and the most recent previous active revision, shifts traffic, deactivates the bad revision, and enforces a maximum of 2 active revisions. It shares the `deploy-<env>` concurrency group with the CD workflow so a rollback and a deploy can never run simultaneously.

---

## GitHub Environments & Secrets

| GitHub Environment | Used by | Secrets required |
|---|---|---|
| `development` | CI deploy-dev | `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID` |
| `build` | CI build-push (main branch) | `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID` |
| `staging` | CI deploy-staging | `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID` |
| `production` | CI deploy-production | `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID` |

> **Production approval gate:** Configure **Required reviewers** on the `production` GitHub Environment in **Settings → Environments → production**. No workflow changes needed — the environment gate pauses `deploy-production` until approved.

### OIDC Federation Setup

Each environment's App Registration must have a federated credential for its subject:

| Workflow | GitHub Environment | Subject |
|---|---|---|
| CI build-push (development branch) | `development` | `repo:<org>/MyApi:environment:development` |
| CI build-push (main branch) | `build` | `repo:<org>/MyApi:environment:build` |
| CI deploy-dev | `development` | `repo:<org>/MyApi:environment:development` |
| CI deploy-staging | `staging` | `repo:<org>/MyApi:environment:staging` |
| CI deploy-production | `production` | `repo:<org>/MyApi:environment:production` |

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

The SHA tag is immutable and used for all deployments. The version tag is a mutable pointer updated on every build.

---

## Manual Triggers

### Re-deploy a specific image

Navigate to **Actions → App - CI (Build, Test & Deploy) → Run workflow**, or via CLI:

```bash
gh workflow run App-CI.yml
```

### Roll back an environment

Navigate to **Actions → App - Rollback → Run workflow** and select the target environment.

```bash
gh workflow run App-Rollback.yml -f environment=development
```

---

## Path Filters

| Workflow | Watches | Ignores |
|---|---|---|
| `App-CI.yml` | everything | `.github/workflows/**` |

---

## Concurrency Controls

| Workflow | Group | Behaviour |
|---|---|---|
| CI deploy | `deploy-<env>` (per environment) | Queues; never cancels a running deploy |

All deployments use `cancel-in-progress: false` to prevent a newer run from interrupting a partially complete deploy.

---

## Infrastructure

Infrastructure provisioning, Terraform modules, and drift detection have moved to the [**MyApi-Infra**](https://github.com/HallCraig/MyApi-Infra) repository. The `_shared-terraform-planapply.yml` file in this directory is a leftover from the migration and can be removed once confirmed no longer needed.
