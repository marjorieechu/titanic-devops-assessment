# Security Controls Documentation

## Overview

This document outlines the security controls implemented across the Titanic API infrastructure.

---

## 1. Container Security

### Image Security

| Control | Implementation | Status |
|---------|---------------|--------|
| Image scanning | Trivy in CI/CD (CRITICAL/HIGH) | ✅ |
| Base image | `python:3.11-slim` (minimal) | ✅ |
| No root user | `USER appuser` (UID 1000) | ✅ |
| Multi-stage build | Build deps not in final image | ✅ |

### Runtime Security (Kubernetes)

```yaml
securityContext:
  runAsNonRoot: true
  runAsUser: 1000
  readOnlyRootFilesystem: true
  allowPrivilegeEscalation: false
  capabilities:
    drop:
      - ALL
```

| Control | Why |
|---------|-----|
| `runAsNonRoot` | Container escape won't have root privileges |
| `readOnlyRootFilesystem` | Prevent malware from writing to disk |
| `allowPrivilegeEscalation: false` | Prevent privilege escalation attacks |
| `capabilities.drop: ALL` | Remove all Linux capabilities |

---

## 2. Secret Management

### Never Hardcoded

| Secret | Storage | Access Method |
|--------|---------|---------------|
| DB Password | AWS Secrets Manager | EKS IRSA |
| JWT Secret | K8s Secret (from overlay) | Environment variable |
| KUBECONFIG | GitHub Environment Secrets | CI/CD only |
| SONAR_TOKEN | GitHub Repository Secrets | CI/CD only |
| AWS Credentials | OIDC Federation | No static keys |

### AWS Secrets Manager Integration

```hcl
# Terraform creates secret
resource "aws_secretsmanager_secret" "db_password" {
  name = "dev-titanic-api-db-password"
}

# Application retrieves via IRSA
# (EKS pod assumes IAM role, reads secret)
```

---

## 3. Network Security

### Network Policy

```yaml
# Only allow:
# - Ingress from ingress controller (port 5000)
# - Egress to RDS (port 5432)
# - Egress to DNS (port 53)
# - Egress to HTTPS (port 443)
```

### Database Security

| Control | Implementation |
|---------|---------------|
| No public access | RDS in private subnet |
| Encrypted at rest | `storage_encrypted = true` |
| Encrypted in transit | SSL required |
| Security group | Only VPC CIDR allowed |

### TLS/SSL Configuration

**Ingress (ALB):**
```yaml
annotations:
  alb.ingress.kubernetes.io/ssl-redirect: "443"
  alb.ingress.kubernetes.io/certificate-arn: arn:aws:acm:...
```

**Database Connection:**
```
DATABASE_URL=postgresql://user:pass@host:5432/db?sslmode=require
```

---

## 4. CI/CD Security

### Shift-Left Security Gates

| Stage | Tool | Blocks On |
|-------|------|-----------|
| 1 | Gitleaks | Hardcoded secrets |
| 2 | Checkov | IaC misconfigurations |
| 3 | SonarCloud | Code vulnerabilities, quality |
| 4 | Trivy | CRITICAL/HIGH CVEs |

### Pipeline Security

| Control | Implementation |
|---------|---------------|
| Least privilege | `permissions: contents: read` |
| No shell injection | Validated by Checkov |
| OIDC for AWS | No static credentials |
| Environment protection | Manual approval for prod |

---

## 5. Infrastructure Security

### VPC Design

```
Public Subnets:  ALB, NAT Gateway (internet-facing)
Private Subnets: EKS, RDS (no direct internet)
```

### IAM Roles

| Role | Permissions | Used By |
|------|-------------|---------|
| EKS Node Role | EC2, ECR pull | EKS nodes |
| IRSA Pod Role | Secrets Manager read | Application pods |
| CI/CD Role | EKS deploy, ECR push | GitHub Actions |

---

## 6. Compliance Checklist

### Container Security

- [x] Non-root user in Dockerfile
- [x] Non-root user in K8s deployment
- [x] Read-only root filesystem
- [x] Dropped Linux capabilities
- [x] No hardcoded secrets in images
- [x] Image vulnerability scanning
- [x] Minimal base image

### Kubernetes Security

- [x] Network policies defined
- [x] Resource limits set
- [x] Pod security context
- [x] Service account per app
- [x] Secrets not in ConfigMaps
- [x] RBAC configured

### Infrastructure Security

- [x] RDS in private subnet
- [x] RDS encrypted at rest
- [x] No public S3 buckets
- [x] VPC flow logs (recommended)
- [x] Secrets in Secrets Manager

### CI/CD Security

- [x] No hardcoded credentials
- [x] Secret scanning (Gitleaks)
- [x] SAST scanning (SonarCloud)
- [x] Container scanning (Trivy)
- [x] IaC scanning (Checkov)
- [x] Manual approval for production

---

## 7. Vulnerability Response

### Severity Levels

| Severity | Response Time | Action |
|----------|---------------|--------|
| CRITICAL | 24 hours | Immediate patch, hotfix deploy |
| HIGH | 7 days | Patch in next release |
| MEDIUM | 30 days | Scheduled maintenance |
| LOW | 90 days | Backlog |

### Response Process

1. Trivy/SonarCloud detects vulnerability
2. Pipeline fails (CRITICAL/HIGH)
3. Team notified via Slack
4. Patch applied or dependency updated
5. Re-run pipeline to verify fix
