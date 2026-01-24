# Titanic API - DevOps Assessment Solution

## Architecture Overview

```
[TODO: Add architecture diagram]
```

## Project Structure

```
titanic-devops-assessment/
├── app/                      # Python Flask API
├── docker/                   # Dockerfiles (dev/prod)
├── k8s/                      # Kubernetes manifests
│   ├── base/                 # Base manifests
│   └── overlays/             # Kustomize overlays
│       ├── dev/
│       ├── staging/
│       └── prod/
├── helm/                     # Helm chart (bonus)
├── terraform/                # AWS Infrastructure as Code
│   ├── modules/
│   └── environments/
├── monitoring/               # Prometheus, Grafana configs
├── .github/workflows/        # CI/CD pipelines
├── docs/                     # Documentation, runbooks
└── scripts/                  # Utility scripts
```

## Cloud Provider
**AWS** - Using EKS, RDS (PostgreSQL), VPC, ALB

## Part 1: Containerization & Local Development

### Multi-Stage Dockerfile

**Why Multi-Stage Builds?**
- **Smaller Images**: Final image ~150MB vs ~800MB with build tools
- **Security**: No compilers/build tools in production = smaller attack surface
- **Faster Deployments**: Smaller images pull faster in CI/CD

**Stage 1 - Builder:**
```dockerfile
FROM python:3.11-slim AS builder
# Install gcc, libpq-dev for compiling Python packages
# Dependencies installed to /root/.local with --user flag
```

**Stage 2 - Production:**
```dockerfile
FROM python:3.11-slim AS production
# Only runtime deps (libpq5, curl for healthcheck)
# Copy pre-built packages from builder stage
```

### Security Best Practices

| Practice | Implementation | Why |
|----------|---------------|-----|
| Non-root user | `appuser` (UID 1000) | Limits container escape damage |
| Slim base image | `python:3.11-slim` | Fewer CVEs, smaller attack surface |
| No cache | `--no-cache-dir` | Reduces image size |
| Cleanup apt | `rm -rf /var/lib/apt/lists/*` | Removes package cache (~50MB saved) |

### Health Checks

**Dockerfile:**
```dockerfile
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:5000/ || exit 1
```

**Docker Compose:**
```yaml
healthcheck:
  test: ["CMD-SHELL", "pg_isready -U titanic -d titanic_db"]
  interval: 10s
  timeout: 5s
  retries: 5
```

**Why Health Checks?**
- Kubernetes/Docker knows when containers are truly ready
- Prevents routing traffic to unhealthy instances
- Enables automatic container restarts on failure

### Docker Compose Configuration

**Service Dependencies:**
```yaml
depends_on:
  db:
    condition: service_healthy
```
- App waits for DB to be healthy, not just started
- Prevents connection errors during startup

**Environment Variables:**
- Uses `${VAR:-default}` syntax for flexibility
- Secrets can be overridden via `.env` file or CI/CD

## Part 2: CI/CD Pipeline

### Shift-Left Security Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│              CI/CD Pipeline Flow (Sequential Gates)             │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  Stage 1: ┌──────────┐                                         │
│           │ Gitleaks │ ── Secrets found? ──▶ STOP              │
│           │ Secrets  │                                         │
│           └────┬─────┘                                         │
│                │ ✓                                              │
│  Stage 2: ┌────▼─────┐                                         │
│           │ Checkov  │ ── IaC issues? ──▶ STOP                 │
│           │   IaC    │                                         │
│           └────┬─────┘                                         │
│                │ ✓                                              │
│  Stage 3: ┌────▼─────┐                                         │
│           │SonarCloud│ ── Quality gate failed? ──▶ STOP        │
│           │  SAST    │                                         │
│           └────┬─────┘                                         │
│                │ ✓                                              │
│  Stage 4: ┌────▼─────┐                                         │
│           │  Tests   │ ── Coverage < 70%? ──▶ STOP             │
│           │  & Lint  │                                         │
│           └────┬─────┘                                         │
│                │ ✓                                              │
│  Stage 5: ┌────▼─────┐                                         │
│           │  Build   │                                         │
│           │  Image   │                                         │
│           └────┬─────┘                                         │
│                │ ✓                                              │
│  Stage 6: ┌────▼─────┐                                         │
│           │  Trivy   │ ── CRITICAL/HIGH CVEs? ──▶ STOP         │
│           │  Image   │                                         │
│           └────┬─────┘                                         │
│                │ ✓                                              │
│  Stage 7: ┌────▼─────┐     ┌──────────┐     ┌────────────┐    │
│           │   Dev    │ ──▶ │ Staging  │ ──▶ │ Production │    │
│           │  (auto)  │     │  (auto)  │     │ (approval) │    │
│           └──────────┘     └──────────┘     └─────┬──────┘    │
│                                                   │            │
│                                          Health check failed?  │
│                                                   │            │
│                                          ┌────────▼────────┐   │
│                                          │ AUTO ROLLBACK   │   │
│                                          └─────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
```

### Reusable Workflows (Shift-Left)

All security scans use reusable workflows from `shared-gh-workflows` repo:

| Workflow | Purpose | When it Fails |
|----------|---------|---------------|
| **Gitleaks** | Detects hardcoded secrets/credentials | Secrets found in code |
| **Checkov** | Scans Dockerfile, K8s, Terraform for misconfigs | IaC security issues |
| **Trivy** | Scans filesystem & images for CVEs | CRITICAL/HIGH vulnerabilities |
| **SonarCloud** | Code quality, bugs, code smells, SAST | Quality gate failed |

**Why Reusable Workflows?**
- DRY principle - define once, use everywhere
- Centralized security policy updates
- Consistent scanning across all repositories

### Pipeline Stages (Sequential)

| Stage | Gate | Fails If |
|-------|------|----------|
| 1. Gitleaks | Secret Detection | Hardcoded secrets/credentials found |
| 2. Checkov | IaC Security | Dockerfile/K8s/Terraform misconfigs |
| 3. SonarCloud | Quality Gate | Coverage < 70%, bugs, code smells |
| 4. Tests & Lint | Coverage | `--cov-fail-under=70`, flake8, black |
| 5. Build | Docker Build | Build errors |
| 6. Trivy | Image Scan | CRITICAL/HIGH CVEs in image |
| 7a. Dev | Deploy | `develop` branch only |
| 7b. Staging | Deploy | `main` branch only |
| 7c. Production | Manual Approval | Requires reviewer approval |

### Automated Rollback

Production deployments include:
1. Store current revision before deploy
2. Deploy new version
3. Health check (30s wait, verify pods Running)
4. If health check fails → `kubectl rollout undo` to previous revision

### Semantic Versioning

```yaml
tags: |
  type=ref,event=branch      # main, develop
  type=semver,pattern={{version}}  # v1.2.3
  type=sha,prefix=           # abc1234
```

### Secrets Management

#### GitHub Repository Secrets (Settings → Secrets and variables → Actions)

| Secret | Purpose | How to Obtain |
|--------|---------|---------------|
| `GITHUB_TOKEN` | GHCR access, PR comments | Auto-provided by GitHub Actions |
| `SONAR_TOKEN` | SonarCloud authentication | [SonarCloud](https://sonarcloud.io) → My Account → Security → Generate Token |
| `SLACK_WEBHOOK_URL` | Deployment notifications | [Slack API](https://api.slack.com/apps) → Create App → Incoming Webhooks |

#### GitHub Environment Secrets (Settings → Environments)

Create three environments: `development`, `staging`, `production`

| Environment | Secret | Protection Rules |
|-------------|--------|------------------|
| development | `KUBECONFIG` | None |
| staging | `KUBECONFIG` | None |
| production | `KUBECONFIG` | Required reviewers, wait timer (optional) |

> **Note:** Each environment has its own `KUBECONFIG` secret pointing to its respective cluster. The pipeline uses `${{ secrets.KUBECONFIG }}` which automatically resolves to the correct environment's secret based on the `environment:` declaration in the job.

#### Setting Up Secrets

```bash
# 1. Base64 encode your kubeconfig files
base64 -w 0 ~/.kube/dev-config > dev-config.b64
base64 -w 0 ~/.kube/staging-config > staging-config.b64
base64 -w 0 ~/.kube/prod-config > prod-config.b64

# 2. Repository-level secrets (GitHub CLI)
gh secret set SONAR_TOKEN --body "your-sonar-token"
gh secret set SLACK_WEBHOOK_URL --body "https://hooks.slack.com/services/..."

# 3. Environment-specific secrets (each env gets its own KUBECONFIG)
gh secret set KUBECONFIG --env development --body "$(cat dev-config.b64)"
gh secret set KUBECONFIG --env staging --body "$(cat staging-config.b64)"
gh secret set KUBECONFIG --env production --body "$(cat prod-config.b64)"

# 4. Clean up encoded files
rm -f dev-config.b64 staging-config.b64 prod-config.b64
```

#### How Pipeline Uses Environment Secrets

```yaml
# In ci-cd.yml - each deploy job declares its environment
deploy-dev:
  environment:
    name: development    # ← This tells GitHub to use 'development' env secrets
  steps:
    - name: Configure Kubeconfig
      run: |
        echo "${{ secrets.KUBECONFIG }}" | base64 -d > $HOME/.kube/config
        # ↑ Automatically uses the KUBECONFIG from 'development' environment
```

#### Security Best Practices

| Practice | Implementation |
|----------|---------------|
| Never hardcode secrets | Use `${{ secrets.SECRET_NAME }}` |
| Never log secrets | GitHub auto-masks, but avoid `echo $SECRET` |
| Rotate regularly | Update tokens every 90 days |
| Least privilege | Create service accounts with minimal permissions |
| Audit access | Review Settings → Actions → General → Access logs |

#### How Secrets Flow in Pipeline

```
GitHub Secrets (encrypted at rest)
        │
        ▼
┌───────────────────────────────────────┐
│ GitHub Actions Runner (ephemeral)     │
│ - Secrets decrypted in memory only    │
│ - Masked in logs automatically        │
│ - Cleared after job completes         │
└───────────────────────────────────────┘
        │
        ▼
┌───────────────────────────────────────┐
│ Used by:                              │
│ - docker login (GITHUB_TOKEN)         │
│ - sonar-scanner (SONAR_TOKEN)         │
│ - kubectl (KUBECONFIG_*)              │
│ - slack notification (SLACK_WEBHOOK)  │
└───────────────────────────────────────┘
```

## Part 3: Infrastructure as Code (AWS)
Infrastructure as Code (Terraform)

### Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                         AWS Region                              │
├─────────────────────────────────────────────────────────────────┤
│  ┌─────────────────────────────────────────────────────────┐   │
│  │                        VPC                               │   │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐      │   │
│  │  │ Public      │  │ Public      │  │ Public      │      │   │
│  │  │ Subnet 1    │  │ Subnet 2    │  │ Subnet 3    │      │   │
│  │  │ (NAT GW)    │  │ (ALB)       │  │ (ALB)       │      │   │
│  │  └─────────────┘  └─────────────┘  └─────────────┘      │   │
│  │                                                          │   │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐      │   │
│  │  │ Private     │  │ Private     │  │ Private     │      │   │
│  │  │ Subnet 1    │  │ Subnet 2    │  │ Subnet 3    │      │   │
│  │  │ (EKS/RDS)   │  │ (EKS/RDS)   │  │ (EKS/RDS)   │      │   │
│  │  └─────────────┘  └─────────────┘  └─────────────┘      │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                 │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐      │
│  │     EKS      │    │     RDS      │    │   Secrets    │      │
│  │   Cluster    │◄──►│  PostgreSQL  │    │   Manager    │      │
│  └──────────────┘    └──────────────┘    └──────────────┘      │
└─────────────────────────────────────────────────────────────────┘
```

### YAML-Based Configuration Pattern

Variables stored in YAML files, loaded via `yamldecode()`:

```hcl
locals {
  env = yamldecode(file("${path.module}/../../environments/dev.yaml"))
}

module "vpc" {
  source = "../../modules/vpc"
  config = local.env.vpc
  tags   = local.env.tags
}
```

**Why YAML for Variables?**
- Human-readable configuration
- Easy to diff across environments
- No Terraform syntax knowledge needed for config changes
- Clear separation of config from code

### Module Structure

| Module | Resources Created |
|--------|-------------------|
| **VPC** | VPC, Subnets, NAT Gateway, Route Tables |
| **EKS** | EKS Cluster, Node Groups, IAM Roles, Addons |
| **RDS** | PostgreSQL, Subnet Group, Security Group, Secrets Manager |

### Environment Scaling

| Resource | Dev | Staging | Prod |
|----------|-----|---------|------|
| EKS Nodes | 1-3 t3.medium | 2-4 t3.medium | 3-10 t3.large |
| RDS | db.t3.micro | db.t3.small | db.t3.medium |
| Multi-AZ RDS | No | No | Yes |
| NAT Gateway | Single | Single | Per-AZ |
| Backup | 7 days | 14 days | 30 days |

### Security Features

- **RDS Password**: Generated randomly, stored in AWS Secrets Manager
- **Encryption**: RDS storage encrypted at rest
- **Network**: RDS only accessible from VPC CIDR
- **State**: Remote state in S3 with DynamoDB locking

### Usage

```bash
cd terraform/resources/dev
terraform init
terraform plan
terraform apply
``` 

### CI/CD Automation

Terraform changes are automated via `.github/workflows/terraform.yml`:

```
PR to main (terraform/** changes)
        │
        ▼
┌───────────────┐
│ Format Check  │
│ + Validate    │
└───────┬───────┘
        │
┌───────▼───────┐
│ Checkov Scan  │
└───────┬───────┘
        │
┌───────▼───────┐
│  Plan (Dev)   │◄── Comments plan on PR
│  Plan (Stg)   │
│  Plan (Prod)  │
└───────┬───────┘
        │
   Merge to main
        │
┌───────▼───────┐
│  Apply (Dev)  │◄── Auto-apply
└───────┬───────┘
        │
┌───────▼───────┐
│ Apply (Stg)   │◄── Requires approval
└───────┬───────┘
        │
┌───────▼───────┐
│ Apply (Prod)  │◄── Requires approval
└───────────────┘
```

**Required Secrets (per environment):**

| Secret | Purpose |
|--------|---------|
| `AWS_ROLE_ARN` | IAM role for OIDC authentication |
OR `AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY`
| `SLACK_WEBHOOK_URL` | Notifications (optional) |

## Part 4: Kubernetes Deployment

### Deployment Options

| Method | Use Case |
|--------|----------|
| **Kustomize** | Environment-specific patches, GitOps-friendly |
| **Helm** | Templating, packaging, sharing charts |

### Kustomize Structure

```
k8s/
├── base/                    # Common manifests
│   ├── deployment.yaml
│   ├── service.yaml
│   ├── ingress.yaml
│   ├── hpa.yaml
│   ├── pdb.yaml
│   ├── networkpolicy.yaml
│   └── kustomization.yaml
└── overlays/
    ├── dev/                 # Dev patches
    ├── staging/             # Staging patches
    └── prod/                # Prod patches
```

### Usage

```bash
# Preview manifests
kubectl kustomize k8s/overlays/dev

# Apply to cluster
kubectl apply -k k8s/overlays/dev

# Helm install
helm install titanic-api ./helm/titanic-api -f values-dev.yaml
```

### Environment Scaling

| Feature | Dev | Staging | Prod |
|---------|-----|---------|------|
| Replicas | 1 | 2 | 3 |
| HPA Max | 3 | 5 | 20 |
| CPU Request | 50m | 100m | 200m |
| Memory Request | 64Mi | 128Mi | 256Mi |
| PDB minAvailable | 1 | 1 | 2 |

### Security Features

| Feature | Implementation |
|---------|---------------|
| Non-root | `runAsUser: 1000` |
| Read-only FS | `readOnlyRootFilesystem: true` |
| Drop capabilities | `capabilities.drop: ALL` |
| Network Policy | Restrict ingress/egress |
| Pod Anti-Affinity | Spread across nodes |

### Probes

```yaml
livenessProbe:
  httpGet:
    path: /
    port: 5000
  initialDelaySeconds: 30
  periodSeconds: 10

readinessProbe:
  httpGet:
    path: /
    port: 5000
  initialDelaySeconds: 5
  periodSeconds: 5
```

### Rolling Update Strategy

spec:
  revisionHistoryLimit: 10      # Keep 10 revisions for rollback
  minReadySeconds: 10           # Wait 10s before marking ready
  progressDeadlineSeconds: 300  # Fail if not done in 5 min
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1        # Add 1 new pod first
      maxUnavailable: 0  # Never remove existing pods
```

### Rollback Mechanism

**Via CI/CD (Recommended):**
1. Go to Actions → CI/CD Pipeline → Run workflow
2. Select action: `rollback`
3. Select environment: `dev/staging/prod`
4. Optionally specify revision number

**Via kubectl:**
```bash
# Rollback to previous
kubectl rollout undo deployment/titanic-api -n prod

# Rollback to specific revision
kubectl rollout undo deployment/titanic-api -n prod --to-revision=3

# View revision history
kubectl rollout history deployment/titanic-api -n prod
```

## Part 5: Security & Compliance

See [docs/SECURITY.md](docs/SECURITY.md) for full security documentation.

### Security Controls Summary

| Layer | Controls |
|-------|----------|
| **Container** | Non-root, read-only FS, drop capabilities, Trivy scan |
| **Kubernetes** | Network Policy, PDB, security context, RBAC |
| **Infrastructure** | Private subnets, encrypted RDS, Secrets Manager |
| **CI/CD** | Gitleaks, Checkov, SonarCloud, OIDC auth |

### Defense in Depth

```
┌─────────────────────────────────────────────────────────────┐
│                    CI/CD Pipeline                           │
│  Gitleaks → Checkov → SonarCloud → Trivy (image)           │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                    Kubernetes                               │
│  Network Policy │ Security Context │ RBAC │ Secrets        │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                    Infrastructure                           │
│  Private Subnets │ Security Groups │ Encrypted Storage     │
└─────────────────────────────────────────────────────────────┘
```

### Secrets Management

| Secret | Location | Never In |
|--------|----------|----------|
| DB Password | AWS Secrets Manager | Code, logs, ConfigMaps |
| JWT Key | K8s Secret (overlay) | Git, images |
| AWS Creds | OIDC (no static keys) | Anywhere |

## Part 6: Observability & Monitoring

### Monitoring Stack

| Component | Purpose |
|-----------|---------|
| Prometheus | Metrics collection & storage |
| Grafana | Visualization & dashboards |
| AlertManager | Alert routing & notifications |

### Prometheus Configuration

```yaml
# ServiceMonitor - scrapes /metrics endpoint
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: titanic-api
spec:
  endpoints:
    - port: http
      path: /metrics
      interval: 30s
```

### Grafana Dashboard Panels

| Panel | Metric | Purpose |
|-------|--------|---------|
| Request Rate | `http_requests_total` | Traffic volume |
| Latency (p95/p50) | `http_request_duration_seconds` | Response time |
| Error Rate | `status=~"5.."` | Availability |
| CPU Usage | `container_cpu_usage_seconds_total` | Resource |
| Memory Usage | `container_memory_usage_bytes` | Resource |
| Pod Replicas | `kube_pod_status_phase` | Scaling |
| Pod Restarts | `kube_pod_container_status_restarts_total` | Stability |

### Alert Rules

| Alert | Condition | Severity |
|-------|-----------|----------|
| ApiDown | `up == 0` for 1m | Critical |
| HighErrorRate | `>5%` for 5m | Critical |
| HighLatency | `p95 > 1s` for 5m | Warning |
| HighCPU | `>80%` for 10m | Warning |
| HighMemory | `>80%` for 10m | Warning |
| PodRestart | `>3 restarts/hour` | Warning |
| DatabaseErrors | `>10 errors/5m` | Critical |

### Files

```
monitoring/
├── prometheus/
│   ├── servicemonitor.yaml
│   └── podmonitor.yaml
├── alerting/
│   └── prometheus-rules.yaml
└── grafana/
    ├── dashboard.json
    └── dashboard-configmap.yaml
```

## Part 7: Disaster Recovery & Backup
Refer to Readme.md

## Design Decisions & Trade-offs
Readme.md

## Known Limitations
[TODO]

## Future Improvements
[TODO]

## Estimated Monthly Cloud Costs
[TODO]

## Setup Instructions
[TODO]

## Summary
[TODO]