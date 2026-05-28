# Prompt — Etapa 1 do Plano CI/CD: Terraform WIF e Secrets no GCP

## Instrucoes para o chat

Use este prompt para um chat dedicado a implementar a Etapa 1 do plano de CI/CD do projeto Techlead Joe.
Cole o conteudo abaixo como sua primeira mensagem.
O workspace principal e `/home/bhs/code/Personal/homelab-infra`.

---

## Prompt

Voce e um Engenheiro de Infraestrutura especializado em Terraform, GCP e seguranca de CI/CD.

Preciso que voce implemente a **Etapa 1 do plano de CI/CD do projeto Techlead Joe** no repositorio `homelab-infra`. O objetivo e preparar o GCP para que os repositorios do Techlead Joe possam fazer push de imagens Docker via GitHub Actions e para que o cluster ai-lab possa consumir secrets dos servicos.

### Contexto do projeto

O homelab possui uma infraestrutura de CI/CD ja estabelecida:
- **GCP Artifact Registry**: repositorio `homelab-apps` em `us-central1-docker.pkg.dev/homelab-492918/homelab-apps/`.
- **Modulo Terraform `gcp-github-wif`** em `terraform/modules/gcp-github-wif/`: cria Workload Identity Pool para autenticacao OIDC de repos do GitHub no GCP, sem credenciais de longa duracao. A service account resultante tem papel `roles/artifactregistry.writer`.
- **Modulo Terraform `artifact-registry`** em `terraform/modules/artifact-registry/`: gerencia o registry Docker.
- **GCP Secret Manager**: ja usado pelo homelab via External Secrets Operator (ESO) para injetar secrets nos pods k3s.
- O projeto GCP e `homelab-492918`, regiao `us-central1`.
- O contexto da gcp gcloud CLI já está no projeto `homelab-492918`.
- O contexto do kubectl já está utilizando o cluster k3s do homelab server.

O plano completo esta documentado em `techlead-joe-infra/docs/cicd-gitops-plan.md`.

### Decisoes arquiteturais ja tomadas (nao discutir, apenas seguir)

1. Usar o registry existente `homelab-apps` — nao criar registry separado para Techlead Joe.
2. Autenticacao via WIF/OIDC — sem service account keys ou secrets de longa duracao nos repos do GitHub.
3. Secrets de aplicacao gerenciados no GCP Secret Manager, consumidos via ESO no cluster.
4. Nomeacao dos secrets no Secret Manager com prefixo `tj-` para isolar do restante do homelab.

### O que preciso que voce entregue

**1. Adicionar repos do Techlead Joe ao WIF**

Nos arquivos Terraform relevantes (verifique onde o modulo `gcp-github-wif` e instanciado para o homelab — provavelmente em `terraform/clusters/homelab/bootstrap/`):
- Adicionar o repositorio `bhenriq-souza/techlead-joe-knowledge-injection-service` ao allowlist do WIF, com condicao de branch `develop` para push de dev e `main` para push de prd.
- Adicionar o repositorio `bhenriq-souza/techlead-joe-gitops` ao allowlist do WIF, para que o workflow de CI possa commitar tags de imagem atualizadas nos manifests GitOps.

**2. Cadastrar secrets no GCP Secret Manager**

Identificar onde os secrets existentes do homelab sao provisionados no Terraform (ex: `google_secret_manager_secret` resources). Criar recursos equivalentes para o Techlead Joe com os seguintes secrets:
- `tj-postgres-host`
- `tj-postgres-db`
- `tj-postgres-user`
- `tj-postgres-password`
- `tj-ollama-base-url`

Cada secret deve ter:
- Replicacao automatica (policy `automatic`)
- Labels: `project = "techlead-joe"`, `env = "dev"` ou `"prd"` conforme aplicavel

**3. Permissoes de leitura dos secrets para o ESO**

Verificar se a service account do ESO ja tem permissao `roles/secretmanager.secretAccessor` no escopo do projeto (provavelmente ja tem). Se a permissao for por secret individual, adicionar os novos secrets.

**4. Validar o plano Terraform**

Apos as mudancas, executar `terraform plan` nos modulos afetados e confirmar que nao ha destruicao de recursos existentes.

### Restricoes e preferencias

- Nao alterar recursos existentes — apenas adicionar novos.
- Seguir o padrao de nomenclatura ja usado no repositorio (snake_case, prefixo por projeto).
- Nao criar outputs ou variaveis desnecessarios — aproveitar os ja existentes nos modulos.
- Se encontrar uma forma melhor de organizar os secrets (ex: modulo dedicado), proponha antes de implementar.

### Ao concluir

Informe:
- Quais arquivos foram modificados e por que.
- Quais recursos Terraform serao criados.
- O output do `terraform plan` (sem valores sensiveis).
- Se houver dependencias que bloqueiam algum item, liste-as explicitamente.
