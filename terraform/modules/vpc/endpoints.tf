# ── Security Group for Interface Endpoints ────────────────────────────────────

resource "aws_security_group" "vpc_endpoints" {
  name        = "${local.name_prefix}-vpc-endpoints-sg"
  description = "Allow HTTPS from within VPC to interface endpoints"
  vpc_id      = aws_vpc.this.id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
    description = "HTTPS from VPC"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound"
  }

  tags = { Name = "${local.name_prefix}-vpc-endpoints-sg" }
}

# ── S3 Gateway Endpoint ───────────────────────────────────────────────────────
# Free — routes S3 traffic (ECR image layers) directly over the AWS network.

resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.this.id
  service_name      = "com.amazonaws.${var.region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [aws_route_table.private.id, aws_route_table.database.id]

  tags = { Name = "${local.name_prefix}-s3-endpoint" }
}

# ── Interface Endpoints ───────────────────────────────────────────────────────
# Placed in private subnets so EKS nodes and CI runners can reach AWS APIs
# without internet access.

locals {
  interface_endpoints = toset([
    "ecr.api",      # ECR control plane
    "ecr.dkr",      # ECR image layer pulls
    "eks",          # kubectl / API server
    "ec2",          # VPC CNI (aws-node)
    "sts",          # IRSA token exchange
    "ssm",          # SSM Session Manager
    "ssmmessages",  # SSM Session Manager
    "ec2messages",  # SSM Session Manager
    "logs",         # CloudWatch Logs
  ])
}

resource "aws_vpc_endpoint" "interface" {
  for_each = local.interface_endpoints

  vpc_id              = aws_vpc.this.id
  service_name        = "com.amazonaws.${var.region}.${each.value}"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private[*].id
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true

  tags = { Name = "${local.name_prefix}-${each.value}-endpoint" }
}
