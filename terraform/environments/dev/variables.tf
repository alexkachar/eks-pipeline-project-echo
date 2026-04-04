variable "aws_region" {
  type    = string
  default = "eu-central-1"
}

variable "environment" {
  type    = string
  default = "dev"
}

variable "project" {
  type    = string
  default = "todo-app"
}

variable "cluster_name" {
  type    = string
  default = "todo-app-dev"
}

variable "developer_ip" {
  type        = string
  description = "Developer's public IP in CIDR notation — restricts EKS public API endpoint access"
}

# ── Route 53 / DNS ────────────────────────────────────────────────────────────

variable "route53_zone_id" {
  type        = string
  description = "Route 53 hosted zone ID for alexanderkachar.com"
  default     = "Z02945612K9BSDVBK5OTN"
}

variable "app_hostname" {
  type        = string
  description = "Fully qualified hostname for the app"
  default     = "todo.alexanderkachar.com"
}

variable "alb_dns_name" {
  type        = string
  default     = ""
  description = "ALB DNS name output by the ALB Controller after first helm install (kubectl get ingress -n todo-app). Leave empty on Phase 1 apply; fill in and re-apply for Phase 2 to create the Route 53 record."
}

# ── ARC (Actions Runner Controller) ───────────────────────────────────────────

variable "arc_github_config_url" {
  type        = string
  description = "GitHub repo URL that ARC runners register to (e.g. https://github.com/owner/repo)"
}

variable "arc_runner_scale_set_name" {
  type        = string
  description = "Name of the ARC runner scale set — used as the 'runs-on' label in GitHub Actions workflows"
}

variable "arc_github_token_parameter_name" {
  type        = string
  description = "SSM Parameter Store name holding the GitHub PAT used by ARC to register runners"
}

# ── Observability ──────────────────────────────────────────────────────────────

variable "grafana_admin_password" {
  type        = string
  sensitive   = true
  default     = "admin"
  description = "Grafana admin password — accessible only via kubectl port-forward in this setup"
}
