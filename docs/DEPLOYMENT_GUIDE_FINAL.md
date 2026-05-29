# 🎯 Game Plan: Complete Deployment (Days 7-11)

## Status Atual (28 Maio 2026)

✅ Infrastructure code está **100% pronto**
✅ Terraform valida sem erros
✅ Ansible playbooks estão prontos
✅ Docker Compose configurado com SQS
✅ Documentação completa

⏳ **Faltam:** Executar deployment e testes

---

## 📋 Checklist Pré-Deployment

Antes de executar qualquer coisa, certifique-se de:

### 1. AWS Account Setup ✅
- [ ] Conta AWS ativa
- [ ] Credenciais AWS CLI configuradas
- [ ] Região padrão: `eu-central-1`

Verificar:
```powershell
aws sts get-caller-identity
aws ec2 describe-regions --region-names eu-central-1
```

### 2. GitHub Setup ✅
- [ ] Repositório criado
- [ ] Branch `main` criado
- [ ] Branch protection rules configuradas

```bash
# Requerimentos:
# - 1 approval antes de merge
# - Status checks devem passar
```

### 3. GitHub Secrets Configurados 🔴 CRÍTICO
No repositório GitHub, ir a **Settings** → **Secrets and variables** → **Actions** e criar:

```
AWS_ROLE_TO_ASSUME = arn:aws:iam::<ACCOUNT_ID>:role/github-actions-role
TF_KEY_NAME = your-ec2-keypair-name
DB_PASSWORD = YourSecurePassword123!
```

### 4. SSH Key Pair Criada 🔴 CRÍTICO
Na consola AWS:
```bash
aws ec2 create-key-pair --key-name <TF_KEY_NAME> --region eu-central-1 --query 'KeyMaterial' --output text > <key>.pem
chmod 600 <key>.pem
```

### 5. OIDC Role Criada 🔴 CRÍTICO
Criar IAM role `github-actions-role` com:
- Trust policy: GitHub repository
- Permissions: EC2, RDS, SQS, S3, IAM:PassRole

**Ou usar:** `scripts/bootstrap-terraform-backend.ps1` (também cria S3 backend)

---

## 🚀 Deployment Steps (In Order)

### Step 1: Create Terraform Variables File

Copiar do template:
```bash
cd infra/terraform
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars`:
```hcl
aws_region            = "eu-central-1"
project_name          = "cloud-project"
key_name              = "your-ec2-keypair"
db_password           = "YourSecurePassword123!"
instance_type         = "t3.micro"  # Free tier eligible
db_instance_class     = "db.t3.micro"
allowed_cidr_blocks   = ["0.0.0.0/0"]  # CHANGE to your IP for production!
```

### Step 2: Test Terraform Locally

```powershell
# Format
terraform fmt -recursive

# Validate
terraform validate

# Plan (dry-run)
terraform plan -out=tfplan
```

Review the plan output for:
- ✅ VPC resources
- ✅ EC2 instance
- ✅ RDS database
- ✅ SQS queues

### Step 3: Deploy Infrastructure

```powershell
# Apply
terraform apply tfplan
```

**Capture outputs:**
```powershell
terraform output -json > deployment-outputs.json

# Or individually:
$EC2_IP = terraform output -raw compute_public_ip
$RDS_ENDPOINT = terraform output -raw database_endpoint
$SQS_QUEUE = terraform output -raw messaging_product_events_queue_url

Write-Host "EC2 IP: $EC2_IP"
Write-Host "RDS Endpoint: $RDS_ENDPOINT"
Write-Host "SQS Queue: $SQS_QUEUE"
```

**Save these values!** You'll need them for Ansible.

### Step 4: Configure Ansible Inventory

Edit `ansible/inventory.ini`:
```ini
[web_servers]
ec2_prod ansible_host=<EC2_IP> ansible_user=ec2-user ansible_ssh_private_key_file=~/.ssh/<key>.pem

[web_servers:vars]
ansible_python_interpreter=/usr/bin/python3
```

### Step 5: Run Ansible Playbooks

**Playbook 1: Configure EC2 (Install Docker, etc.)**
```powershell
ansible-playbook -i ansible/inventory.ini ansible/playbooks/configure-ec2.yml -vvv
```

Expected output:
```
✓ Docker installed
✓ Docker Compose plugin installed  
✓ appuser created
✓ /opt/app directory created
```

**Playbook 2: Deploy Services**
```powershell
ansible-playbook -i ansible/inventory.ini ansible/playbooks/deploy-app.yml \
  --extra-vars "rds_endpoint=<RDS_ENDPOINT> db_password=<DB_PASSWORD> sqs_queue_url=<SQS_QUEUE>" \
  -vvv
```

Expected output:
```
✓ docker-compose.yml copied
✓ .env file created
✓ Images pulled
✓ Services started
✓ Health check: API Gateway responding
```

### Step 6: Verify Services

SSH into EC2:
```bash
ssh -i ~/.ssh/<key>.pem ec2-user@<EC2_IP>

# Once connected:
docker compose -f /opt/app/docker-compose.yml ps
docker compose -f /opt/app/docker-compose.yml logs -f
```

Test endpoints:
```powershell
# From your local machine:
curl http://<EC2_IP>:8080/actuator/health
curl http://<EC2_IP>:8080/api/users
curl http://<EC2_IP>:8080/api/products
```

---

## 📊 ExpectedOutput After Deployment

### EC2 Instance
```
✓ Public IP: XXX.XXX.XXX.XXX
✓ Security Group: allows ports 22, 8080-8083
✓ Docker Compose running 4 services
```

### RDS Database
```
✓ PostgreSQL 17 running in private subnet
✓ Accessible only from EC2 security group
✓ Database created: cloudprojectdb
```

### SQS Queues
```
✓ product-events (Standard)
✓ product-events.fifo (FIFO)
✓ product-events-dlq (Dead-letter)
```

### Running Services
```
✓ api-gateway: 8080
✓ user-service: 8081  
✓ product-service: 8082
✓ order-service: 8083
```

---

## 🧪 Testing Checklist

After deployment, verify:

- [ ] SSH into EC2
- [ ] `docker ps` shows 4 containers running
- [ ] `curl http://localhost:8080/actuator/health` returns 200 OK
- [ ] `curl http://localhost:8081/actuator/health` returns 200 OK (user-service)
- [ ] `curl http://localhost:8082/actuator/health` returns 200 OK (product-service)
- [ ] `curl http://localhost:8083/actuator/health` returns 200 OK (order-service)
- [ ] Services can communicate (API Gateway → services)
- [ ] Database connection works (services → RDS)
- [ ] SQS message flow works (producer → queue → consumer)

### Manual SQS Test (Optional)
```bash
# Publish message to product-events queue
aws sqs send-message \
  --queue-url <SQS_QUEUE_URL> \
  --message-body '{"productId": 1, "name": "Test Product"}' \
  --region eu-central-1

# Check order-service logs for consumption
docker compose -f /opt/app/docker-compose.yml logs order-service
```

---

## 🔧 Troubleshooting

### Services not starting?
```bash
ssh -i ~/.ssh/<key>.pem ec2-user@<EC2_IP>
docker compose -f /opt/app/docker-compose.yml logs
```

### RDS connection failing?
- Check security groups: EC2 → RDS on port 5432
- Verify `.env` file: `cat /opt/app/.env`
- Check credentials: `echo $DB_PASSWORD`

### Docker images not found?
- Build locally: `docker build -t <image> ./services/<service>/`
- Push to Docker Hub: `docker push <image>`
- Update docker-compose.yml with correct image names

### Terraform state issues?
```powershell
# If stuck, reset local state:
rm terraform.tfstate terraform.tfstate.backup .terraform.lock.hcl
terraform init
```

---

## 📸 Screenshots for Defense

Capture these for your presentation:

1. Terraform plan output
2. Terraform apply success
3. EC2 instance in AWS Console
4. RDS database in AWS Console  
5. SQS queues in AWS Console
6. `docker ps` output
7. Health endpoint response
8. Service logs
9. Git commit history
10. GitHub Actions workflow passing

---

## ⏱️ Estimated Timelines

- **Setup AWS & GitHub:** 15-30 minutes
- **Terraform init & plan:** 5 minutes
- **Terraform apply:** 10-15 minutes
- **Ansible playbooks:** 10-15 minutes
- **Testing & verification:** 10 minutes
- **Troubleshooting (if needed):** 30+ minutes

**Total: 60-90 minutes for complete deployment**

---

## 📞 Quick Reference Commands

```powershell
# See all deployed resources
terraform output -json

# Destroy everything
terraform destroy -auto-approve

# SSH into EC2
ssh -i ~/.ssh/<key>.pem ec2-user@<EC2_IP>

# Run Ansible again (if changes made)
ansible-playbook -i ansible/inventory.ini ansible/deploy-app.yml --extra-vars "..."

# View service logs
docker compose -f /opt/app/docker-compose.yml logs -f <service-name>
```

---

## 🎯 Next Phase: Day 11 Defense

Once everything is running:

1. **Write Demo Script**
   - Explain architecture
   - Show API calls working
   - Demonstrate SQS message flow
   - Highlight security setup

2. **Performance Testing**
   - Load test endpoints
   - Check response times
   - Monitor resource usage

3. **Security Audit**
   - Review IAM permissions
   - Check security groups
   - Verify no secrets in code

4. **Documentation Review**
   - Ensure all files are complete
   - Verify commands work
   - Test from scratch (clean env)

5. **Team Rehearsal**
   - Each member knows their part
   - Practice Q&A
   - Time the demo (15-20 min)

---

**Last Updated:** 28 Maio 2026
**Status:** Ready for Deployment! 🚀

