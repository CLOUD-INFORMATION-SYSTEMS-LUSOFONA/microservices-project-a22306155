# Ansible Deployment Guide

Automate EC2 setup and microservices deployment using Ansible playbooks.

## Architecture

```
Terraform (infra/terraform/)
    ↓ Creates
EC2 Instance (Amazon Linux 2023)
    ↓ Configured by
Ansible (ansible/)
    ├─ playbooks/
    │  ├─ configure-ec2.yml (setup Docker, users, directories)
    │  └─ deploy-app.yml (docker-compose, health checks)
    ├─ inventory.ini (EC2 host configuration)
    ├─ docker-compose.yml (services definition)
    └─ main.yml (master orchestration)
        ↓ Runs
Docker Compose on EC2
    ├─ api-gateway (8080)
    ├─ product-service (8082)
    ├─ user-service (8081)
    ├─ order-service (8083)
    └─ PostgreSQL (5432)
```

## Files

| File | Purpose |
|------|---------|
| `playbooks/configure-ec2.yml` | Install Docker, create users, setup directories |
| `playbooks/deploy-app.yml` | Copy docker-compose.yml, start services, health checks |
| `docker-compose.yml` | Define 4 services + PostgreSQL + networking |
| `inventory.ini` | EC2 host configuration |
| `main.yml` | Master playbook (optional orchestration) |

## Prerequisites

### Local Machine

- **Ansible** >= 2.13
  ```bash
  pip install ansible
  ansible --version
  ```
- **SSH key pair** (matching AWS EC2)
  ```bash
  ls ~/miguelrodr1.pem
  chmod 600 ~/miguelrodr1.pem
  ```

### AWS EC2

- **Public IP** of EC2 instance
- **Security group** allows:
  - Port 22 (SSH)
  - Ports 8080, 8081, 8082, 8083 (app ports)
  - Port 5432 (PostgreSQL, internal only)

## Setup

### 1. Update Inventory

Edit `infra/ansible/inventory.ini`:

```ini
[web_servers]
web1 ansible_host=<EC2_PUBLIC_IP> ansible_user=ec2-user

[all:vars]
ansible_ssh_private_key_file=~/miguelrodr1.pem
ansible_python_interpreter=/usr/bin/python
```

Replace `<EC2_PUBLIC_IP>` with your Terraform output:

```powershell
terraform output -raw compute_public_ip
```

### 2. Test SSH Connectivity

```bash
ansible -i inventory.ini web_servers -m ping
# Expected: pong on web1
```

## Deployment

### Option 1: Individual Playbooks (Modular)

#### Step 1: Configure EC2

```bash
cd infra/ansible

ansible-playbook -i inventory.ini configure-ec2.yml -vvv
# Expected:
# - Docker installed
# - appuser created
# - /opt/app directory created
```

#### Step 2: Deploy Applications

```bash
# Set RDS password (from Terraform outputs or tfvars)
export DB_PASSWORD="your-db-password"

ansible-playbook -i inventory.ini deploy-app.yml -vvv
# Expected:
# - docker-compose.yml copied
# - Images pulled
# - Services started
# - Health checks pass
```

### Option 2: Master Playbook (All-in-One)

```bash
cd infra/ansible

export DB_PASSWORD="your-db-password"

ansible-playbook -i inventory.ini main.yml -vvv
```

This runs both configure-ec2.yml and deploy-app.yml in sequence.

## Verification

### Check Services Are Running

```bash
# Via Ansible ad-hoc
ansible -i inventory.ini web_servers -m docker_container_info

# Or SSH into EC2
ssh -i ~/miguelrodr1.pem ec2-user@<EC2_IP>

# Then:
docker ps
docker-compose -f /opt/app/docker-compose.yml logs -f
```

### Health Checks

```bash
# From your local machine
curl http://<EC2_PUBLIC_IP>:8080/actuator/health
curl http://<EC2_PUBLIC_IP>:8082/actuator/health
curl http://<EC2_PUBLIC_IP>:8081/actuator/health
curl http://<EC2_PUBLIC_IP>:8083/actuator/health

# Expected: {"status":"UP"}
```

### View Logs

```bash
# SSH into EC2
ssh -i ~/miguelrodr1.pem ec2-user@<EC2_IP>

# View all logs
docker-compose -f /opt/app/docker-compose.yml logs -f

# View specific service logs
docker logs api-gateway -f
docker logs product-service -f
```

## Troubleshooting

### Connection Refused

**Error**: `Failed to connect to the host via ssh`

**Fix**:
```bash
# Check SSH key permissions
chmod 600 ~/miguelrodr1.pem

# Test SSH directly
ssh -i ~/miguelrodr1.pem ec2-user@<EC2_IP>

# If fails, check security group allows port 22
aws ec2 describe-security-groups --group-ids sg-xxxx
```

### Ansible Module Not Found

**Error**: `ModuleNotFoundError: docker`

**Fix**:
```bash
pip install docker
pip install docker-compose
```

### Database Password Not Set

**Error**: `DB_PASSWORD: value required`

**Fix**:
```bash
# Set environment variable before running playbook
export DB_PASSWORD="your-password"

# Or pass as extra var
ansible-playbook -i inventory.ini deploy-app.yml -e "db_password=your-password"
```

### Services Won't Start

**Symptoms**: `docker ps` shows exited containers

**Debug**:
```bash
# Check logs
docker logs product-service

# Common issues:
# - Database not ready (wait 30 seconds)
# - Wrong database password
# - Docker image doesn't exist on DockerHub

# Restart services
docker-compose -f /opt/app/docker-compose.yml restart

# Or redeploy
ansible-playbook -i inventory.ini deploy-app.yml --tags "deploy"
```

### Docker Images Not Found

**Error**: `pull access denied`

**Fix**:

1. Ensure images are pushed to DockerHub:
   ```bash
   # Build locally
   docker build -t miguelrodr1gues/product-service:latest ./services/product-service
   
   # Login to DockerHub
   docker login
   
   # Push
   docker push miguelrodr1gues/product-service:latest
   ```

2. Or update `docker-compose.yml` to use local images:
   ```yaml
   image: miguelrodr1gues/product-service:latest
   # Change to:
   image: localhost:5000/product-service:latest  # local registry
   ```

## Configuration

### docker-compose.yml Variables

Edit `infra/ansible/docker-compose.yml` to:

- Change image tags: `miguelrodr1gues/product-service:latest` → `v2.0.0`
- Adjust ports: `8082:8080` → `9082:8080`
- Change database: `postgres:17-alpine` → `mysql:8.0`
- Add environment variables (Kafka bootstrap, Redis, etc.)

### Ansible Variables

Edit `deploy-app.yml` vars section:

```yaml
vars:
  docker_images:
    - your-org/service:v2.0.0  # Update versions
  docker_registry_url: ""       # Add private registry
  docker_registry_username: ""  # Add credentials
```

## Advanced Options

### Zero-Downtime Deployment

The deploy-app.yml uses `docker-compose up -d --pull always` with `recreate: smart` to minimize downtime:

- Only recreates containers if images changed
- Keeps other containers running
- Graceful shutdown (15s timeout)

### Custom Health Checks

Modify `docker-compose.yml` healthcheck blocks:

```yaml
healthcheck:
  test: ["CMD", "curl", "-f", "http://localhost:8080/custom/health"]
  interval: 30s
  timeout: 10s
  retries: 3
  start_period: 60s
```

### Persistent Data

Data is stored in Docker volumes:

```bash
# View volumes on EC2
docker volume ls

# Inspect volume data
docker volume inspect microservices_postgres_data
```

## Cleanup

### Stop Services

```bash
# Via docker-compose
docker-compose -f /opt/app/docker-compose.yml down

# Keep volumes (data)
docker-compose -f /opt/app/docker-compose.yml down  # Keeps volumes

# Remove everything
docker-compose -f /opt/app/docker-compose.yml down -v  # Remove volumes too
```

### Remove EC2 Instance

```bash
# From repo root
cd infra/terraform

terraform destroy
# Confirm with 'yes'
```

## References

- [Ansible Docker Module](https://docs.ansible.com/ansible/latest/collections/community/docker/docker_container_module.html)
- [Docker Compose File Format](https://docs.docker.com/compose/compose-file/compose-file-v3/)
- [Spring Boot in Docker](https://spring.io/guides/gs/spring-boot-docker/)
- [PostgreSQL Docker Image](https://hub.docker.com/_/postgres)

## Support

For issues, check:
1. Ansible logs: `ansible-playbook -vvv`
2. Docker logs: `docker-compose logs`
3. SSH connectivity: `ssh -i key.pem ec2-user@ip`
4. Security groups: AWS Console → EC2 → Security Groups

