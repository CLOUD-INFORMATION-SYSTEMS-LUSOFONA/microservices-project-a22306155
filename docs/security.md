# Security Guide

Este documento descreve o modelo de segurança, boas práticas implementadas e recomendações para produção.

## Table of Contents

1. [Network Security](#network-security)
2. [IAM & Authentication](#iam--authentication)
3. [Secrets Management](#secrets-management)
4. [Application Security](#application-security)
5. [Compliance & Auditing](#compliance--auditing)
6. [Security Checklist](#security-checklist)

---

## Network Security

### VPC Isolation

```
Internet (0.0.0.0/0)
    │
    ▼ (Port 22, 80, 443)
Public Subnets (EC2)
    │
    ├─► Private Subnets (RDS)  [NOT directly accessible from Internet]
    │
    └─► Route to IGW
```

**Current Configuration:**

- **Public Subnets**: EC2 instance
  - Inbound: 22 (SSH), 80 (HTTP), 443 (HTTPS), 8080-8083 (app ports)
  - Source: `0.0.0.0/0` (OPEN — restrict in production)
  - Outbound: All allowed

- **Private Subnets**: RDS database
  - Inbound: 5432 (PostgreSQL)
  - Source: EC2 security group only
  - Outbound: All allowed (for updates/patches)

### Network ACLs

- Default NACLs allow all traffic (inbound/outbound)
- **Recommendation**: Implement stricter NACLs in production:
  - Deny all by default
  - Explicitly allow required traffic (SSH, HTTP, HTTPS, app ports)

### NAT Gateway

**Current**: Not implemented
- Private subnets cannot initiate internet connections
- If RDS or containers need package updates, add NAT Gateway:

```hcl
# Add to modules/vpc/main.tf
resource "aws_nat_gateway" "this" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[0].id
}

resource "aws_eip" "nat" {
  domain = "vpc"
}

# Add route for private subnets
resource "aws_route" "private_nat" {
  route_table_id         = aws_route_table.private.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.this.id
}
```

---

## IAM & Authentication

### GitHub OIDC (Recommended)

**How it works:**

1. GitHub Actions uses OpenID Connect to get temporary AWS credentials
2. No long-lived AWS access keys needed
3. Temporary credentials expire after use

**Setup:**

```bash
# 1. Create OIDC provider in AWS
# (via AWS Console or Terraform)

# 2. Create IAM role with trust policy for GitHub

# 3. Grant role permissions for Terraform operations

# 4. Store role ARN in GitHub secret: AWS_ROLE_TO_ASSUME
```

**Security Benefits:**

- ✅ No credentials stored in GitHub
- ✅ Automatic credential rotation
- ✅ Audit trail in CloudTrail
- ✅ Fine-grained permissions via SCPs

### EC2 Instance Role (Future Enhancement)

Currently, EC2 uses SSH key for access. **Best practice**: Use IAM instance profile:

```hcl
# Add to modules/ec2/main.tf
resource "aws_iam_role" "ec2_role" {
  name = "cloud-project-ec2-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ec2_policy" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_iam_instance_profile" "ec2_profile" {
  role = aws_iam_role.ec2_role.name
}

resource "aws_instance" "this" {
  # ... existing config ...
  iam_instance_profile = aws_iam_instance_profile.ec2_profile.name
}
```

### SSH Key Management

**Current**: Manual key creation in AWS Console

**Best practices:**

- ✅ Store private key in secure location (e.g., ~/.ssh/ with mode 600)
- ✅ Never commit private key to Git
- ✅ Use SSH agent for key management
- ✅ Rotate keys regularly (at least annually)
- ✅ Use separate keys for dev/staging/production

---

## Secrets Management

### Current Approach (Development Only)

```hcl
variable "db_password" {
  type      = string
  sensitive = true
}
```

- Password stored in `terraform.tfvars` (local only, not in Git)
- Sensitive variables hidden from logs
- **NOT SUITABLE FOR PRODUCTION**

### Recommended Approach (AWS Secrets Manager)

```hcl
# Create secret in Secrets Manager
resource "aws_secretsmanager_secret" "db_password" {
  name = "cloud-project/db/password"
}

resource "aws_secretsmanager_secret_version" "db_password" {
  secret_id     = aws_secretsmanager_secret.db_password.id
  secret_string = var.db_password  # Or use random_password resource
}

# Reference in RDS module
data "aws_secretsmanager_secret_version" "db_password" {
  secret_id = aws_secretsmanager_secret.db_password.id
}

resource "aws_db_instance" "this" {
  password = jsondecode(data.aws_secretsmanager_secret_version.db_password.secret_string)
}
```

**Benefits:**

- ✅ Centralized secret storage
- ✅ Automatic rotation support
- ✅ Audit trail (CloudTrail)
- ✅ Fine-grained IAM policies
- ✅ Separate from infrastructure code

### GitHub Secrets (CI/CD Only)

Used only in GitHub Actions workflows:

- `AWS_ROLE_TO_ASSUME` — OIDC role ARN (not sensitive)
- `DB_PASSWORD` — RDS master password
- `TF_KEY_NAME` — EC2 key pair name
- `DOCKERHUB_TOKEN` — Docker Hub access token

**Best practices:**

- ✅ Mark secrets as "masked" in GitHub UI
- ✅ Rotate regularly
- ✅ Use fine-grained Personal Access Tokens (instead of personal credentials)
- ✅ Never commit `.env` files or `*.tfvars` with secrets

---

## Application Security

### Container Security

**Dockerfile best practices** (implemented):

✅ Multi-stage builds (reduce image size)
✅ Run as non-root user (Java default OK)
✅ FROM official base images (eclipse-temurin)
✅ No secrets in Docker images

**Future enhancements:**

- [ ] Scan images with Trivy or Snyk
- [ ] Use private Docker registry (ECR)
- [ ] Implement pod security policies (if using ECS/EKS)

### API Security

**Current (Dev Only):**

- No authentication on service endpoints
- Port 8080 open to `0.0.0.0/0`

**Production recommendations:**

- [ ] Implement API Gateway authentication (OAuth2, JWT)
- [ ] TLS/HTTPS for all traffic
- [ ] Rate limiting & DDoS protection (AWS Shield)
- [ ] API key rotation

### Database Security

**Current:**

- ✅ RDS in private subnet (not internet-accessible)
- ✅ Password stored as sensitive variable
- ✅ Security group restricted to EC2 SG
- ❌ Encryption at rest: NOT enabled
- ❌ Encryption in transit: NOT enforced

**Production recommendations:**

```hcl
resource "aws_db_instance" "this" {
  # ... existing config ...
  storage_encrypted = true
  kms_key_id        = aws_kms_key.rds.arn
  
  # Enforce SSL
  db_parameter_group_name = aws_db_parameter_group.this.name
}

resource "aws_db_parameter_group" "this" {
  family = "postgres17"
  
  parameter {
    name  = "rds.force_ssl"
    value = "1"
  }
}

# Backup configuration
resource "aws_db_instance" "this" {
  backup_retention_period = 30  # 30 days
  backup_window          = "03:00-04:00"  # UTC
  copy_tags_to_snapshot  = true
}
```

---

## Compliance & Auditing

### CloudTrail Logging

**Enable for production:**

```hcl
resource "aws_cloudtrail" "main" {
  name                  = "cloud-project-trail"
  s3_bucket_name        = aws_s3_bucket.cloudtrail.id
  is_multi_region_trail = true
  enable_log_file_validation = true
  depends_on = [aws_s3_bucket_policy.cloudtrail]
}
```

**Benefits:**

- ✅ Audit all API calls
- ✅ Compliance evidence (SOC2, ISO27001)
- ✅ Security incident investigation

### VPC Flow Logs

**Enable for production:**

```hcl
resource "aws_flow_log" "main" {
  iam_role_arn    = aws_iam_role.vpc_flow_logs.arn
  log_destination = aws_cloudwatch_log_group.vpc_flow_logs.arn
  traffic_type    = "ALL"  # ACCEPT, REJECT, or ALL
  vpc_id          = aws_vpc.this.id
}
```

**Use cases:**

- Traffic troubleshooting
- Security analysis
- Compliance audits

### Tags for Cost & Access Control

All resources tagged with:

```hcl
Project     = "CloudComputing"
Environment = "dev/prod"
Owner       = "Miguel"
CostCenter  = "Education"
ManagedBy   = "Terraform"
```

**IAM policies can reference tags:**

```json
{
  "Effect": "Allow",
  "Action": "ec2:*",
  "Resource": "*",
  "Condition": {
    "StringEquals": {
      "aws:ResourceTag/Project": "CloudComputing"
    }
  }
}
```

---

## Security Checklist

### Pre-Deployment

- [ ] Review `terraform plan` output for security implications
- [ ] Verify all secrets stored in GitHub Secrets (not in code)
- [ ] Confirm OIDC role permissions are minimal (least privilege)
- [ ] Remove any hardcoded AWS keys or credentials
- [ ] Test OIDC authentication locally (if possible)

### Post-Deployment

- [ ] Verify VPC flow logs enabled
- [ ] Confirm RDS in private subnet
- [ ] Check security group rules (EC2 & RDS)
- [ ] Verify EC2 instance security group allows only needed ports
- [ ] Test SSH access with correct key pair
- [ ] Verify database password is strong (>12 chars, special symbols)

### Production Checklist

- [ ] Enable RDS encryption at rest (KMS)
- [ ] Enable RDS automated backups (30+ days)
- [ ] Implement NAT Gateway for private subnet internet access
- [ ] Set up CloudTrail for API audit logging
- [ ] Enable VPC Flow Logs
- [ ] Implement CloudWatch alarms for unusual activity
- [ ] Use AWS Secrets Manager for credential rotation
- [ ] Implement MFA for IAM principals
- [ ] Configure S3 bucket versioning for Terraform state
- [ ] Enable S3 bucket encryption (KMS)
- [ ] Restrict `allowed_cidr_blocks` from "0.0.0.0/0" to corporate IP range
- [ ] Implement ASG + ALB for high availability
- [ ] Add WAF rules for API protection
- [ ] Enable GuardDuty for threat detection

### Ongoing Maintenance

- [ ] Weekly: Review CloudTrail logs for unauthorized access
- [ ] Monthly: Rotate RDS master password
- [ ] Quarterly: Review IAM permissions
- [ ] Annually: Rotate SSH keys

---

## References

- [AWS Well-Architected Framework — Security Pillar](https://docs.aws.amazon.com/wellarchitected/latest/security-pillar/welcome.html)
- [AWS IAM Best Practices](https://docs.aws.amazon.com/IAM/latest/UserGuide/best-practices.html)
- [GitHub Actions OIDC](https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/about-security-hardening-with-openid-connect)
- [RDS Security Groups](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/Overview.DBSecurityGroup.html)
- [Container Image Security Best Practices](https://docs.docker.com/develop/security-best-practices/)

