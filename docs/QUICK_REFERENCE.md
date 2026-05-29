# ⚡ Quick Reference - Command Cheatsheet

## 🔧 Terraform Commands

```powershell
# Validate syntax
terraform fmt -recursive
terraform validate

# Plan changes (dry-run)
terraform plan -out=tfplan

# Apply changes
terraform apply tfplan

# View outputs
terraform output -json
terraform output -raw compute_public_ip
terraform output -raw database_endpoint

# Destroy everything
terraform destroy -auto-approve

# State management
terraform state list
terraform state show <resource>
```

---

## 🔄 Ansible Commands

```bash
# Ansible host setup
ansible-playbook -i ansible/inventory.ini ansible/playbooks/configure-ec2.yml -vvv

# Deploy services
ansible-playbook -i ansible/inventory.ini ansible/playbooks/deploy-app.yml \
  --extra-vars "rds_endpoint=<RDS> db_password=<PWD> sqs_queue_url=<URL>" \
  -vvv

# Test connectivity
ansible web_servers -i ansible/inventory.ini -m ping
```

---

## 🐳 Docker Commands

```bash
# Local testing
docker compose up -d
docker compose down

# View all images
docker images

# Build service image
cd services/<service>
docker build -t miguelrodr1gues/<service>:latest .
docker push miguelrodr1gues/<service>:latest
```

---

## ☁️ AWS CLI Commands

```bash
# Get caller identity (verify credentials)
aws sts get-caller-identity

# EC2 operations
aws ec2 describe-instances --region eu-central-1
aws ec2-instance-connect ssh --instance-id <id>

# RDS operations
aws rds describe-db-instances --region eu-central-1

# SQS operations
aws sqs send-message \
  --queue-url <URL> \
  --message-body '{"test": "message"}' \
  --region eu-central-1

aws sqs receive-message \
  --queue-url <URL> \
  --region eu-central-1

# S3 operations
aws s3 ls s3://my-terraform-state-bucket/
```

---

## 📋 Variable Files

### `infra/terraform/terraform.tfvars`
```hcl
aws_region              = "eu-central-1"
project_name            = "cloud-project"
key_name                = "your-ec2-keypair"
db_password             = "YourSecurePassword123!"
instance_type           = "t3.micro"
allowed_cidr_blocks     = ["0.0.0.0/0"]  # Change for production!
db_instance_class       = "db.t3.micro"
additional_tags = {
  Owner       = "Your Name"
  Environment = "dev"
}
```

### `ansible/inventory.ini`
```ini
[web_servers]
ec2_prod ansible_host=<EC2_IP> ansible_user=ec2-user ansible_ssh_private_key_file=~/.ssh/<key>.pem

[web_servers:vars]
ansible_python_interpreter=/usr/bin/python3
```

---

## 🔑 GitHub Secrets (Required)

Set these in **Settings → Secrets and variables → Actions**:

```
AWS_ROLE_TO_ASSUME    = arn:aws:iam::<ACCOUNT>:role/github-actions-role
TF_KEY_NAME           = your-ec2-keypair-name
DB_PASSWORD           = YourSecurePassword123!
```

---

## 🧪 Testing Commands

```bash
# Health check
curl http://<EC2_IP>:8080/actuator/health

# Service health (individual)
curl http://<EC2_IP>:8081/actuator/health  # user-service
curl http://<EC2_IP>:8082/actuator/health  # product-service
curl http://<EC2_IP>:8083/actuator/health  # order-service

# Docker status on EC2
ssh -i ~/.ssh/<key>.pem ec2-user@<EC2_IP>
docker compose -f /opt/app/docker-compose.yml ps
docker compose -f /opt/app/docker-compose.yml logs -f
```

---

## 🚀 Deployment Workflow

```powershell
# Step 1: Prepare
cd infra/terraform
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with actual values

# Step 2: Plan
terraform validate
terraform plan -out=tfplan

# Step 3: Deploy
terraform apply tfplan
$EC2_IP = terraform output -raw compute_public_ip
$RDS_ENDPOINT = terraform output -raw database_endpoint
$SQS_QUEUE = terraform output -raw messaging_product_events_queue_url

# Step 4: Configure Ansible
# Edit ansible/inventory.ini with EC2_IP

# Step 5: Deploy services
cd ../..
ansible-playbook -i ansible/inventory.ini ansible/configure-ec2.yml -vvv
ansible-playbook -i ansible/inventory.ini ansible/deploy-app.yml \
  --extra-vars "rds_endpoint=$RDS_ENDPOINT db_password=<PWD> sqs_queue_url=$SQS_QUEUE" \
  -vvv

# Step 6: Test
curl http://$EC2_IP:8080/actuator/health
```

---

## 📊 Useful Queries

```bash
# Find resource in Terraform state
terraform state list | grep -i "aws_"

# Show specific resource
terraform state show 'module.compute.aws_instance.this'

# Get all outputs
terraform output -json > outputs.json

# Count resources
terraform state list | wc -l
```

---

## 🐛 Troubleshooting Quick Fixes

```bash
# Services won't start?
ssh -i ~/.ssh/<key>.pem ec2-user@<EC2_IP>
docker compose -f /opt/app/docker-compose.yml logs
env | grep RDS  # Check environment variables

# Terraform lock issues?
rm .terraform.lock.hcl
terraform init

# SSH key permissions wrong?
chmod 600 ~/.ssh/<key>.pem

# Can't connect to RDS?
# Check security groups:
aws ec2 describe-security-groups --region eu-central-1
# Verify EC2 SG can access RDS port 5432

# SQS not receiving messages?
aws sqs get-queue-attributes --queue-url <URL> --attribute-names All
```

---

## 📝 File Structure Review

```
microservices-project-a22306155/
├── infra/
│   ├── terraform/
│   │   ├── main.tf                    # Root module
│   │   ├── variables.tf               # Input vars
│   │   ├── outputs.tf                 # Output values
│   │   ├── backend.tf                 # Remote state (template)
│   │   ├── modules/
│   │   │   ├── vpc/                   # VPC module
│   │   │   ├── ec2/                   # Compute module
│   │   │   ├── rds/                   # Database module
│   │   │   └── sqs/                   # Messaging module (NEW)
│   │   └── terraform.tfvars.example   # Variables template
│   └── ansible/
│       ├── inventory.ini              # Hosts
│       ├── configure-ec2.yml          # Setup playbook
│       └── docker-compose.yml         # Production compose
├── ansible/
│   ├── configure-ec2.yml              # Setup playbook (root level)
│   ├── deploy-app.yml                 # Deploy playbook (root level)
│   ├── docker-compose.yml             # Production compose
│   └── inventory.ini                  # Inventory template
├── services/                          # Microservices
│   ├── api-gateway/
│   ├── user-service/
│   ├── product-service/
│   └── order-service/
├── docs/                              # Documentation
│   ├── architecture.md
│   ├── deployment.md
│   ├── security.md
│   ├── ROADMAP_STATUS.md              # Progress (NEW)
│   ├── DEPLOYMENT_GUIDE_FINAL.md      # Final guide (NEW)
│   └── EXECUTIVE_SUMMARY.md           # Summary (NEW)
├── scripts/
│   ├── bootstrap-terraform-backend.ps1
│   ├── demo-test.ps1                  # Test script (NEW)
│   └── ...
└── docker-compose.yml                 # Local dev compose
```

---

## ✅ Pre-Deployment Checklist

- [ ] AWS account active + credentials configured
- [ ] EC2 key pair created: `aws ec2 create-key-pair --key-name <NAME>`
- [ ] OIDC role created in AWS IAM
- [ ] GitHub Actions secrets configured
- [ ] GitHub branch protection enabled
- [ ] All files formatted: `terraform fmt -recursive`
- [ ] Terraform validates: `terraform validate`
- [ ] Ansible syntax check: `ansible-playbook --syntax-check`
- [ ] Docker images accessible (DockerHub)
- [ ] Repository cloned/staged for deployment

---

## 📞 Emergency Contacts (For You)

| Issue | Solution |
|-------|----------|
| Terraform error | Read error message, check variable types |
| Ansible failed | SSH to EC2, check logs, verify credentials |
| Services not running | `docker ps`, `docker logs <container>` |
| RDS connection failed | Check security groups, .env file |
| SQS not working | Verify IAM role, queue URL, region |
| GitHub Actions failing | Check workflow logs, secrets, permissions |

---

## 🎯 Success Indicators

- ✅ `terraform validate` outputs: "Success! The configuration is valid."
- ✅ `terraform plan` shows all resources with no errors
- ✅ `terraform apply` completes successfully
- ✅ Ansible playbooks run without errors
- ✅ `docker ps` shows 4 containers running
- ✅ `curl http://localhost:8080/actuator/health` returns 200 OK
- ✅ No error messages in service logs
- ✅ GitHub Actions workflows passing

---

*Use this as your deployment reference sheet!* 📋

**Last Updated:** 28 Maio 2026

