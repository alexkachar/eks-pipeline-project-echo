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
