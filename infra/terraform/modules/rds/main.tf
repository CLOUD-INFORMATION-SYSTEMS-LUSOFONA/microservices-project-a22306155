resource "aws_db_subnet_group" "this" {
  name       = lower("cloud-project-db-subnet-group")
  subnet_ids = var.subnet_ids

  tags = merge(var.tags, {
    Name = "cloud-project-db-subnet-group"
  })
}

resource "aws_security_group" "this" {
  name        = lower("cloud-project-rds-sg")
  description = "Security group for the Week 8 RDS instance"
  vpc_id      = var.vpc_id

  ingress {
    from_port       = var.port
    to_port         = var.port
    protocol        = "tcp"
    security_groups = var.allowed_security_group_ids
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "cloud-project-rds-sg"
  })
}

resource "aws_db_instance" "this" {
  identifier = "cloud-project-database"

  engine         = var.engine
  engine_version = var.engine_version
  instance_class = var.instance_class

  allocated_storage = var.allocated_storage
  db_name           = var.db_name
  username          = var.username
  password          = var.password

  db_subnet_group_name       = aws_db_subnet_group.this.name
  vpc_security_group_ids     = [aws_security_group.this.id]
  publicly_accessible        = var.publicly_accessible
  port                       = var.port
  skip_final_snapshot        = var.skip_final_snapshot
  deletion_protection        = false
  multi_az                   = false
  auto_minor_version_upgrade = true

  tags = merge(var.tags, {
    Name = "cloud-project-database"
  })
}

