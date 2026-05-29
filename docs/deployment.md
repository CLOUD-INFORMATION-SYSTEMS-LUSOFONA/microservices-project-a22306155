# Deployment Guide

Este documento descreve o passo-a-passo completo para deployar o projeto em AWS.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Manual Local Setup](#manual-local-setup)
3. [Deploy Infrastructure](#deploy-infrastructure)
4. [Deploy Applications](#deploy-applications)
5. [Verification](#verification)
6. [Troubleshooting](#troubleshooting)
7. [Cleanup](#cleanup)

---

## Prerequisites

### Software Required

- **Terraform** >= 1.6.0 ([install](https://www.terraform.io/downloads))
- **AWS CLI** (v2) ([install](https://aws.amazon.com/cli/))
- **Ansible** >= 2.13 ([install](https://docs.ansible.com/ansible/latest/installation_guide/))
- **Docker** (for local image building)
- **Git**
- **SSH client** (for EC2 access)

### AWS Account Requirements

- Active AWS account with sufficient permissions
- AWS credentials configured locally via `aws configure` or environment variables
- Key pair created in AWS EC2 console (`miguelrodr1.pem` or your key name)
- S3 bucket for Terraform state (optional but recommended for production)

### GitHub Setup

- Repository with branch protection on `main`
- GitHub OIDC role created in AWS
- Secrets configured in GitHub repo settings:
  - `AWS_ROLE_TO_ASSUME` (ARN of OIDC role)
  - `DB_PASSWORD` (RDS master password)
  - `TF_KEY_NAME` (AWS key pair name)
  - `DOCKERHUB_USERNAME` (optional, for image push)
  - `DOCKERHUB_TOKEN` (optional, for image push)

---

## Manual Local Setup

### 1. Clone Repository

```powershell
# Clone the repo
git clone https://github.com/YOUR_USERNAME/microservices-project-a22306155.git
cd microservices-project-a22306155
```

### 2. Configure AWS Credentials

```powershell
# Option A: Use AWS CLI configuration
aws configure
# Enter: AWS Access Key ID, Secret Access Key, Region (eu-central-1), Output format (json)

# Option B: Set environment variables
$env:AWS_ACCESS_KEY_ID = "YOUR_ACCESS_KEY"
$env:AWS_SECRET_ACCESS_KEY = "YOUR_SECRET_KEY"
$env:AWS_DEFAULT_REGION = "eu-central-1"
```

### 3. Prepare Terraform Variables

```powershell
# Copy example to actual terraform vars file
Copy-Item infra/terraform/terraform.tfvars.example infra/terraform/terraform.tfvars

# Edit with your actual values (key_name, db_password, etc.)
# Use your preferred editor (VS Code, Notepad, etc.)
code infra/terraform/terraform.tfvars
```

**Important fields to update:**
- `key_name` — your EC2 key pair name (e.g., "miguelrodr1")
- `db_password` — strong random password for RDS
- `aws_region` — your preferred region (e.g., "eu-central-1")

### 4. Validate Terraform Configuration

```powershell
cd infra/terraform

# Format code
terraform fmt -recursive

# Initialize (downloads providers)
terraform init -input=false

# Validate syntax
terraform validate

# Plan (shows what will be created)
terraform plan -no-color -out=tfplan
```

Check the plan output for any errors before proceeding.

---

## Deploy Infrastructure

### Step 1: Apply Terraform

```powershell
cd infra/terraform

# Apply the plan (creates VPC, EC2, RDS)
terraform apply tfplan

# Wait ~5-10 minutes for resources to be created
# RDS creation takes the longest
```

### Step 2: Capture Outputs

```powershell
# Display all outputs
terraform output -json | Tee-Object outputs.json

# Or individual outputs
$EC2_IP = terraform output -raw compute_public_ip
$DB_ENDPOINT = terraform output -raw database_endpoint
$RDS_PORT = terraform output -raw database_port

Write-Host "EC2 Public IP: $EC2_IP"
Write-Host "RDS Endpoint: $DB_ENDPOINT:$RDS_PORT"
```

Store these values for later use.

### Step 3: Verify AWS Resources

Log into AWS Console and verify:
- **VPC** created with correct CIDR (10.8.0.0/16)
- **Subnets** (2 public, 2 private across AZs)
- **EC2 instance** running in public subnet
- **RDS database** running in private subnet
- **Security groups** properly configured

---

## Deploy Applications

### Step 1: Prepare Ansible Inventory

Create or update `infra/ansible/inventory.ini`:

```ini
[web_servers]
web1 ansible_host=<EC2_PUBLIC_IP> ansible_user=ec2-user

[all:vars]
ansible_ssh_private_key_file=~/path/to/miguelrodr1.pem
ansible_python_interpreter=/usr/bin/python
```

Replace `<EC2_PUBLIC_IP>` with the output from `terraform output compute_public_ip`.

### Step 2: Build Docker Images

```powershell
# Build all services
cd <repo-root>

docker build -t miguelrodr1gues/api-gateway:latest ./services/api-gateway
docker build -t miguelrodr1gues/product-service:latest ./services/product-service
docker build -t miguelrodr1gues/user-service:latest ./services/user-service
docker build -t miguelrodr1gues/order-service:latest ./services/order-service
```

### Step 3: (Optional) Push to Docker Hub

```powershell
# Login to Docker Hub
docker login

# Push images
docker push miguelrodr1gues/api-gateway:latest
docker push miguelrodr1gues/product-service:latest
docker push miguelrodr1gues/user-service:latest
docker push miguelrodr1gues/order-service:latest
```

### Step 4: Run Ansible Playbook

```powershell
cd infra/ansible

# Test connectivity
ansible -i inventory.ini web_servers -m ping

# Run playbook (installs Docker, pulls images, runs containers)
ansible-playbook -i inventory.ini configure-ec2.yml -vvv
```

During playbook execution:
- System updates
- Docker installation
- Java + Maven installation
- Application repository cloned
- Application built (if applicable)
- Docker containers started

### Step 5: Verify Containers Running

```powershell
# SSH into EC2
ssh -i ~/miguelrodr1.pem ec2-user@<EC2_PUBLIC_IP>

# List running containers
docker ps

# Check logs
docker logs <container_id>

# Test API endpoint
curl http://localhost:8080/health
```

---

## Verification

### Health Checks Checklist

- [ ] SSH into EC2 succeeds
- [ ] `docker ps` shows 4 containers running (api-gateway, product-service, user-service, order-service)
- [ ] `curl http://localhost:8080/health` returns HTTP 200
- [ ] `curl http://<EC2_PULIC_IP>:8080/health` accessible from local machine
- [ ] RDS instance is in "Available" state (AWS Console)
- [ ] Services can connect to RDS (check logs for DB connection errors)

### Example Verification Commands

```powershell
# From local machine
$EC2_IP = terraform output -raw compute_public_ip

# Test API Gateway
curl http://$EC2_IP:8080/health

# Test Product Service (internal)
# ssh -i key.pem ec2-user@$EC2_IP
# docker exec api-gateway curl http://localhost:8082/health

# Test database connectivity
# From EC2: psql -h <DB_ENDPOINT> -U dr1gues -d cloudprojectdb
```

---

## Troubleshooting

### Common Issues

#### 1. Terraform Init Fails (Backend State)

**Error**: `Failed to get existing state`

**Solution**:
```powershell
# If using local state (default), this is normal on first run
# If using S3 backend, ensure bucket exists and you have permissions

# Debug:
terraform init -input=false -upgrade
```

#### 2. EC2 Instance Cannot Be Reached

**Error**: `Connection refused` or timeout on SSH

**Solution**:
```powershell
# Check security group allows port 22
aws ec2 describe-security-groups --query 'SecurityGroups[*].[GroupName,IpPermissions]'

# Check instance is running
aws ec2 describe-instances --query 'Reservations[*].Instances[*].[InstanceId,State.Name,PublicIpAddress]'

# Manually add inbound rule (if needed)
aws ec2 authorize-security-group-ingress --group-id sg-xxxxx --protocol tcp --port 22 --cidr 0.0.0.0/0
```

#### 3. Ansible Playbook Fails with "Python 2 yum module needed"

**Error**: `The Python 2 yum module is needed for this module`

**Solution**: Already fixed in the playbook; uses `dnf` for AL2023. If error persists:
```bash
# SSH into EC2 and install Python 2
sudo yum install -y python2
sudo update-alternatives --install /usr/bin/python python /usr/bin/python2 1
```

#### 4. Docker Images Cannot Be Pulled

**Error**: `Error response from daemon: pull access denied`

**Solution**:
```powershell
# Ensure images are pushed to Docker Hub (or use local build)
docker build -t <image>:latest ./services/<service>

# Or login and push
docker login
docker push <image>:latest
```

#### 5. RDS Connection Fails

**Error**: `psql: could not connect to server: Connection refused`

**Solution**:
```powershell
# Check RDS is in "Available" state
aws rds describe-db-instances --query 'DBInstances[*].[DBInstanceIdentifier,DBInstanceStatus,Endpoint]'

# Check security group allows port 5432 from EC2 SG
aws ec2 describe-security-groups --query 'SecurityGroups[*].[GroupName,IpPermissions[*].[FromPort,ToPort,IpProtocol,UserIdGroupPairs]]'

# Wait for RDS to finish initialization (can take 5+ minutes)
```

### Debug Commands

```bash
# SSH into EC2
ssh -i ~/miguelrodr1.pem ec2-user@<EC2_IP>

# Check Docker daemon
sudo systemctl status docker

# Check container logs
docker logs <container_id> -f

# Network debugging
docker network ls
docker inspect bridge

# Database connectivity test
# (if PostgreSQL client installed)
psql -h <RDS_ENDPOINT> -U dr1gues -d cloudprojectdb -c "SELECT 1;"
```

---

## Cleanup

### Destroy All Resources

```powershell
cd infra/terraform

# Plan destruction
terraform plan -destroy -out=destroy_plan

# Apply destruction (WARNING: irreversible)
terraform apply destroy_plan

# Verify in AWS Console that resources are gone
```

### Partial Cleanup (if needed)

```powershell
# Destroy specific resource
terraform destroy -target=aws_db_instance.this
terraform destroy -target=aws_instance.this

# Refresh state (if resources deleted manually)
terraform refresh
```

---

## Post-Deployment

### Monitoring

- Set up CloudWatch alarms for EC2 and RDS
- Enable VPC Flow Logs for network debugging
- Configure RDS backups

### Security Hardening

- Restrict `allowed_cidr_blocks` from "0.0.0.0/0" to your IP range
- Rotate RDS master password periodically
- Enable RDS encryption
- Review IAM OIDC role permissions

### Backup

- Enable automated RDS backups
- Snapshot EC2 volumes
- Export Terraform state to S3 with versioning

---

## Reference

- [Terraform AWS VPC Module Docs](https://registry.terraform.io/modules/terraform-aws-modules/vpc/aws/)
- [AWS RDS User Guide](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/)
- [Ansible AWS EC2 Module](https://docs.ansible.com/ansible/latest/collections/amazon/aws/ec2_module.html)
- [Docker Compose Reference](https://docs.docker.com/compose/compose-file/)

