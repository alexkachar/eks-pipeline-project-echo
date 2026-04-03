module "ecr" {
  source = "../../modules/ecr"

  repositories = ["todo-app-frontend", "todo-app-backend"]
}

module "rds" {
  source = "../../modules/rds"

  project              = var.project
  environment          = var.environment
  vpc_id               = module.vpc.vpc_id
  private_subnet_ids   = module.vpc.private_subnet_ids
  db_subnet_group_name = module.vpc.db_subnet_group_name
  db_name              = "todos"
  db_username          = "todos"
}

module "vpc" {
  source = "../../modules/vpc"

  project      = var.project
  environment  = var.environment
  region       = var.aws_region
  cluster_name = var.cluster_name

  vpc_cidr              = "10.0.0.0/16"
  public_subnet_cidrs   = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnet_cidrs  = ["10.0.10.0/24", "10.0.11.0/24"]
  database_subnet_cidrs = ["10.0.20.0/24", "10.0.21.0/24"]
}
