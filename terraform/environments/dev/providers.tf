terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.14"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.31"
    }
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = "~> 1.14"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = var.project
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}

# ── EKS cluster auth (used by helm, kubernetes, kubectl providers) ─────────────
# Use exec-based auth so the token is fetched fresh on every API call.
# data.aws_eks_cluster_auth issues a single token valid for ~15 minutes;
# a full apply (cluster + helm charts) easily exceeds that and causes
# "server asked for client credentials" errors mid-run.

locals {
  kubeconfig = {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_ca_certificate)
  }
}

provider "helm" {
  kubernetes {
    host                   = local.kubeconfig.host
    cluster_ca_certificate = local.kubeconfig.cluster_ca_certificate
    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", var.cluster_name, "--region", var.aws_region]
    }
  }
}

provider "kubernetes" {
  host                   = local.kubeconfig.host
  cluster_ca_certificate = local.kubeconfig.cluster_ca_certificate
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", var.cluster_name, "--region", var.aws_region]
  }
}

provider "kubectl" {
  host                   = local.kubeconfig.host
  cluster_ca_certificate = local.kubeconfig.cluster_ca_certificate
  load_config_file       = false
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", var.cluster_name, "--region", var.aws_region]
  }
}
