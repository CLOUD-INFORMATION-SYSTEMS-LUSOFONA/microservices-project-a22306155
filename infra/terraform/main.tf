terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = local.common_tags
  }
}

data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*x86_64*"]
  }

  filter {
    name   = "state"
    values = ["available"]
  }
}

locals {
  workspace_name = terraform.workspace == "default" ? "dev" : terraform.workspace

  common_tags = merge(
    {
      Project     = var.project_name
      Environment = local.workspace_name
      ManagedBy   = "Terraform"
      Workspace   = terraform.workspace
      Week        = "cloud-project"
    },
    var.additional_tags
  )
}

module "network" {
  source               = "./modules/vpc"
  vpc_cidr             = var.vpc_cidr
  azs                  = var.azs
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  tags                 = local.common_tags
}

module "compute" {
  source              = "./modules/ec2"
  vpc_id              = module.network.vpc_id
  subnet_id           = module.network.public_subnet_ids[0]
  ami_id              = data.aws_ami.al2023.id
  instance_type       = var.instance_type
  key_name            = var.key_name
  allowed_ports       = var.allowed_ports
  allowed_cidr_blocks = var.allowed_cidr_blocks
  user_data           = var.ec2_user_data
  tags                = local.common_tags
}

module "database" {
  source                     = "./modules/rds"
  vpc_id                     = module.network.vpc_id
  subnet_ids                 = module.network.private_subnet_ids
  allowed_security_group_ids = [module.compute.security_group_id]
  db_name                    = var.db_name
  username                   = var.db_username
  password                   = var.db_password
  instance_class             = var.db_instance_class
  engine                     = var.db_engine
  engine_version             = var.db_engine_version
  port                       = var.db_port
  tags                       = local.common_tags
}

module "messaging" {
  source                       = "./modules/sqs"
  environment                  = local.workspace_name
  project_name                 = var.project_name
  max_receive_count_before_dlq = 3
  tags                         = local.common_tags
}

# Attach SQS policy to EC2 instance role
resource "aws_iam_role_policy_attachment" "ec2_sqs_access" {
  role       = module.compute.iam_role_name
  policy_arn = module.messaging.sqs_access_policy_arn
}



