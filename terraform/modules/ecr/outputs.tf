output "repository_urls" {
  value       = { for name, repo in aws_ecr_repository.this : name => repo.repository_url }
  description = "Map of repository name to repository URL"
}

output "repository_arns" {
  value       = { for name, repo in aws_ecr_repository.this : name => repo.arn }
  description = "Map of repository name to repository ARN"
}
