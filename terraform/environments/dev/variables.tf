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
