terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

data "aws_caller_identity" "current" {}

module "vpc" {
  source      = "../../modules/vpc"
  environment = var.environment
}

module "alb" {
  source       = "../../modules/alb"
  environment  = var.environment
  vpc_id       = module.vpc.vpc_id
  subnet_ids   = module.vpc.public_subnet_ids
  active_color = var.active_color
}

module "s3" {
  source         = "../../modules/s3"
  environment    = var.environment
  aws_account_id = data.aws_caller_identity.current.account_id
}

resource "aws_ecr_repository" "backend" {
  name                 = "${var.environment}-cloudshop-backend"
  image_tag_mutability = "MUTABLE"
  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_iam_role" "ecs_execution" {
  name = "${var.environment}-ecs-execution-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_execution" {
  role       = aws_iam_role.ecs_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role" "ecs_task" {
  name = "${var.environment}-ecs-task-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      }
    }]
  })
}

module "ecs" {
  source                = "../../modules/ecs"
  environment           = var.environment
  vpc_id                = module.vpc.vpc_id
  subnet_ids            = module.vpc.public_subnet_ids
  alb_security_group_id = module.alb.alb_security_group_id
  target_group_blue_arn = module.alb.target_group_blue_arn
  target_group_green_arn = module.alb.target_group_green_arn
  alb_listener_arn      = module.alb.listener_arn
  execution_role_arn    = aws_iam_role.ecs_execution.arn
  task_role_arn         = aws_iam_role.ecs_task.arn
  ecr_repository_url    = aws_ecr_repository.backend.repository_url
  backend_image_tag     = var.backend_image_tag
  active_color          = var.active_color
  db_host               = module.rds.db_address
  db_name               = module.rds.db_name
  db_user               = "cloudshop_admin"
  db_password           = var.db_password
  aws_region            = var.aws_region
}

module "rds" {
  source                = "../../modules/rds"
  environment           = var.environment
  vpc_id                = module.vpc.vpc_id
  subnet_ids            = module.vpc.public_subnet_ids
  ecs_security_group_id = module.ecs.ecs_security_group_id
  db_password           = var.db_password
}

resource "aws_ssm_parameter" "active_color" {
  name  = "/${var.environment}/backend/active_color"
  type  = "String"
  value = var.active_color
}
