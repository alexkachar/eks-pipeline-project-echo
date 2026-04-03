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
