module "eks" {
  source = "../../modules/eks"

  project      = var.project
  environment  = var.environment
  region       = var.aws_region
  cluster_name = var.cluster_name

  vpc_id             = module.vpc.vpc_id
  vpc_cidr           = module.vpc.vpc_cidr
  private_subnet_ids = module.vpc.private_subnet_ids

  developer_ip_cidr         = var.developer_ip
  ssm_parameter_prefix      = "/${var.project}/${var.environment}"
  arc_runner_scale_set_name = var.arc_runner_scale_set_name
}

module "ecr" {
  source = "../../modules/ecr"

  repositories = ["todo-app-frontend", "todo-app-backend", "platform-actions-runner"]
}

module "rds" {
  source = "../../modules/rds"

  project              = var.project
  environment          = var.environment
  vpc_id               = module.vpc.vpc_id
  private_subnet_cidrs = module.vpc.private_subnet_cidrs
  db_subnet_group_name = module.vpc.db_subnet_group_name
  db_name              = "todos"
  db_username          = "todos"
}

module "route53" {
  source = "../../modules/route53"

  zone_id      = var.route53_zone_id
  record_name  = var.app_hostname
  alb_dns_name = var.alb_dns_name
  # Fixed ALB hosted zone ID for eu-central-1
  # https://docs.aws.amazon.com/general/latest/gr/elb.html
  alb_zone_id  = "Z215JYRZR1TBD5"
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
