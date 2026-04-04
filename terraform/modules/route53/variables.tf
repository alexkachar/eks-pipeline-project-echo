variable "zone_id" {
  type        = string
  description = "Route 53 hosted zone ID for the domain"
}

variable "record_name" {
  type        = string
  description = "DNS record name (e.g. todo.alexanderkachar.com)"
}

variable "alb_dns_name" {
  type        = string
  description = "ALB DNS name — the alias target"
}

variable "alb_zone_id" {
  type        = string
  description = "ALB hosted zone ID for the region (fixed per AWS region)"
}
