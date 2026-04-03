output "vpc_id" {
  value = module.vpc.vpc_id
}

output "public_subnet_ids" {
  value = module.vpc.public_subnet_ids
}

output "private_subnet_ids" {
  value = module.vpc.private_subnet_ids
}

output "database_subnet_ids" {
  value = module.vpc.database_subnet_ids
}

output "db_subnet_group_name" {
  value = module.vpc.db_subnet_group_name
}

output "ecr_repository_urls" {
  value = module.ecr.repository_urls
}

output "rds_endpoint" {
  value = module.rds.db_endpoint
}

output "rds_identifier" {
  value = module.rds.db_identifier
}

output "eks_cluster_name" {
  value = module.eks.cluster_name
}

output "eks_cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "eks_oidc_provider_arn" {
  value = module.eks.oidc_provider_arn
}

output "alb_controller_role_arn" {
  value = module.eks.alb_controller_role_arn
}

output "eso_role_arn" {
  value = module.eks.eso_role_arn
}

output "arc_runner_role_arn" {
  value = module.eks.arc_runner_role_arn
}
