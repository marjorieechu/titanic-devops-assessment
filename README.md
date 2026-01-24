# Titanic DevOps Assessment

Production-ready DevOps implementation of Titanic API on AWS EKS.

## Summary

Flask/PostgreSQL API transformed into a cloud-native, production-ready application with:
- **Containerization**: Multi-stage Docker builds with security hardening
- **CI/CD**: GitHub Actions with shift-left security (Gitleaks, Checkov, Trivy, SonarCloud)
- **Infrastructure**: Terraform modules (VPC, EKS, RDS) with YAML-based configuration
- **Kubernetes**: Kustomize overlays + Helm chart with HPA, PDB, NetworkPolicy
- **Security**: Defense-in-depth, OIDC auth, Secrets Manager, compliance checklist
- **Monitoring**: Prometheus ServiceMonitor, Grafana dashboards, alerting rules

## Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              GitHub Actions                                  │
│  ┌─────────┐  ┌─────────┐  ┌─────────┐  ┌─────────┐  ┌─────────┐           │
│  │Gitleaks │→ │Checkov  │→ │  Tests  │→ │SonarCloud│→ │ Trivy   │→ Deploy   │
│  └─────────┘  └─────────┘  └─────────┘  └─────────┘  └─────────┘           │
└─────────────────────────────────────────────────────────────────────────────┘
                                      │
                                      ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                                AWS Cloud                                     │
│  ┌───────────────────────────────────────────────────────────────────────┐  │
│  │                              VPC                                       │  │
│  │  ┌─────────────────────────────┐  ┌─────────────────────────────────┐ │  │
│  │  │      Public Subnets         │  │       Private Subnets           │ │  │
│  │  │  ┌───────┐    ┌───────┐     │  │  ┌─────────────────────────┐    │ │  │
│  │  │  │  ALB  │    │  NAT  │     │  │  │        EKS Cluster      │    │ │  │
│  │  │  └───┬───┘    └───────┘     │  │  │  ┌───────────────────┐  │    │ │  │
│  │  │      │                      │  │  │  │   Titanic API     │  │    │ │  │
│  │  └──────┼──────────────────────┘  │  │  │  ┌─────┐ ┌─────┐  │  │    │ │  │
│  │         │                         │  │  │  │Pod 1│ │Pod 2│  │  │    │ │  │
│  │         └─────────────────────────┼──┼──│  └─────┘ └─────┘  │  │    │ │  │
│  │                                   │  │  └───────────────────┘  │    │ │  │
│  │                                   │  │           │             │    │ │  │
│  │                                   │  │           ▼             │    │ │  │
│  │                                   │  │  ┌───────────────────┐  │    │ │  │
│  │                                   │  │  │   RDS PostgreSQL  │  │    │ │  │
│  │                                   │  │  │   (Multi-AZ)      │  │    │ │  │
│  │                                   │  │  └───────────────────┘  │    │ │  │
│  │                                   │  └─────────────────────────┘    │ │  │
│  │                                   └─────────────────────────────────┘ │  │
│  └───────────────────────────────────────────────────────────────────────┘  │
│                                                                              │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐              │
│  │ Secrets Manager │  │      ECR        │  │   CloudWatch    │              │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘              │
└─────────────────────────────────────────────────────────────────────────────┘
```

## Cost Estimation (Monthly)

| Resource | Dev | Staging | Prod |
|----------|-----|---------|------|
| **EKS Cluster** | $73 | $73 | $73 |
| **EC2 Nodes** (t3.medium x2/3/5) | $60 | $90 | $150 |
| **RDS** (db.t3.micro/small/medium) | $15 | $30 | $70 |
| **ALB** | $20 | $20 | $25 |
| **NAT Gateway** | $35 | $35 | $70 |
| **ECR** | $5 | $5 | $10 |
| **Secrets Manager** | $1 | $1 | $2 |
| **Data Transfer** | $10 | $20 | $50 |
| **Total** | **~$220** | **~$275** | **~$450** |

> Note: Estimates based on us-east-1 pricing. Actual costs vary by usage.

**Cost Optimization Tips:**
- Use Spot instances for non-prod EKS nodes (60-70% savings)
- Reserved instances for prod (30-40% savings)
- Consider Fargate for dev (pay per pod, no idle nodes)

## Disaster Recovery

| Component | Strategy | RTO | RPO |
|-----------|----------|-----|-----|
| **RDS** | Automated backups + Multi-AZ | 5 min | 5 min |
| **EKS** | Declarative IaC (Terraform rebuild) | 30 min | 0 |
| **Application** | Container images in ECR | 5 min | 0 |
| **Secrets** | Secrets Manager (replicated) | 1 min | 0 |

## Quick Start

```bash
# Local development
docker-compose -f docker-compose.dev.yml up

# Deploy to Kubernetes
kubectl apply -k k8s/overlays/dev

# Or with Helm
helm install titanic-api ./helm/titanic-api -f values-dev.yaml
```

## Documentation

- [SOLUTION.md](SOLUTION.md) - Detailed implementation documentation
- [docs/SECURITY.md](docs/SECURITY.md) - Security controls & compliance
- [IMPLEMENTATION_ORDER.md](IMPLEMENTATION_ORDER.md) - Implementation tracking
