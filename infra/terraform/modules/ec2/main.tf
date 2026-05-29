data "aws_iam_role" "ec2_role" {
  name = "EC2S3AccessRole"
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "cloud-project-ec2-profile-${var.tags["Environment"]}"
  role = data.aws_iam_role.ec2_role.name
}

resource "aws_security_group" "this" {
  name        = lower("cloud-project-web-sg")
  description = "Security group for the EC2 instance"
  vpc_id      = var.vpc_id

  dynamic "ingress" {
    for_each = toset(var.allowed_ports)

    content {
      from_port   = ingress.value
      to_port     = ingress.value
      protocol    = "tcp"
      cidr_blocks = var.allowed_cidr_blocks
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "cloud-project-web-sg"
  })
}

resource "aws_instance" "this" {
  ami                         = var.ami_id
  instance_type               = var.instance_type
  subnet_id                   = var.subnet_id
  vpc_security_group_ids      = [aws_security_group.this.id]
  key_name                    = var.key_name
  associate_public_ip_address = var.associate_public_ip
  user_data                   = var.user_data
  user_data_replace_on_change = true

  iam_instance_profile = aws_iam_instance_profile.ec2_profile.name

  tags = merge(var.tags, {
    Name = "cloud-project-instance"
  })
}