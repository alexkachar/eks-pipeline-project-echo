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

The VPC contains 6 subnets across 2 Availability Zones: 2 public (for the ALB), 2 private (for EKS worker nodes), and 2 database (for RDS).

VPC Endpoints handle all AWS service traffic from private subnets — ECR (API + DKR), S3, EKS, EC2, STS, SSM (3 endpoints for Session Manager), and CloudWatch Logs — keeping that traffic on the AWS backbone network. A single NAT Gateway in AZ-0 provides outbound internet access for pulling images from public registries (ghcr.io, docker.io) that are not reachable via VPC endpoints.

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
- **VPC Endpoints for all AWS services** — ECR, S3, SSM, STS, EKS, CloudWatch traffic never leaves the AWS backbone
- **IRSA for all service accounts** — ESO, ALB Controller, ARC runners authenticate to AWS without static keys
- **OIDC federation** — GitHub Actions authenticates to AWS without long-lived credentials
- **Database isolation** — RDS in dedicated subnets, security group restricted to private subnet CIDRs
- **Kaniko** — image builds without privileged containers or Docker-in-Docker
- **CIDR-restricted API** — cluster endpoint not open to the internet

## Cost management

This project is designed to be created and destroyed with Terraform for each working session rather than running continuously.

Typical hourly cost while running: approximately $0.35/hour (EKS control plane + 2× t3.large nodes + RDS + VPC endpoints + NAT Gateway). AWS account credits offset these costs.

## Destroying the stack

**Do not run `terraform destroy` directly.** The ALB is created by the ALB Controller from the Kubernetes Ingress and is not in Terraform state. Destroying the cluster while the ALB still exists will cause the VPC delete to fail.

Use the provided script instead:

```bash
./destroy.sh
```

The script: uninstalls the `todo-app` Helm release → waits for the ALB Controller to delete the ALB → clears `alb_dns_name` in tfvars → runs `terraform destroy`.

## Bootstrap sequence (fresh recreate)

The full stack requires two phases after a `terraform apply`.

### Phase 1 — infrastructure

```bash
cd terraform/environments/dev
terraform apply
```

Provisions: VPC + subnets + NAT + endpoints → ECR repos → EKS cluster → RDS + SSM parameters → Helm addon releases (ALB Controller, ARC, ESO, kube-prometheus-stack).

After apply completes:

```bash
# Update kubeconfig
aws eks update-kubeconfig --name todo-app-dev --region eu-central-1

# Build and push the custom ARC runner image (ECR was empty after recreate)
./bootstrap-runner-image.sh
```

### Phase 2 — first application deploy

```bash
helm install todo-app ./k8s/helm/todo-app -n todo-app --create-namespace
```

Wait ~2 minutes for the ALB Controller to provision the ALB, then capture its DNS name and wire up Route 53:

```bash
ALB_DNS=$(kubectl get ingress -n todo-app -o jsonpath='{.items[0].status.loadBalancer.ingress[0].hostname}')
echo "alb_dns_name = \"$ALB_DNS\""
# Paste the above line into terraform/environments/dev/terraform.tfvars, then:
terraform apply
```

After Phase 2, all subsequent deploys are fully automated — a push to `main` triggers CI/CD via ARC.

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
