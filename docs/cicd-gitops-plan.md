# Plano de CI/CD e GitOps para Servicos Techlead Joe

## 1. Contexto

O homelab ja possui infraestrutura de CI/CD bem definida para deploy de aplicacoes no cluster k3s via GitOps com ArgoCD. O que falta e conectar os servicos do projeto Techlead Joe (ex: `knowledge-injection-service`) a essa infraestrutura, definindo o fluxo de build, publicacao de imagem Docker e deploy automatizado.

## 2. O que ja existe no homelab

- **GCP Artifact Registry** — repositorio `homelab-apps` em `us-central1-docker.pkg.dev/homelab-492918/homelab-apps/` gerenciado pelo modulo Terraform `artifact-registry`.
- **Workflow reutilizavel de CI** — `homelab-gitops/.github/workflows/docker-build-push.yaml`:
  - Autentica no GCP via WIF/OIDC (sem credenciais de longa duracao).
  - Faz build e push da imagem Docker para o Artifact Registry.
  - Atualiza a tag da imagem nos manifests do GitOps via commit automatico.
- **Modulo Terraform `gcp-github-wif`** — vincula repos do GitHub ao GCP via OIDC, concedendo permissao de push para o Artifact Registry.
- **ArgoCD** — bootstrapped via Terraform no cluster homelab, reconciliando o repositorio `homelab-gitops`.
- **External Secrets Operator** — integrado ao GCP Secret Manager com autenticacao via WIF.
- **Scaffold `clusters/ai-lab/`** — ja existe em `homelab-gitops`, ainda sem workloads do Techlead Joe.

## 3. O que falta para os servicos Techlead Joe

| Gap | Repositorio responsavel |
|-----|------------------------|
| Repo `techlead-joe-knowledge-injection-service` nao esta no allowlist do WIF | `homelab-infra` (Terraform) |
| Secrets de aplicacao nao cadastrados no GCP Secret Manager | GCP + `homelab-infra` |
| Sem repo GitOps dedicado ao projeto | `techlead-joe-gitops` (novo repo) |
| Sem manifests Kubernetes para os servicos | `techlead-joe-gitops` |
| Sem ArgoCD AppProject e Application para o Techlead Joe | `homelab-gitops` |
| Sem workflow de CI nos repos de aplicacao | cada repo de aplicacao |

## 4. Decisao: repositorio GitOps separado para Techlead Joe

**Decisao**: criar um repositorio `techlead-joe-gitops` dedicado aos workloads do projeto Techlead Joe.

**Motivacao**:
- `homelab-gitops` e a fonte de verdade da infraestrutura do homelab (plataforma, observabilidade, apps genericos).
- Techlead Joe e um produto com ciclo de vida proprio e multiplos servicos.
- Separacao garante autonomia de deploy sem impactar a infraestrutura base.
- O CI de cada servico commita tags apenas no `techlead-joe-gitops`, nao no `homelab-gitops`.
- Cada repo gitops tem permissoes independentes no ArgoCD.

**Trade-off**: um repo a mais para manter. Dado que o padrao esta bem estabelecido no homelab, o overhead e baixo.

## 5. Plano de implementacao

### Etapa 1 — Terraform (homelab-infra)

Responsavel: modulos `gcp-github-wif` e `artifact-registry` em `homelab-infra/terraform/`.

Acoes:
- Adicionar `bhenriq-souza/techlead-joe-knowledge-injection-service` ao allowlist do WIF para receber permissao de push no Artifact Registry.
- Adicionar `bhenriq-souza/techlead-joe-gitops` ao allowlist do WIF para que o CI possa commitar tags atualizadas nos manifests.
- Manter o registry existente `homelab-apps` — separacao logica ja ocorre pela tag do app-name.
- Cadastrar no GCP Secret Manager os secrets necessarios para os servicos:
  - `tj-postgres-host`, `tj-postgres-db`, `tj-postgres-user`, `tj-postgres-password`
  - `tj-ollama-base-url`
  - (image pull secret ja existe no padrao homelab via ExternalSecret)

### Etapa 2 — Novo repositorio `techlead-joe-gitops`

Estrutura recomendada (espelha o padrao de `homelab-gitops`):

```
techlead-joe-gitops/
├── clusters/
│   └── ai-lab/
│       └── workloads/
│           ├── dev/
│           │   ├── kustomization.yaml
│           │   └── manifests/
│           │       └── knowledge-injection-service/
│           │           ├── deployment.yaml
│           │           ├── externalsecret.yaml
│           │           └── kustomization.yaml
│           └── prd/
│               └── (mesmo padrao)
└── components/
```

Acoes:
- Criar repositorio `bhenriq-souza/techlead-joe-gitops` no GitHub.
- Implementar manifests Kubernetes para `knowledge-injection-service`.
- Criar `ExternalSecret` apontando para os secrets cadastrados na Etapa 1.
- Adicionar `imagePullSecret` seguindo o padrao `externalsecret-image-pull` do homelab.

### Etapa 3 — homelab-gitops (ArgoCD AppProject + Application)

Acoes:
- Criar `AppProject` `techlead-joe` no ArgoCD:
  - source: repositorio `techlead-joe-gitops`
  - destination: namespace `techlead-joe` no cluster ai-lab
  - permissoes restritas ao namespace do projeto
- Criar `Application` do ArgoCD apontando para os workloads de dev e prd.
- Registrar `techlead-joe-gitops` como fonte confiavel no bootstrap do cluster ai-lab em `homelab-gitops`.

### Etapa 4 — Workflow de CI no repositorio da aplicacao

Arquivo: `techlead-joe-knowledge-injection-service/.github/workflows/ci.yml`

Acoes:
- Criar workflow que chama o workflow reutilizavel `docker-build-push.yaml` de `homelab-gitops`.
- Configurar o target de commit de tags para `techlead-joe-gitops` (nao `homelab-gitops`).
- Gatilhos: push em `develop` (deploy dev) e `main` (deploy prd).

## 6. Dependencias e ordem de execucao

```
Etapa 1 — Terraform WIF + Secrets (homelab-infra)
  └── habilita Etapa 2 — techlead-joe-gitops (manifests + ExternalSecrets)
                └── habilita Etapa 3 — homelab-gitops (AppProject + Application)
                              └── habilita Etapa 4 — CI workflow na aplicacao
```

## 7. Itens fora do escopo deste plano

- Bootstrap do cluster ai-lab com k3s (cobre item 1.9 em itens-em-aberto-e-backlog.md)
- GPU enablement para Ollama no k3s (item 1.8)
- Migracao do Docker Compose para k3s (Fase 2)
- Criacao de registries Artifact Registry adicionais por projeto

## 8. Referencias

- [homelab-gitops] `.github/workflows/docker-build-push.yaml` — workflow reutilizavel de CI
- [homelab-infra] `terraform/modules/gcp-github-wif/` — modulo de WIF para GitHub Actions
- [homelab-infra] `terraform/modules/artifact-registry/` — modulo do registry Docker
- [homelab-gitops] `clusters/homelab/workloads/dev/manifests/myapp/` — exemplo de workload com ExternalSecret
- [techlead-joe-infra] `docs/deployment-topology-mvp.md` — topologia de clusters definida
