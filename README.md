# Todo App on EKS — DevOps Portfolio Project

A production-grade infrastructure for a simple full-stack Todo application, deployed on AWS EKS with fully automated CI/CD, observability, and security best practices.

The application is intentionally minimal (React + Express + PostgreSQL CRUD) — the focus of this project is the infrastructure, automation, and operational tooling around it.

## Architecture

```
                         ┌──────────────┐
                         │   Internet   │
                         └──────┬───────┘
                                │
                         ┌──────┴───────┐
                         │   Route 53   │
                         │  todo.alex…  │
                         └──────┬───────┘
                                │
┌───────────────────────────────┼────────────────────────────────────┐
│ VPC                           │                                    │
│  ┌────────────────────────────┼─────────────────────────────────┐  │
│  │ Public subnets (2 AZs)     │                                 │  │
│  │                     ┌──────┴───────┐                         │  │
│  │                     │     ALB      │                         │  │
│  │                     │ TLS termina. │                         │  │
│  │                     └──────┬───────┘                         │  │
│  └────────────────────────────┼─────────────────────────────────┘  │
│  ┌────────────────────────────┼─────────────────────────────────┐  │
│  │ Private subnets (2 AZs)    │                                 │  │
│  │  ┌─────────────────────────┼──────────────────────────────┐  │  │
│  │  │ EKS 1.35                │                              │  │  │
│  │  │              ┌──────────┴──────────┐                   │  │  │
│  │  │              │ Ingress (path-based) │                  │  │  │
│  │  │              └───┬─────────────┬───┘                   │  │  │
│  │  │         /*       │             │   /api/*              │  │  │
│  │  │          ┌───────┴──┐    ┌─────┴────────┐              │  │  │
│  │  │          │ Frontend │    │   Backend    │              │  │  │
│  │  │          │  Nginx   │    │   Express    │──────┐       │  │  │
│  │  │          │ 2 repli. │    │  2 replicas  │      │       │  │  │
│  │  │          └──────────┘    └──────────────┘      │       │  │  │
│  │  │                                                │       │  │  │
│  │  │  ┌───────────┐ ┌─────┐ ┌──────┐ ┌──────────┐  │       │  │  │
│  │  │  │ALB Ctrlr. │ │ ARC │ │ ESO  │ │Prometheus│  │       │  │  │
│  │  │  └───────────┘ └─────┘ └──────┘ │+ Grafana │  │       │  │  │
│  │  │                                 └──────────┘  │       │  │  │
│  │  └────────────────────────────────────────────────┼───────┘  │  │
│  └───────────────────────────────────────────────────┼──────────┘  │
│  ┌───────────────────────────────────────────────────┼──────────┐  │
│  │ Database subnets (2 AZs)                          │          │  │
│  │                     ┌─────────────────┐           │          │  │
│  │                     │ RDS PostgreSQL  │◄──────────┘          │  │
│  │                     │  db.t4g.micro   │                      │  │
│  │                     └─────────────────┘                      │  │
│  └──────────────────────────────────────────────────────────────┘  │
│                                                                    │
│  VPC Endpoints: ECR, S3, EKS, EC2, STS, SSM, CloudWatch Logs      │
│  (no NAT Gateway — all AWS traffic stays on the AWS network)       │
└────────────────────────────────────────────────────────────────────┘
```

## Tech stack

| Layer | Technology |
|---|---|
| Frontend | React + Vite, served by Nginx |
| Backend | Node.js + Express |
| Database | PostgreSQL on RDS |
| Container orchestration | Amazon EKS 1.35 |
| Infrastructure as Code | Terraform (modular) |
| CI/CD | GitHub Actions + Actions Runner Controller (in-cluster) |
| Image builds | Kaniko (no Docker-in-Docker) |
| Container registry | Amazon ECR |
| Secrets | AWS SSM Parameter Store → External Secrets Operator → K8s Secrets |
| Observability | Prometheus + Grafana (kube-prometheus-stack) |
| TLS | ACM certificate on ALB (`*.alexanderkachar.com`) |
| DNS | Route 53 |
| Package management | Helm |

## Repository structure

```
.github/workflows/            # GitHub Actions workflow definitions
app/
  backend/                     # Express API + Dockerfile
  frontend/                    # React + Vite + Dockerfile (Nginx)
k8s/
  helm/
    todo-app/                  # Helm chart for the application
terraform/
  modules/
    vpc/                       # VPC, subnets, IGW, VPC endpoints
    eks/                       # Cluster, node group, IRSA roles
    rds/                       # PostgreSQL instance, subnet group, SG
    ecr/                       # Image repositories
    route53/                   # DNS alias record
  environments/
    dev/                       # tfvars for the dev environment
```

## Networking

The VPC contains 6 subnets across 2 Availability Zones: 2 public (for the ALB), 2 private (for EKS worker nodes), and 2 database (for RDS). There is no NAT Gateway. Instead, all AWS service communication from private subnets goes through VPC Endpoints, keeping traffic on the AWS backbone network. The endpoints cover ECR (API + DKR), S3, EKS, EC2, STS, SSM (3 endpoints for Session Manager), and CloudWatch Logs.

## EKS cluster access

The cluster API endpoint is configured as **public + private with a CIDR allowlist** restricted to the developer's IP address. This allows `kubectl` and Terraform's Helm provider to reach the cluster directly during provisioning, while blocking all other external access.

**Production note:** In a team environment, the cluster would typically use a private-only endpoint paired with a VPN or AWS Direct Connect. The CIDR-restricted public+private pattern used here is a standard approach for solo developer or small team workflows.

Worker node access is through **SSM Session Manager** — no bastion host, no VPN, and no inbound ports open on the nodes.

## CI/CD pipeline

```
Push to main
     │
     ▼
GitHub webhook
     │
     ▼
ARC picks up job → Runner pod starts inside EKS
     │
     ├──► Kaniko builds frontend image → pushes to ECR
     ├──► Kaniko builds backend image  → pushes to ECR
     │
     ▼
helm upgrade → rolling update (2 replicas, maxSurge: 1)
```

The entire CI/CD pipeline runs inside the EKS cluster. Actions Runner Controller (ARC) manages self-hosted GitHub Actions runners as pods. Kaniko handles container image builds without a Docker daemon or privileged containers. Authentication to AWS services uses IRSA (IAM Roles for Service Accounts) — no static credentials are stored anywhere.

## Secrets management

Database credentials and other sensitive configuration are stored in **AWS SSM Parameter Store** as SecureString parameters. The **External Secrets Operator** (ESO), authenticated via IRSA, syncs these into Kubernetes Secrets that the application pods consume. No secrets exist in source code, Helm values files, or GitHub Secrets.

## Observability

The **kube-prometheus-stack** Helm chart provides Prometheus, Grafana, and Alertmanager with default dashboards for node metrics, pod metrics, and Kubernetes component health. Grafana runs without persistent storage since the stack is ephemeral — custom dashboards are defined as ConfigMaps in the Helm chart and recreated automatically on each deployment.

## Security highlights

- **Private worker nodes** — no public IPs, no inbound ports, SSM-only access
- **No NAT Gateway** — VPC Endpoints eliminate internet-routed traffic for AWS services
- **IRSA for all service accounts** — ESO, ALB Controller, ARC runners authenticate to AWS without static keys
- **OIDC federation** — GitHub Actions authenticates to AWS without long-lived credentials
- **Database isolation** — RDS in dedicated subnets, security group restricted to private subnet CIDRs
- **Kaniko** — image builds without privileged containers or Docker-in-Docker
- **CIDR-restricted API** — cluster endpoint not open to the internet

## Cost management

This project is designed to be created and destroyed with Terraform for each working session rather than running continuously.

```bash
# Start a session
terraform apply

# Work on the project...

# End the session
terraform destroy
```

Typical hourly cost while running: approximately $0.30/hour (EKS control plane + 2× t3.large nodes + RDS + VPC endpoints). AWS account credits offset these costs.

## Bootstrap sequence

A single `terraform apply` provisions the entire stack:

1. VPC, subnets, internet gateway, VPC endpoints
2. ECR repositories
3. EKS cluster (public+private endpoint, CIDR-restricted)
4. RDS PostgreSQL instance + SSM parameters for credentials
5. Helm releases: AWS Load Balancer Controller, ARC, ESO, kube-prometheus-stack
6. Route 53 alias record pointing `todo.alexanderkachar.com` → ALB

After Terraform completes, a push to `main` triggers the first CI/CD run via ARC, which builds and deploys the application.

## Prerequisites

- AWS account with appropriate permissions
- AWS CLI configured
- Terraform installed
- kubectl installed
- Helm installed
- GitHub repository with Actions enabled
- ACM certificate for `*.alexanderkachar.com` (already provisioned)
- Route 53 hosted zone for `alexanderkachar.com` (already provisioned)

## Future enhancements

- Private-only EKS endpoint with VPN or Direct Connect
- ArgoCD for GitOps-style continuous delivery
- Horizontal Pod Autoscaler based on custom metrics
- Persistent Grafana dashboards with EBS-backed storage
- Additional projects on other subdomains (`<project>.alexanderkachar.com`)
