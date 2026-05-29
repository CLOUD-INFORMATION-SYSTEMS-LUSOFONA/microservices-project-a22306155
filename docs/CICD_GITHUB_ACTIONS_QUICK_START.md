# 🚀 CI/CD GitHub Actions - Guia de Configuração

## Visão Geral

Este projeto implementa um pipeline CI/CD production-ready com:
- ✅ **terraform-plan.yml**: Validação em Pull Requests (sem apply)
- ✅ **terraform-apply.yml**: Apply automático em main + Ansible deploy
- ✅ **ansible-config.yml** (opcional): Configuração EC2 separada
- ✅ **ansible-deploy.yml** (opcional): Deploy aplicação separado

## Fluxo de Execução

```
1. Developer cria PR com changes em infra/terraform/
   └─ terraform-plan.yml é acionado
   └─ Valida: fmt, init, validate, plan
   └─ Comment no PR com resultado
   └─ Bloqueia merge se falhar

2. Pull Request é aprovado e mergido para main
   └─ terraform-apply.yml é acionado
   └─ terraform apply -auto-approve
   └─ Captura outputs (EC2, RDS, SQS)
   └─ Executa configure-ec2.yml
   └─ Executa deploy-app.yml
   └─ Verifica health endpoints
   └─ ✅ Ambiente em produção!
```

## 🔐 Configuração de Secrets

Adicionar em: **Settings → Secrets and variables → Actions**

| Secret | Valor | Descrição |
|--------|-------|-----------|
| AWS_ROLE_TO_ASSUME | arn:aws:iam::839006976195:role/github-actions-role | OIDC role for AWS access |
| TF_KEY_NAME | miguelrodr1 | EC2 key pair name |
| DB_PASSWORD | dr1gues103 | RDS master password |
| SSH_PRIVATE_KEY | (conteúdo de ~/.ssh/miguelrodr1_lf.pem) | SSH private key para Ansible |

⚠️ SSH_PRIVATE_KEY deve incluir -----BEGIN e -----END

## 📋 Workflows Detalhados

### 1. terraform-plan.yml (Pull Requests)

**Trigger**: Changes em `infra/terraform/` ou `.github/workflows/terraform-plan.yml`

**Steps**:
- Setup Terraform 1.9.0
- Cache providers
- terraform fmt -check → Falha se não formatado
- terraform init (sem backend)
- terraform validate → Falha se inválido
- terraform plan → Mostra mudanças
- Comment no PR → Resultado completo
- Upload artifact → tfplan por 1 dia

**Duração**: 2-3 minutos

**Resultado**: PR comentado com plan, merge bloqueado se falhar

### 2. terraform-apply.yml (Main Branch)

**Trigger**: Push para `main` com changes em `infra/terraform/`

**Job 1 - Apply**:
- Verifica se é main branch
- Configure AWS OIDC credentials
- terraform init (com remote backend)
- terraform validate, fmt check, plan
- terraform apply -auto-approve
- Captura outputs: EC2, RDS, SQS
- Passa outputs para próximo job

**Job 2 - Deploy** (executa só se apply suceder):
- Aguarda EC2 estar acessível (até 5 min)
- Executa ansible/playbooks/configure-ec2.yml
- Executa ansible/playbooks/deploy-app.yml
  - Injeta variáveis: RDS endpoint, DB password, SQS URL
  - Copia docker-compose.yml
  - Inicia containers
- Verifica health endpoints

**Job 3 - Notify** (se falhar):
- Notifica falha no GitHub

**Duração**: 10-12 minutos total

**Environment Protection**: Production (requer aprovação se configurado)

### 3. ansible-config.yml (Opcional)

**Trigger**: workflow_run (acionado após terraform-apply suceder)

- Setup Ansible
- Cria SSH key
- Aguarda EC2 ficar acessível
- Executa configure-ec2.yml
- Publica summary

**Duração**: 4-5 minutos

### 4. ansible-deploy.yml (Opcional)

**Trigger**: workflow_run (acionado após ansible-config suceder)

- Setup Ansible
- Recupera outputs do Terraform
- Executa deploy-app.yml
- Verifica health endpoints
- Publica informações de acesso

**Duração**: 4-5 minutos

## 📚 Arquivos Relacionados

- `.github/workflows/terraform-plan.yml` - PR validation
- `.github/workflows/terraform-apply.yml` - Infrastructure + Deploy
- `.github/workflows/ansible-config.yml` - EC2 config (optional)
- `.github/workflows/ansible-deploy.yml` - App deploy (optional)
- `infra/terraform/backend.tf` - Remote state S3 + DynamoDB locking
- `ansible/playbooks/configure-ec2.yml` - EC2 setup
- `ansible/playbooks/deploy-app.yml` - Application deployment
- `docs/TERRAFORM_CICD_PIPELINE.md` - Documentação PT

## 🐛 Troubleshooting

**SSH connection denied**:
- Verificar SSH_PRIVATE_KEY secret (incluir BEGIN/END)
- Verificar EC2 security group permite port 22
- Aguardar EC2 estar fully initialized (2-5 min)

**Terraform init failed**:
- Verificar S3 bucket exists para backend
- Verificar DynamoDB table exists
- Verificar AWS role permissions

**Health checks failed**:
- Serviços ainda estão starting (aguarde)
- Verificar docker compose logs: `docker compose logs -f`
- Verificar variáveis de ambiente

**Apply falha**:
- Verificar logs no GitHub Actions
- Verificar Terraform variables (db_password, key_name)
- Rollback: `git revert <commit>` + push para main

## ✨ Boas Práticas

1. **Always use branches**: Nunca commit direto no main
2. **Review Terraform plan**: No PR antes de merge
3. **Never manual apply**: Sempre via GitHub Actions (rastreável)
4. **Environment approval**: Configurar no GitHub se quiser 2FA
5. **Lock terraform state**: Usado S3 + DynamoDB (já configurado)
6. **SSH key security**: Nunca commit chaves privadas
7. **Secrets management**: Usar GitHub Secrets, nunca hardcode

## 📊 Monitoramento

- **GitHub Actions**: Ver logs em tempo real
- **AWS Console**: Verificar EC2, RDS, SQS criados
- **EC2 SSH**: ssh -i ~/.ssh/key ec2-user@<IP>
- **Docker logs**: docker compose logs -f

## 🎯 Checklist Pré-Produção

- [ ] terraform-plan.yml passou em PR
- [ ] Terraform plan review feito e aprovado
- [ ] AWS IAM role tem permissions corretas
- [ ] SSH key válida em GitHub Secrets
- [ ] EC2 key pair existe em AWS
- [ ] S3 backend bucket existe
- [ ] Database password atualizado
- [ ] Não há changes não intencionais

## 📞 Próximos Passos

1. Verificar todos os **secrets estão adicionados** no GitHub
2. Criar uma **feature branch** para testar
3. Fazer **commit mock** em `infra/terraform/`
4. Criar **Pull Request** e ver terraform-plan.yml rodar
5. Verificar **comment no PR** com plan output
6. Fazer **merge** para main e ver deploy automático
7. Verificar **health endpoints** após deployment
8. 🎉 **Pronto para produção!**

---

**Status**: ✅ CI/CD Production-Ready
**Data**: 28 Maio 2026

