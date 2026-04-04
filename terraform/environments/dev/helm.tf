# ── Namespaces ─────────────────────────────────────────────────────────────────

resource "kubernetes_namespace" "external_secrets" {
  metadata { name = "external-secrets" }
}

resource "kubernetes_namespace" "arc_systems" {
  metadata { name = "arc-systems" }
}

resource "kubernetes_namespace" "arc_runners" {
  metadata { name = "arc-runners" }
}

resource "kubernetes_namespace" "monitoring" {
  metadata { name = "monitoring" }
}

# ── 1. AWS Load Balancer Controller ───────────────────────────────────────────

resource "helm_release" "alb_controller" {
  name             = "aws-load-balancer-controller"
  repository       = "https://aws.github.io/eks-charts"
  chart            = "aws-load-balancer-controller"
  version          = "1.8.3"
  namespace        = "kube-system"
  cleanup_on_fail  = true

  set {
    name  = "clusterName"
    value = module.eks.cluster_name
  }
  set {
    name  = "region"
    value = var.aws_region
  }
  set {
    name  = "vpcId"
    value = module.vpc.vpc_id
  }
  set {
    name  = "serviceAccount.create"
    value = "true"
  }
  set {
    name  = "serviceAccount.name"
    value = "aws-load-balancer-controller"
  }
  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = module.eks.alb_controller_role_arn
  }

  depends_on = [module.eks]
}

# ── 2. External Secrets Operator ──────────────────────────────────────────────

resource "helm_release" "external_secrets" {
  name            = "external-secrets"
  repository      = "https://charts.external-secrets.io"
  chart           = "external-secrets"
  version         = "0.10.4"
  namespace       = kubernetes_namespace.external_secrets.metadata[0].name
  cleanup_on_fail = true

  set {
    name  = "installCRDs"
    value = "true"
  }
  set {
    name  = "serviceAccount.create"
    value = "true"
  }
  set {
    name  = "serviceAccount.name"
    value = "external-secrets"
  }
  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = module.eks.eso_role_arn
  }

  depends_on = [module.eks, helm_release.alb_controller]
}

# ── ClusterSecretStore — SSM Parameter Store ──────────────────────────────────
# Uses kubectl provider to avoid plan-time CRD validation failure (CRD is
# installed by the ESO helm release above).

resource "kubectl_manifest" "cluster_secret_store" {
  yaml_body = <<-YAML
    apiVersion: external-secrets.io/v1beta1
    kind: ClusterSecretStore
    metadata:
      name: aws-ssm
    spec:
      provider:
        aws:
          service: ParameterStore
          region: ${var.aws_region}
          auth:
            jwt:
              serviceAccountRef:
                name: external-secrets
                namespace: external-secrets
  YAML

  depends_on = [helm_release.external_secrets]
}

# ── 3. Actions Runner Controller (ARC) ────────────────────────────────────────

resource "helm_release" "arc_controller" {
  name            = "arc"
  repository      = "oci://ghcr.io/actions/actions-runner-controller-charts"
  chart           = "gha-runner-scale-set-controller"
  version         = "0.9.3"
  namespace       = kubernetes_namespace.arc_systems.metadata[0].name
  cleanup_on_fail = true

  depends_on = [module.eks]
}

# GitHub PAT — read from SSM and create as a Kubernetes Secret for ARC.
# Prerequisite: store the PAT at the SSM path set in arc_github_token_parameter_name.

data "aws_ssm_parameter" "github_pat" {
  name            = var.arc_github_token_parameter_name
  with_decryption = true
}

resource "kubernetes_secret" "arc_github_secret" {
  metadata {
    name      = "arc-github-secret"
    namespace = kubernetes_namespace.arc_runners.metadata[0].name
  }

  data = {
    github_token = data.aws_ssm_parameter.github_pat.value
  }
}

# Runner service account — annotated with the IRSA role so runner pods can
# push images to ECR and call the EKS API for helm upgrade.

resource "kubernetes_service_account" "arc_runner" {
  metadata {
    name      = var.arc_runner_scale_set_name
    namespace = kubernetes_namespace.arc_runners.metadata[0].name
    annotations = {
      "eks.amazonaws.com/role-arn" = module.eks.arc_runner_role_arn
    }
  }

  depends_on = [kubernetes_namespace.arc_runners]
}

resource "helm_release" "arc_runner_set" {
  name            = var.arc_runner_scale_set_name
  repository      = "oci://ghcr.io/actions/actions-runner-controller-charts"
  chart           = "gha-runner-scale-set"
  version         = "0.9.3"
  namespace       = kubernetes_namespace.arc_runners.metadata[0].name
  cleanup_on_fail = true

  set {
    name  = "githubConfigUrl"
    value = var.arc_github_config_url
  }
  set {
    name  = "githubConfigSecret"
    value = kubernetes_secret.arc_github_secret.metadata[0].name
  }
  set {
    name  = "minRunners"
    value = "0"
  }
  set {
    name  = "maxRunners"
    value = "5"
  }
  set {
    name  = "template.spec.serviceAccountName"
    value = kubernetes_service_account.arc_runner.metadata[0].name
  }

  depends_on = [helm_release.arc_controller, kubernetes_secret.arc_github_secret]
}

# ── 4. kube-prometheus-stack ──────────────────────────────────────────────────

resource "helm_release" "kube_prometheus_stack" {
  name            = "kube-prometheus-stack"
  repository      = "https://prometheus-community.github.io/helm-charts"
  chart           = "kube-prometheus-stack"
  version         = "67.7.0"
  namespace       = kubernetes_namespace.monitoring.metadata[0].name
  cleanup_on_fail = true

  # Extend timeout — the chart installs many CRDs and waits for webhook readiness
  timeout = 600

  set {
    name  = "grafana.adminPassword"
    value = var.grafana_admin_password
  }
  set {
    name  = "grafana.persistence.enabled"
    value = "false"
  }
  # Short retention — this cluster is created/destroyed per session
  set {
    name  = "prometheus.prometheusSpec.retention"
    value = "6h"
  }
  # Alertmanager adds cost and complexity not needed for the portfolio setup
  set {
    name  = "alertmanager.enabled"
    value = "false"
  }

  depends_on = [module.eks, helm_release.alb_controller]
}
