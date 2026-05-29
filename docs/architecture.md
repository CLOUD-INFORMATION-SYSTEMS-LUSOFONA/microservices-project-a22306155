# Cloud Computing Project — Architecture

## System Overview

Este projeto implementa uma **arquitetura microserviços em AWS** com deploy automatizado via Terraform, Docker, Ansible e GitHub Actions. O sistema é composto por:

- **VPC isolada** com subnets públicas (API Gateway, Web Services) e privadas (Banco de dados)
- **EC2 instance** em subnet pública para rodar containers Docker (via Ansible)
- **RDS PostgreSQL** em subnets privadas para persistência de dados
- **Docker containers** para cada serviço (product-service, user-service, order-service, api-gateway)
- **CI/CD pipeline** GitHub Actions para build/test/deploy automático
- **IaC (Terraform)** para reproducibilidade e versionamento de infraestrutura

---

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────────┐
│                          AWS Account (eu-central-1)                     │
│                                                                         │
│  ┌──────────────────────────────────────────────────────────────────┐  │
│  │                    VPC (10.8.0.0/16)                            │  │
│  │                                                                  │  │
│  │  ┌─────────────────────────┐   ┌──────────────────────────┐    │  │
│  │  │  Public Subnet 1 (AZ-a) │   │ Public Subnet 2 (AZ-b)  │    │  │
│  │  │  (10.8.1.0/24)          │   │ (10.8.2.0/24)            │    │  │
│  │  │                         │   │                          │    │  │
│  │  │  ┌─────────────────┐    │   │                          │    │  │
│  │  │  │   EC2 Instance  │    │   │                          │    │  │
│  │  │  │ (AL2023, t3.m)  │◄──┼───┼─ Internet Gateway        │    │  │
│  │  │  │  + Docker +     │    │   │                          │    │  │
│  │  │  │  Containers     │    │   │        (IGW)             │    │  │
│  │  │  └────────┬────────┘    │   │           ▲              │    │  │
│  │  │           │             │   │           │              │    │  │
│  │  ├───────────┼─────────────┤   ├───────────┼──────────────┤    │  │
│  │  │ Port 22, 80, 443        │   │ Route 0.0.0.0/0 → IGW   │    │  │
│  │  └──────────────────────────┘   └──────────────────────────┘    │  │
│  │                                                                  │  │
│  │  ┌─────────────────────────┐   ┌──────────────────────────┐    │  │
│  │  │ Private Subnet 1 (AZ-a) │   │Private Subnet 2 (AZ-b)  │    │  │
│  │  │ (10.8.10.0/24)          │   │ (10.8.11.0/24)           │    │  │
│  │  │                         │   │                          │    │  │
│  │  │  ┌─────────────────┐    │   │  ┌─────────────────┐     │    │  │
│  │  │  │                 │    │   │  │                 │     │    │  │
│  │  │  │  RDS PostgreSQL │◄───┼───┤──┤ CIDR: App SG    │     │    │  │
│  │  │  │  DB Instance    │    │   │  │ Port: 5432      │     │    │  │
│  │  │  │  (db.t3.micro)  │    │   │  │                 │     │    │  │
│  │  │  │                 │    │   │  └─────────────────┘     │    │  │
│  │  │  └─────────────────┘    │   │                          │    │  │
│  │  └─────────────────────────┘   └──────────────────────────┘    │  │
│  │                                                                  │  │
│  │  ┌──────────────────────────────────────────────────────────┐  │  │
│  │  │ Route Table (Private) — 0.0.0.0/0 → [NAT Gateway/None]  │  │  │
│  │  └──────────────────────────────────────────────────────────┘  │  │
│  │                                                                  │  │
│  └──────────────────────────────────────────────────────────────────┘  │
│                                                                         │
│  GitHub Actions                                                       │
│  ├─ terraform-plan.yml (PR trigger)                                  │
│  ├─ terraform-apply.yml (manual trigger)                             │
│  └─ image.yml (build & push Docker images)                           │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## Service Components

### 1. **API Gateway** (Port 8080)
- Spring Boot application
- Routes requests to backend services
- Exposed via EC2 public IP
- Container: `miguelrodr1gues/api-gateway:latest`

### 2. **Product Service** (Port 8082)
- Core business logic for products
- Connects to RDS PostgreSQL
- Container: `miguelrodr1gues/product-service:latest`

### 3. **User Service** (Port 8081)
- User management service
- Connects to RDS PostgreSQL
- Container: `miguelrodr1gues/user-service:latest`

### 4. **Order Service** (Port 8083)
- Order processing and management
- Connects to RDS PostgreSQL
- Produces/consumes events via SQS (future enhancement)
- Container: `miguelrodr1gues/order-service:latest`

---

## Data Flow

```
Internet User
     │
     ▼
EC2 Public IP (0.0.0.0/0 allowed on 80, 443, 22)
     │
     ├─► API Gateway (port 8080)
     │       │
     │       ├─► Product Service (port 8082)
     │       ├─► User Service (port 8081)
     │       └─► Order Service (port 8083)
     │
     ▼
RDS PostgreSQL (private subnet, port 5432)
     │
     └─► Application Data
```

---

## Deployment Pipeline

### VCS → CI/CD → Infrastructure → Application

1. **GitHub Push/PR**
   - Triggers `terraform-plan.yml` (format check, validate, plan)
   - Triggers `image.yml` (build Docker images, push to DockerHub)

2. **Code Review & Merge**
   - PR approved → merge to `main`
   - Branch protection ensures review + status checks pass

3. **Terraform Apply (Manual)**
   - `terraform-apply.yml` runs manually (workflow_dispatch)
   - Creates/updates AWS infrastructure (VPC, EC2, RDS)
   - Outputs: EC2 public IP, RDS endpoint, security group IDs

4. **Ansible Deployment**
   - Runs against EC2 instance
   - Installs Docker runtime
   - Pulls latest Docker images from DockerHub
   - Starts containers with proper networking (docker-compose or CLI)

5. **Health Checks**
   - Verify containers running: `docker ps`
   - Test API endpoint: `curl http://EC2_IP:8080/health`

---

## Infrastructure as Code (Terraform)

### Directory Structure

```
infra/terraform/
├── main.tf                 # Provider + module composition
├── variables.tf            # Input variables with validation
├── outputs.tf              # Outputs exposed to consumers
├── backend.tf              # Remote state configuration (S3 + DynamoDB)
├── terraform.tfvars.example # Example variable values
├── README.md               # Terraform module documentation
└── modules/
    ├── vpc/                # VPC, subnets, IGW, route tables
    │   ├── main.tf
    │   ├── variables.tf
    │   └── outputs.tf
    ├── ec2/                # EC2 instance + security group
    │   ├── main.tf
    │   ├── variables.tf
    │   └── outputs.tf
    └── rds/                # RDS database + security group
        ├── main.tf
        ├── variables.tf
        └── outputs.tf
```

### Key Outputs

After `terraform apply`, these outputs are available:

- `network_vpc_id` — VPC ID
- `network_public_subnet_ids` — Public subnet IDs (2 AZs)
- `network_private_subnet_ids` — Private subnet IDs (2 AZs)
- `compute_instance_id` — EC2 instance ID
- `compute_public_ip` — EC2 public IP (for SSH/HTTP)
- `compute_public_dns` — EC2 public DNS
- `database_endpoint` — RDS endpoint hostname
- `database_port` — RDS port (5432)

---

## Security Model

### Network Isolation

- **Public subnets**: EC2 instance only (exposed to 0.0.0.0/0 on ports 22, 80, 443)
- **Private subnets**: RDS database only (exposed to EC2 security group on port 5432)
- **No direct internet access** for RDS (no NAT Gateway configured yet)

### IAM & Credentials

- GitHub OIDC role: Assumes temporary AWS credentials (no hardcoded keys)
- RDS password: Stored as sensitive variable in terraform.tfvars (not in VCS)
- EC2 key pair: Created manually in AWS; referenced by name

### Tagging Strategy

All resources tagged with:
- `Project` — CloudComputing
- `Environment` — dev/staging/prod (via workspaces)
- `ManagedBy` — Terraform
- `Week` — cloud-project

Tags enable cost tracking, IAM policies, and resource organization.

---

## Development Workflow

### 1. Local Development

```bash
cd infra/terraform
terraform init -input=false
terraform fmt -recursive
terraform validate
terraform plan -out=tfplan -var="key_name=YOUR_KEY" -var="db_password=STRONG_PASSWORD"
terraform apply tfplan
```

### 2. GitHub Actions (Automated)

- PR on `infra/terraform/**` → runs `terraform-plan.yml`
- Merge to `main` → image build & push via `image.yml`
- Manual trigger → `terraform-apply.yml` applies infrastructure

### 3. Post-Deploy Verification

```bash
# Get EC2 public IP from output
EC2_IP=$(terraform output -raw compute_public_ip)

# SSH into instance
ssh -i "path/to/key.pem" ec2-user@$EC2_IP

# Check Docker containers
docker ps

# Test API
curl http://$EC2_IP:8080/health
```

---

## Future Enhancements

- [ ] Add NAT Gateway for private subnet internet access
- [ ] Implement SQS queue for event-driven communication
- [ ] Add CloudWatch monitoring and alarms
- [ ] Implement Auto Scaling Group for EC2
- [ ] Add ELB/ALB for load balancing
- [ ] S3 backend terraform state + DynamoDB locks
- [ ] Encrypted RDS storage
- [ ] VPC endpoints for AWS services

---

## References

- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest)
- [AWS VPC Best Practices](https://docs.aws.amazon.com/vpc/latest/userguide/VPC_Subnets.html)
- [RDS Security Groups](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/Overview.DBSecurityGroup.html)
- [GitHub OIDC](https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/about-security-hardening-with-openid-connect)

