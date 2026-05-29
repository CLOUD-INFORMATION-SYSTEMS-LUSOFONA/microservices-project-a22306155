variable "project_name" {
  description = "Project name used in resource naming and tags"
  type        = string
  default     = "CloudComputing"
}

variable "aws_region" {
  description = "AWS region where resources will be created"
  type        = string
  default     = "eu-central-1"

  validation {
    condition     = can(regex("^[a-z]{2}-[a-z]+-[0-9]$", var.aws_region))
    error_message = "aws_region must be a valid AWS region format, for example eu-central-1."
  }
}

variable "additional_tags" {
  description = "Extra tags to add to all resources"
  type        = map(string)
  default     = {}
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.8.0.0/16"

  validation {
    condition     = can(cidrnetmask(var.vpc_cidr))
    error_message = "vpc_cidr must be a valid CIDR block, for example 10.8.0.0/16."
  }
}

variable "azs" {
  description = "Availability zones used for public and private subnets"
  type        = list(string)
  default     = ["eu-central-1a", "eu-central-1b"]

  validation {
    condition     = length(var.azs) >= 2
    error_message = "azs must contain at least two availability zones."
  }
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets"
  type        = list(string)
  default     = ["10.8.1.0/24", "10.8.2.0/24"]

  validation {
    condition = length(var.public_subnet_cidrs) == length(var.azs) && alltrue([
      for cidr in var.public_subnet_cidrs : can(cidrnetmask(cidr))
    ])
    error_message = "public_subnet_cidrs must contain one valid CIDR per AZ."
  }
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets"
  type        = list(string)
  default     = ["10.8.10.0/24", "10.8.11.0/24"]

  validation {
    condition = length(var.private_subnet_cidrs) == length(var.azs) && alltrue([
      for cidr in var.private_subnet_cidrs : can(cidrnetmask(cidr))
    ])
    error_message = "private_subnet_cidrs must contain one valid CIDR per AZ."
  }
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.small"

  validation {
    condition     = contains(["t2.micro", "t3.micro", "t3.small", "t3.medium"], var.instance_type)
    error_message = "instance_type must be one of: t2.micro, t3.micro, t3.small, or t3.medium."
  }
}

variable "key_name" {
  description = "AWS key pair name for EC2 access"
  type        = string
  default     = "miguelrodr1"
}

variable "allowed_ports" {
  description = "List of ports opened in the EC2 security group"
  type        = list(number)
  default     = [22, 80, 443]

  validation {
    condition = length(var.allowed_ports) > 0 && alltrue([
      for port in var.allowed_ports : port >= 1 && port <= 65535
    ])
    error_message = "allowed_ports must contain valid TCP ports between 1 and 65535."
  }
}

variable "allowed_cidr_blocks" {
  description = "CIDR blocks allowed to access the EC2 security group"
  type        = list(string)
  default     = ["0.0.0.0/0"]

  validation {
    condition = length(var.allowed_cidr_blocks) > 0 && alltrue([
      for cidr in var.allowed_cidr_blocks : can(cidrnetmask(cidr))
    ])
    error_message = "allowed_cidr_blocks must contain valid CIDR blocks."
  }
}

variable "ec2_user_data" {
  description = "User data script for the EC2 instance"
  type        = string
  default     = <<-EOF
#!/bin/bash
dnf update -y
dnf install -y docker
systemctl start docker
systemctl enable docker
usermod -aG docker ec2-user
EOF
}

variable "db_name" {
  description = "Initial database name"
  type        = string
  default     = "cloudprojectdb"

  validation {
    condition     = can(regex("^[a-zA-Z][a-zA-Z0-9_]{0,62}$", var.db_name))
    error_message = "db_name must start with a letter and contain only letters, numbers, and underscores."
  }
}

variable "db_username" {
  description = "Database master username"
  type        = string
  default     = "dr1gues"

  validation {
    condition     = can(regex("^[a-zA-Z][a-zA-Z0-9_]{0,15}$", var.db_username))
    error_message = "db_username must start with a letter and contain only letters, numbers, and underscores."
  }
}

variable "db_password" {
  description = "Database master password"
  type        = string
  sensitive   = true
  default     = "dr1gues103"
}

variable "db_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.micro"

  validation {
    condition     = contains(["db.t3.micro", "db.t3.small", "db.t3.medium"], var.db_instance_class)
    error_message = "db_instance_class must be one of: db.t3.micro, db.t3.small, or db.t3.medium."
  }
}

variable "db_engine" {
  description = "RDS engine"
  type        = string
  default     = "postgres"
}

variable "db_engine_version" {
  description = "RDS engine version"
  type        = string
  default     = "17"
}

variable "db_port" {
  description = "Database port"
  type        = number
  default     = 5432

  validation {
    condition     = var.db_port >= 1 && var.db_port <= 65535
    error_message = "db_port must be a valid TCP port between 1 and 65535."
  }
}

