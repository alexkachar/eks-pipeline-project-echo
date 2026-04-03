# ── OIDC Provider ─────────────────────────────────────────────────────────────

data "tls_certificate" "eks" {
  url = aws_eks_cluster.this.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "this" {
  url             = aws_eks_cluster.this.identity[0].oidc[0].issuer
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks.certificates[0].sha1_fingerprint]
}

locals {
  oidc_issuer_host = replace(aws_iam_openid_connect_provider.this.url, "https://", "")
}

# ── Helper: reusable trust policy factory ─────────────────────────────────────

data "aws_iam_policy_document" "irsa_trust" {
  for_each = {
    alb_controller = "system:serviceaccount:kube-system:aws-load-balancer-controller"
    eso            = "system:serviceaccount:external-secrets:external-secrets"
    arc_runner     = "system:serviceaccount:arc-runners:arc-runner-set"
  }

  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.this.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_issuer_host}:sub"
      values   = [each.value]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_issuer_host}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

# ── ALB Controller ────────────────────────────────────────────────────────────

resource "aws_iam_role" "alb_controller" {
  name               = "${local.name_prefix}-alb-controller"
  assume_role_policy = data.aws_iam_policy_document.irsa_trust["alb_controller"].json
}

resource "aws_iam_policy" "alb_controller" {
  name   = "${local.name_prefix}-alb-controller-policy"
  policy = file("${path.module}/files/alb_controller_policy.json")
}

resource "aws_iam_role_policy_attachment" "alb_controller" {
  role       = aws_iam_role.alb_controller.name
  policy_arn = aws_iam_policy.alb_controller.arn
}

# ── External Secrets Operator ─────────────────────────────────────────────────

resource "aws_iam_role" "eso" {
  name               = "${local.name_prefix}-eso"
  assume_role_policy = data.aws_iam_policy_document.irsa_trust["eso"].json
}

data "aws_iam_policy_document" "eso" {
  statement {
    effect = "Allow"
    actions = [
      "ssm:GetParameter",
      "ssm:GetParameters",
      "ssm:GetParametersByPath",
    ]
    resources = [
      "arn:aws:ssm:${var.region}:${data.aws_caller_identity.current.account_id}:parameter${var.ssm_parameter_prefix}/*"
    ]
  }
}

resource "aws_iam_policy" "eso" {
  name   = "${local.name_prefix}-eso-policy"
  policy = data.aws_iam_policy_document.eso.json
}

resource "aws_iam_role_policy_attachment" "eso" {
  role       = aws_iam_role.eso.name
  policy_arn = aws_iam_policy.eso.arn
}

# ── ARC Runner ────────────────────────────────────────────────────────────────

resource "aws_iam_role" "arc_runner" {
  name               = "${local.name_prefix}-arc-runner"
  assume_role_policy = data.aws_iam_policy_document.irsa_trust["arc_runner"].json
}

data "aws_iam_policy_document" "arc_runner" {
  # GetAuthorizationToken has no resource scope — must be *
  statement {
    effect    = "Allow"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }

  statement {
    effect = "Allow"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:GetDownloadUrlForLayer",
      "ecr:BatchGetImage",
      "ecr:InitiateLayerUpload",
      "ecr:UploadLayerPart",
      "ecr:CompleteLayerUpload",
      "ecr:PutImage",
    ]
    resources = [
      "arn:aws:ecr:${var.region}:${data.aws_caller_identity.current.account_id}:repository/todo-app-*"
    ]
  }
}

resource "aws_iam_policy" "arc_runner" {
  name   = "${local.name_prefix}-arc-runner-policy"
  policy = data.aws_iam_policy_document.arc_runner.json
}

resource "aws_iam_role_policy_attachment" "arc_runner" {
  role       = aws_iam_role.arc_runner.name
  policy_arn = aws_iam_policy.arc_runner.arn
}
