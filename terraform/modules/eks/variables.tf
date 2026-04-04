variable "project" {
  type = string
}

variable "environment" {
  type = string
}

variable "region" {
  type = string
}

variable "cluster_name" {
  type = string
}

variable "cluster_version" {
  type    = string
  default = "1.35"
}

variable "vpc_id" {
  type = string
}

variable "vpc_cidr" {
  type = string
}

variable "private_subnet_ids" {
  type = list(string)
}

variable "developer_ip_cidr" {
  type        = string
  description = "Developer public IP in CIDR notation — allowed to reach the public EKS API endpoint"
}

variable "ssm_parameter_prefix" {
  type        = string
  description = "SSM Parameter Store path prefix granted to the ESO IRSA role (e.g. /todo-app/dev)"
}

variable "arc_runner_scale_set_name" {
  type        = string
  description = "Name of the ARC runner scale set — must match the Helm release name used for gha-runner-scale-set (becomes the K8s service account name in arc-runners namespace)"
}

variable "node_instance_types" {
  type    = list(string)
  default = ["t3.large"]
}

variable "node_desired_size" {
  type    = number
  default = 2
}

variable "node_min_size" {
  type    = number
  default = 2
}

variable "node_max_size" {
  type    = number
  default = 2
}
