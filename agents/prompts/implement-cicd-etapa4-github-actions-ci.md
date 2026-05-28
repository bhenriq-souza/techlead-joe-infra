# Prompt — Etapa 4 do Plano CI/CD: GitHub Actions no repositorio da aplicacao

## Instrucoes para o chat

Use este prompt para um chat dedicado a criar o workflow de CI/CD no repositorio `techlead-joe-knowledge-injection-service`.
Cole o conteudo abaixo como sua primeira mensagem.
O workspace principal e `/home/bhs/code/Personal/techlead-joe-knowledge-injection-service`.
As Etapas 1, 2 e 3 devem estar concluidas antes de iniciar esta etapa.

---

## Prompt

Voce e um Engenheiro de DevOps especializado em GitHub Actions e pipelines de CI/CD para aplicacoes Python containerizadas.

Preciso que voce crie o **workflow de CI/CD** no repositorio `techlead-joe-knowledge-injection-service`. O pipeline deve executar verificacoes de qualidade (testes, lint, seguranca), depois fazer build e push da imagem Docker para o GCP Artifact Registry, e por fim atualizar a tag nos manifests GitOps.

### Contexto do projeto

O homelab possui um **workflow reutilizavel** de CI/CD em `homelab-gitops/.github/workflows/docker-build-push.yaml` (disponivel em `/home/bhs/code/Personal/homelab-gitops/.github/workflows/docker-build-push.yaml`). Esse workflow:
- Recebe como inputs: `app-name`, `environment`, `dockerfile`, `context`, `registry-url`, `gitops-repo`, `gitops-branch`.
- Autentica no GCP via Workload Identity Federation (WIF/OIDC) — sem credenciais de longa duracao.
- Faz build e push para `us-central1-docker.pkg.dev/homelab-492918/homelab-apps/{app-name}:{sha}`.
- Commita a tag atualizada nos manifests do repositorio GitOps alvo via GitHub PAT.

Para o Techlead Joe, o repositorio GitOps alvo e `bhenriq-souza/techlead-joe-gitops` (nao `homelab-gitops`).

O plano completo esta em `techlead-joe-infra/docs/cicd-gitops-plan.md`.

Leia o arquivo `docker-build-push.yaml` antes de criar o caller para verificar a assinatura exata (inputs e secrets).

### Contexto da aplicacao

- Repositorio: `bhenriq-souza/techlead-joe-knowledge-injection-service`
- Linguagem: Python 3.12, gerenciador de dependencias: `uv`
- Dockerfile: na raiz do repositorio
- Imagem: `us-central1-docker.pkg.dev/homelab-492918/homelab-apps/knowledge-injection-service`
- Branch `develop` -> deploy em `dev`
- Branch `main` -> deploy em `prd`
- Testes: `pytest` com `pytest-asyncio` e `pytest-cov` (configurados em `pyproject.toml`)
- Linting: `ruff` (adicionar nas dev deps se nao estiver presente)
- Scan de seguranca estatica: `bandit`
- Scan de vulnerabilidades de imagem: `trivy`

### Decisoes arquiteturais ja tomadas (nao discutir, apenas seguir)

1. Usar o workflow reutilizavel `docker-build-push.yaml` de `homelab-gitops` via `uses:`.
2. Autenticacao no GCP via WIF — sem `GOOGLE_APPLICATION_CREDENTIALS` ou chaves JSON.
3. O repositorio GitOps alvo para commit de tags e `bhenriq-souza/techlead-joe-gitops`.
4. A tag da imagem e o SHA abreviado do commit — nao usar `latest`.
5. O job de build/deploy so deve rodar se o quality gate passar.
6. O workflow deve executar o quality gate em PRs tambem, mas o deploy so ocorre em push para `develop` e `main`.

### Estrutura de jobs esperada

```
quality-gate
  ├── lint          (ruff check)
  ├── test          (pytest com coverage)
  └── security-scan (bandit + trivy filesystem)

build-deploy        (needs: quality-gate, apenas em push develop/main)
  └── chama docker-build-push.yaml com gitops-repo: bhenriq-souza/techlead-joe-gitops
```

### O que preciso que voce entregue

**1. Atualizar `pyproject.toml`** (se necessario)

Verificar se `ruff` e `bandit` estao nas dev dependencies. Se nao estiverem, adiciona-los:

```toml
[dependency-groups]
dev = [
    "bandit[toml]>=1.7",
    "pytest>=8.2",
    "pytest-asyncio>=0.23",
    "pytest-cov>=5.0",
    "ruff>=0.4",
]
```

Adicionar configuracao do ruff no `pyproject.toml`:

```toml
[tool.ruff]
line-length = 100
target-version = "py312"

[tool.ruff.lint]
select = ["E", "F", "I", "B", "UP"]

[tool.bandit]
targets = ["src"]
skips = []
```

**2. Workflow principal: `.github/workflows/ci.yml`**

O workflow deve:
- Disparar em `push` para `develop` e `main`, e em `pull_request` para qualquer branch.
- Job `quality-gate` que executa em paralelo ou sequencialmente:
  - **lint**: `uv run ruff check .`
  - **test**: `uv run pytest` com upload de relatorio de cobertura como artifact
  - **security-scan**:
    - `uv run bandit -r src/ -c pyproject.toml`
    - `trivy filesystem . --exit-code 1 --severity HIGH,CRITICAL --ignore-unfixed` (usando a action oficial `aquasecurity/trivy-action`)
- Job `build-deploy`:
  - Condicional: `if: github.event_name == 'push'`
  - `needs: quality-gate`
  - Detecta o ambiente a partir da branch (`develop` -> `dev`, `main` -> `prd`)
  - Chama o workflow reutilizavel `docker-build-push.yaml` com os inputs corretos

**3. Documentar os secrets necessarios no GitHub**

Listar quais secrets devem ser configurados no repositorio no GitHub (Settings > Secrets and variables > Actions):
- Nome do secret, descricao e como obter o valor (ex: "obter do output Terraform do modulo gcp-github-wif").

**4. Verificar compatibilidade com o workflow reutilizavel**

Antes de criar o caller, leia `docker-build-push.yaml` e verifique:
- Quais `inputs` sao obrigatorios e opcionais.
- Quais `secrets` sao esperados (inherited ou explicitamente declarados).
- Se o workflow reutilizavel suporta configurar o repositorio GitOps alvo como parametro.

Se o workflow reutilizavel nao suportar `gitops-repo` como parametro (hardcoded para `homelab-gitops`), proponha a alteracao minima necessaria retro-compativel antes de criar o caller. Documente a alteracao sugerida.

### Restricoes e preferencias

- Nao duplicar logica de build/push/gitops-update que ja existe no workflow reutilizavel.
- O quality gate deve rodar em PRs para dar feedback rapido sem fazer deploy.
- Manter o workflow caller simples no job de build — ele e apenas um dispatcher para o workflow reutilizavel.
- Se houver necessidade de alterar `docker-build-push.yaml`, a mudanca deve ser retro-compativel (sem quebrar callers existentes no homelab-gitops).
- Usar `uv` para todos os comandos Python no CI (nao pip diretamente).
- Cache de dependencias do uv para acelerar execucoes subsequentes.

### Ao concluir

Informe:
- Os arquivos criados ou modificados com seus conteudos.
- A lista de secrets a configurar no GitHub com instrucoes de onde obter cada valor.
- Se foi necessario propor alteracao no workflow reutilizavel, descrever a mudanca e seu impacto.
- Como validar que o pipeline funcionou apos o primeiro push (o que verificar no GitHub Actions, no Artifact Registry, nos manifests do `techlead-joe-gitops` e no ArgoCD).
