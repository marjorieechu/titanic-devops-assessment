# Terraform Infrastructure

AWS infrastructure for Titanic API using modular Terraform with YAML-based configuration.

## Structure

```
terraform/
├── environments/          # YAML config per environment
│   ├── dev.yaml
│   ├── staging.yaml
│   └── prod.yaml
├── modules/               # Reusable Terraform modules
│   ├── vpc/
│   ├── eks/
│   └── rds/
└── resources/             # Environment deployments
    ├── dev/
    ├── staging/
    └── prod/
```

## Usage

### Prerequisites
- AWS CLI configured with appropriate credentials
- Terraform >= 1.5.0
- S3 bucket and DynamoDB table for state (create manually or use bootstrap)

### Deploy an Environment

```bash
cd terraform/resources/dev
terraform init
terraform plan
terraform apply
```

### Environment Differences

| Resource | Dev | Staging | Prod |
|----------|-----|---------|------|
| EKS Nodes | 1-3 (t3.medium) | 2-4 (t3.medium) | 3-10 (t3.large) |
| RDS | db.t3.micro, Single-AZ | db.t3.small, Single-AZ | db.t3.medium, Multi-AZ |
| NAT Gateway | Single | Single | Per-AZ |
| Backup Retention | 7 days | 14 days | 30 days |

## Modules

### VPC Module
Creates VPC with public/private subnets, NAT gateway, and proper tags for EKS.

### EKS Module
Creates EKS cluster with managed node groups, cluster addons (CoreDNS, kube-proxy, VPC-CNI).

### RDS Module
Creates PostgreSQL RDS instance with:
- Encrypted storage
- Password stored in AWS Secrets Manager
- Security group allowing VPC access only
