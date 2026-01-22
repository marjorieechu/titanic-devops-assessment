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
[TODO]

## Part 3: Infrastructure as Code (AWS)
[TODO]

## Part 4: Kubernetes Deployment
[TODO]

## Part 5: Security & Compliance
[TODO]

## Part 6: Observability & Monitoring
[TODO]

## Part 7: Disaster Recovery & Backup
[TODO]

## Design Decisions & Trade-offs
[TODO]

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