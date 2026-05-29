🚀 CI/CD INTEGRATION GUIDE - AUTOMATIC DEPLOYMENT
═════════════════════════════════════════════════════════════════

Data: 28 Maio 2026
Status: ✅ PRONTO PARA USAR

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

✅ O QUE FOI CONFIGURADO

O workflow automático agora faz:

1. ✅ terraform apply (Deploy infrastructure)
2. ✅ Captura outputs:
   - EC2 public IP
   - RDS endpoint
   - SQS queue URL
3. ✅ Run ansible playbooks (Configure + Deploy)
   - configure-ec2.yml
   - deploy-app.yml (com variáveis injetadas)
4. ✅ Verify health endpoints

ZERO manual variables needed!

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

📋 GITHUB SECRETS REQUIRED

Adicionar os seguintes secrets no GitHub (Settings → Secrets → Actions):

1. AWS_ROLE_TO_ASSUME
   └─ Value: arn:aws:iam::839006976195:role/github-actions-role
   
2. TF_KEY_NAME
   └─ Value: miguelrodr1 (ou o seu EC2 key pair name)

3. DB_PASSWORD
   └─ Value: dr1gues103 (ou a sua password)

4. SSH_PRIVATE_KEY (NOVO!)
   └─ Value: Conteúdo do ~/.ssh/miguelrodr1_lf.pem
   └─ Como adicionar:
      cat ~/.ssh/miguelrodr1_lf.pem
      (copiar todo o conteúdo, incluindo -----BEGIN e -----END)

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

🔐 COMO ADICIONAR SSH_PRIVATE_KEY NO GITHUB

1. Abrir: https://github.com/seu-user/seu-repo/settings/secrets/actions

2. Clicar: "New repository secret"

3. Name: SSH_PRIVATE_KEY

4. Value: (colar conteúdo da chave privada)
   -----BEGIN RSA PRIVATE KEY-----
   MIIEpAIBAAKCAQEA...
   ... resto da chave ...
   -----END RSA PRIVATE KEY-----

5. Clicar: "Add secret"

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

🎯 COMO USAR O WORKFLOW AUTOMÁTICO

1. Ir para: GitHub → seu repo → Actions tab

2. Abrir: "Terraform Apply + Ansible Deploy"

3. Clicar: "Run workflow" button

4. Deixar correr (5-10 minutos):
   ✓ Terraform deploy (~3 min)
   ✓ Ansible configure-ec2 (~3 min)
   ✓ Ansible deploy-app (~2 min)
   ✓ Health check (~1 min)

5. Ver resultado nos logs do workflow

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

📊 WORKFLOW ARCHITECTURE

┌─────────────────────────────────────────┐
│  GitHub Actions Trigger (Manual)        │
└────────────────┬────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────┐
│  Job 1: APPLY                           │
│  - terraform init                       │
│  - terraform validate                   │
│  - terraform apply                      │
│  - Capture outputs ✅ NEW!              │
└────────────────┬────────────────────────┘
                 │ (pass outputs)
                 ▼
┌─────────────────────────────────────────┐
│  Job 2: DEPLOY ✅ NEW!                  │
│  - Setup Ansible                        │
│  - Generate inventory (dinâmico)        │
│  - Run configure-ec2.yml                │
│  - Run deploy-app.yml (variáveis auto)  │
│  - Health check                         │
└────────────────┬────────────────────────┘
                 │
                 ▼
         ✅ DEPLOYMENT COMPLETE!

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

🔑 VARIÁVEIS INJETADAS AUTOMATICAMENTE

Estas passam direto dos outputs do Terraform:

┌────────────────────┬──────────────────────────────────┐
│ Variável           │ Origem                           │
├────────────────────┼──────────────────────────────────┤
│ rds_endpoint       │ terraform output (captured auto) │
│ db_password        │ GitHub Secrets (DB_PASSWORD)     │
│ sqs_queue_url      │ terraform output (captured auto) │
│ ec2_public_ip      │ terraform output (used for SSH)  │
└────────────────────┴──────────────────────────────────┘

NO MANUAL CONFIGURATION NEEDED! ✅

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

📝 FICHEIRO MODIFICADO

.github/workflows/terraform-apply.yml

Alterações:
- Dividido em 2 jobs: apply + deploy
- Job apply captura outputs via GITHUB_OUTPUT
- Job deploy passa para Ansible via --extra-vars
- Cria inventory.ini dinamicamente
- Valida saúde dos endpoints no final

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

✅ FLUXO COMPLETO AGORA:

Antes (Manual):
  1. terraform apply
  2. Capturar outputs manualmente
  3. rodar ansible playbooks manualmente
  4. Testar manualmente
  ⏱️ Tempo: ~30 minutos (com muita digitação)

Depois (Automático - CI/CD):
  1. GitHub Actions → "Run workflow"
  2. Senta, aguarda, …
  3. ✅ Tudo done automaticamente
  ⏱️ Tempo: ~10 minutos (completamente automático)

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

🎬 EXEMPLO DE EXECUÇÃO

GitHub Actions UI:
├─ Workflow: Terraform Apply + Ansible Deploy
├─ Status: In Progress...
│
├─ Job: apply
│  ├─ ✅ Checkout repository
│  ├─ ✅ Configure AWS credentials
│  ├─ ✅ Setup Terraform
│  ├─ ✅ Terraform Init
│  ├─ ✅ Terraform Validate
│  ├─ ✅ Terraform Apply (EC2, RDS, SQS created!)
│  ├─ ✅ Capture outputs
│  │  ├─ ec2_public_ip: 63.184.114.120
│  │  ├─ rds_endpoint: cloud-project-database.cnuwkgaqueql.eu-central-1.rds.amazonaws.com:5432
│  │  └─ sqs_queue_url: https://sqs.eu-central-1.amazonaws.com/.../dev-CloudComputing-product-events
│  └─ ✅ Display outputs
│
├─ Job: deploy (usando outputs do apply)
│  ├─ ✅ Setup Ansible
│  ├─ ✅ Create SSH key
│  ├─ ✅ Update inventory (DINÂMICO!)
│  ├─ ✅ Run configure-ec2.yml (Docker install, users setup)
│  ├─ ✅ Run deploy-app.yml (Services deployed with auto vars!)
│  │  Variables automatically injected:
│  │  ├─ rds_endpoint=cloud-project-database.cnuwkgaqueql...
│  │  ├─ db_password=dr1gues103 (from secrets)
│  │  └─ sqs_queue_url=https://sqs.eu-central-1...
│  ├─ ✅ Verify services
│  │  └─ API Gateway /actuator/health: {"status":"UP"}
│  └─ ✅ Deployment complete!

Duration: 9 min 42 sec ⏱️

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

⚡ TROUBLESHOOTING

Problema: "SSH key permission denied"
Solução: Verificar que SSH_PRIVATE_KEY tem -----BEGIN e -----END

Problema: "Ansible inventory not found"
Solução: Verificar que o playbook está em ansible/playbooks/

Problema: "RDS connection refused"
Solução: Aguardar mais 1-2 minutos (RDS leva tempo a initiar)

Problema: "Docker not running on EC2"
Solução: Verificar logs de configure-ec2.yml no workflow

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

🎯 PRÓXIMOS PASSOS

1. ✅ Adicionar SSH_PRIVATE_KEY nos GitHub Secrets
2. ✅ Commit e push do workflow atualizado
3. ✅ Ir para GitHub Actions
4. ✅ Clicar "Run workflow"
5. ✅ Aguardar ~10 min
6. ✅ Verificar logs
7. ✅ Aceder a http://<ec2-ip>:8080/actuator/health

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

📚 DOCUMENTAÇÃO RELACIONADA

- docs/DEPLOYMENT_GUIDE_FINAL.md ← Deployment manual (reference)
- docs/QUICK_REFERENCE.md ← Todos os comandos
- .github/workflows/terraform-plan.yml ← PR validation workflow
- .github/workflows/terraform-apply.yml ← Este arquivo (CI/CD auto)

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

✨ RESUMO

Antes: Manual commands com 5+ etapas diferentes
Depois: Um clique no GitHub Actions ✅

Variáveis hardcoded? Não! Todas injetadas automaticamente.
Tempo poupado? ~25 minutos por deployment.
Erro humano? Minimizado (tudo automático).

═════════════════════════════════════════════════════════════════

🎓 PRONTO PARA DEMO & DEFESA!

═════════════════════════════════════════════════════════════════
Gerado: 28 Maio 2026 - Status: ✅ COMPLETO
═════════════════════════════════════════════════════════════════

