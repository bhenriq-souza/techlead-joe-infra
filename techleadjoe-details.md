# Report Técnico: Ecossistema Tech Lead Joe

**Data:** 2026-05-28 | **Repositórios analisados:** `techlead-joe-infra`, `techlead-joe-knowledge-injection-service`

---

## 1. Visão Geral do Ecossistema

O Tech Lead Joe é uma plataforma de **análise de incidentes assistida por LLM local**, com arquitetura distribuída em dois clusters Kubernetes. O sistema usa RAG (Retrieval-Augmented Generation) para fornecer contexto ao modelo sem fine-tuning, e integra com Jira e Slack para automação de tickets.

O ecossistema hoje tem **dois repositórios ativos** e um terceiro planejado:

| Repositório | Papel | Status |
|---|---|---|
| `techlead-joe-infra` | Documentação, ADRs, prompts de agente, experimentos de infra | Ativo — documentação madura |
| `techlead-joe-knowledge-injection-service` | Serviço Python de ingestão de conhecimento (RAG) | Ativo — Fases 1–2 completas, Fase 3 em andamento |
| `techlead-joe-gitops` | Manifests K8s + ArgoCD | **Não criado** — bloqueado por CI/CD Etapa 1 |

O ecossistema depende de infraestrutura de suporte em dois repositórios separados já ativos:

| Repositório | Papel | Estado relevante para o projeto |
|---|---|---|
| `homelab-infra` | IaC Terraform, ADRs, rede, host Ubuntu + K3s | WIF pool/provider, Artifact Registry `homelab-apps` e ESO já provisionados; bootstrap ArgoCD gerenciado por Terraform |
| `homelab-gitops` | Estado desejado dos clusters reconciliado pelo ArgoCD | Cluster `homelab` operacional; workflow reutilizável `docker-build-push.yaml` já implementado; scaffold `clusters/ai-lab` pronto aguardando K3s |

---

## 2. Tech Stack

### `techlead-joe-infra` (infra & docs)

| Camada | Tecnologia |
|---|---|
| Documentação | Markdown estruturado |
| Experimentos | Docker Compose |
| LLM runtime | Ollama (qwen2.5:7b, qwen2.5-coder:14b) |
| Embeddings | Text Embeddings Inference — BAAI/bge-m3 (1024d) |
| GPU | RTX 5070 12GB (sm_120 — Blackwell) via NVIDIA Container Toolkit |
| Observabilidade | Grafana Alloy → Loki → Grafana |
| Deployment futuro | k3s + ArgoCD (Fase 2, não iniciado) |

### `techlead-joe-knowledge-injection-service` (serviço Python)

| Camada | Tecnologia |
|---|---|
| Linguagem | Python 3.12+ |
| Gerenciador de pacotes | `uv` |
| Framework de domínio | Dataclasses puras (sem ORM no domínio) |
| ORM | SQLAlchemy 2.0 (sync) |
| Banco de dados | PostgreSQL 16 + pgvector (schema `knowledge`) |
| Embeddings | Ollama `/api/embed` via httpx |
| Migrações | Alembic |
| CLI | Click |
| DI | `dependency-injector` |
| Logging | structlog |
| Config | Pydantic Settings v2 |
| Containerização | Docker (Python 3.12-slim, multi-stage com uv) |
| Testes | pytest + pytest-asyncio + pytest-cov |
| Runtime-target | Kubernetes CronJob |

**Observação sobre inconsistência:** O `pyproject.toml` lista `asyncpg`, `sqlalchemy[asyncio]`, e `pytest-asyncio` mas o código está implementado de forma **síncrona**. A documentação interna afirma explicitamente "Synchronous (SQLAlchemy sync + httpx sync)". Isso é dívida técnica controlada e intencional, mas as dependências async são ruído.

---

## 3. Arquitetura

### 3.1 Arquitetura do serviço de ingestão

O serviço segue **Arquitetura Hexagonal** com separação clara de responsabilidades:

```
CLI (Click)
  └─ IngestionService (application)
       ├─ ChunkingService (application)
       ├─ EmbeddingsClientPort → OllamaEmbeddingsClient (infra)
       ├─ RepositoryClientPort → GitRepositoryClient (infra, superseded)
       └─ Repositories (ports) → SQLAlchemy adapters (infra)
            └─ PostgreSQL/pgvector
```

O DI Container (`dependency-injector`) faz a composição, e a injeção chega até os comandos Click via `wiring_config`.

**Ponto forte:** O domínio (`domain/models.py`, `domain/ports.py`) é completamente livre de frameworks — dataclasses e ABCs puras. Isso é correto.

### 3.2 Decisão arquitetural crítica: Event-Driven

Em 2026-05-15 houve uma **mudança de paradigma importante**: a ingestão passou de "clonar/pull local" para um fluxo event-driven:

```
GitHub PR Merge
  → GitHub Actions publica evento normalizado no Pub/Sub
  → Knowledge Ingestion Worker consome evento
  → Worker consulta catálogo (source of truth)
  → Worker calcula delta (arquivos alterados no merge)
  → Worker baixa apenas docs permitidos via GitHub API
  → Worker atualiza embeddings, chunks, documentos no PostgreSQL
```

Esta é uma decisão sólida — alinha com o princípio DA-003 ("Knowledge via RAG from GitHub, OpenSpec, ADRs, runbooks") e evita materializar repositórios inteiros. A documentação em `docs/architecture/knowledge-ingestion-event-driven.md` é bem articulada.

**Porém:** os prompts de agente em `agents/prompts/` do repo de infra ainda referem ao `GitRepositoryClient` como path principal até o `passo-03`. O `passo-03-git-repository-client.md` está marcado como superseded mas continua presente. Isso pode confundir um agente que ler os prompts sequencialmente.

### 3.3 Topologia de deployment

```
Cluster A (AI Lab workstation — Docker Compose hoje, k3s futuro)
  ├─ Ollama Server (RTX 5070) ← LLM_BASE_URL
  ├─ Text Embeddings Inference (CPU, workaround Blackwell)
  └─ Grafana Alloy

Cluster B (homelab server — k3s) ← gerenciado por homelab-gitops via ArgoCD
  ├─ Incident Analyzer
  ├─ Knowledge Injection Worker
  ├─ Retrieval / Knowledge Access
  ├─ Admin Platform (Node.js + React + Next.js)
  ├─ RabbitMQ (topology TBD — AA-001)
  ├─ Policy Engine
  └─ PostgreSQL (DA-012) ← StatefulSet pgvector/pgvector:pg16 já definido em homelab-gitops/dev-apps
```

---

## 4. Práticas Aplicadas

### O que está bem feito

- **ADRs (Architecture Decision Records)** estão bem estruturadas com decisões fechadas (DA-001 a DA-013) e abertas (AA-001 a AA-008). A separação entre "fechado" e "aberto" é fundamental.
- **Princípios guias explícitos** no discovery report: LLM não é detector, fine-tuning adiado, open source, etc. Esses princípios aparecem nas decisões de código (e.g., event-driven não indexa indiscriminadamente).
- **Separação hexagonal** no serviço Python está correta — domínio sem framework, ports como ABCs, adapters na infra.
- **Idempotência** é um princípio explícito do MVP: rodar duas vezes sem mudanças = zero chunks_created. Isso é crítico para CronJob.
- **Experimentos validados e documentados** — o experimento do AI Lab tem critérios de aceitação explícitos e status VALIDATED, com data.
- **`project_status.md` atualizado** — provavelmente o arquivo mais útil para continuidade, está com data de hoje.
- **Migrações Alembic** com histórico versionado (0001 → 0002) e a segunda migração documenta o motivo (mudança de 384d para 768d por troca de modelo).
- **Stubs com NotImplementedError** nos clientes ainda não implementados — melhor que passar silenciosamente.
- **TEI no CPU como workaround documentado** para Blackwell sm_120 — decisão pragmática com raciocínio registrado.

### O que está inconsistente ou pode melhorar

- **`asyncpg` e `sqlalchemy[asyncio]`** no `pyproject.toml` com código síncrono — ruído que pode confundir.
- **Dimensão do embedding inconsistente entre repos:** o `knowledge-injection-service` usa 768d (nomic-embed-text) mas o AI Lab validado usa `BAAI/bge-m3` (1024d). Não há reconciliação documentada.
- **`SKILL.md` vazio** em ambos os repos — indica intenção não concluída.
- **Segurança em aberto:** AA-004 (inter-cluster auth), AA-006 (SSH/token auth para git clone), e DA-013 (LLM_BASE_URL via ConfigMap sem authn) são itens P0 sem resolução documentada.

---

## 5. Estado da Documentação

### `techlead-joe-infra/docs/` — Boa qualidade, mas com pontos de atenção

| Arquivo | Status | Observação |
|---|---|---|
| `discovery-report.md` | Válido | Fundação sólida, ainda relevante |
| `decisoes-arquiteturais.md` | Válido | ADRs bem estruturadas |
| `componentes-e-responsabilidades.md` | Parcialmente desatualizado | Não reflete a decisão event-driven — Incident Analyzer e Knowledge Ingestion precisam de atualização |
| `modelo-conceitual-e-fluxos.md` | Parcialmente desatualizado | O Fluxo 3 (inter-cluster) ainda assume GitRepositoryClient; o fluxo event-driven (Pub/Sub) não está aqui |
| `deployment-topology-mvp.md` | Válido | Reflete o estado atual (Docker Compose na Fase 1) |
| `cicd-gitops-plan.md` | Válido, parcialmente desatualizado | Plano ainda não executado, mas a infraestrutura de suporte avançou: WIF + Artifact Registry + ESO já existem em `homelab-infra/homelab-gitops`; workflow reutilizável `docker-build-push.yaml` já implementado; o plano deve ser revisto para refletir o menor esforço restante nas Etapas 1 e 4 |
| `openspec-roadmap.md` | Válido como roadmap | As 14 specs não estão em execução linear — o repo divergiu para event-driven antes de completar o roadmap original |
| `itens-em-aberto-e-backlog.md` | Parcialmente desatualizado | Não inclui os novos open items levantados após a decisão event-driven |

### `techlead-joe-knowledge-injection-service/docs/` — Boa qualidade

| Arquivo | Status | Observação |
|---|---|---|
| `implementation-plan.md` | Válido, bem detalhado | Reflete corretamente o estado com marcação clara de completo/stub/superseded |
| `architecture/knowledge-ingestion-event-driven.md` | Válido | Decisão bem documentada, mas não está linkada do `techlead-joe-infra` |
| `project_status.md` | Excelente | O melhor arquivo para continuidade — atualizado hoje, granular, com estimativas |
| `README.md` | Válido mas defasado | Ainda descreve o flow de clone/pull local como o path principal |

---

## 6. Qualidade dos Arquivos para Programação Agêntica

Esta é a análise mais crítica do report.

### `agents/prompts/` (em ambos os repos — são espelhados)

Os prompts existem em `techlead-joe-infra/agents/prompts/` e são referenciados também em `knowledge-injection-service/agents/prompts/`. Os dois repos têm os mesmos arquivos — isso é redundância desnecessária e pode causar drift.

**Pontos positivos:**
- Os prompts são sequenciais e numerados (`passo-01` a `passo-07`), o que facilita a execução linear.
- Cada prompt aparenta ter escopo limitado e bem definido (database engine, repositories, git client, etc.).
- A presença de estimativas de tempo no `implementation-plan.md` é excelente para um agente entender granularidade.

**Problemas sérios:**

1. **`passo-03-git-repository-client.md` está "superseded" mas não foi removido nem claramente marcado no próprio arquivo.** Um agente que ler a pasta em ordem vai consumir um prompt obsoleto antes de encontrar o substituto. O arquivo deveria ter um header `> SUPERSEDED — use passo-03-event-driven-document-source-ingestion.md` logo na primeira linha.

2. **`SKILL.md` está vazio nos dois repos.** Esse é o arquivo que o Claude Code usa para entender como interagir com o projeto em habilidades especializadas. Vazio = oportunidade desperdiçada. Deveria conter pelo menos: como rodar o serviço localmente, como executar testes, qual é o comando padrão de verificação, e qual é o contexto atual do projeto.

3. **Os prompts não referenciam o estado atual do código.** Um agente que chega no `passo-04` sem ler o `project_status.md` vai tentar implementar algo que pode já estar parcialmente feito ou que tem dependências não-óbvias. Os prompts deveriam começar com um bloco de "Estado esperado no início deste passo" (o que deve estar completo, o que deve ser stub).

4. **Não há um prompt de "orientação geral" ou `AGENT.md`/`CLAUDE.md` raiz** que descreva como os agentes devem operar no projeto — qual ferramenta usar para testar, qual o flow de trabalho esperado, quais arquivos nunca tocar, etc.

5. **`.claude/settings.local.json`** em ambos os repos só tem permissões básicas de `git status`. Para um projeto que roda `uv run`, `docker compose`, e potencialmente `alembic`, isso gera muitos prompts de permissão desnecessários.

### Recomendações concretas

**Alta prioridade:**

- Criar um `CLAUDE.md` raiz no `knowledge-injection-service` com:
  - Como rodar o projeto (`uv sync`, `uv run python -m knowledge_injector`)
  - Como rodar testes (`uv run pytest tests/unit/`)
  - Estado atual resumido com ponteiro para `project_status.md`
  - Quais arquivos são stubs (chunking_service, ollama_embeddings_client, ingestion_service, git_repository_client)
  - Qual é o próximo passo planejado

- Marcar explicitamente o `passo-03-git-repository-client.md` como obsoleto dentro do próprio arquivo, com redirect para o substituto.

- Expandir `.claude/settings.local.json` para incluir permissões de `uv run *`, `docker compose *`, `alembic *` — isso reduz fricção em sessões longas.

**Média prioridade:**

- Preencher o `SKILL.md` ou transformá-lo em um `CLAUDE.md` consolidado.
- Remover a duplicação de `agents/prompts/` entre os dois repos — um dos repos deve ser a fonte da verdade.
- Adicionar ao início de cada prompt um bloco "Precondições" e "Pós-condições esperadas" — isso ajuda o agente a verificar o contexto antes de executar.
- Reconciliar a dimensão de embeddings (768d vs 1024d) em documentação explícita.

**Baixa prioridade:**

- Remover `asyncpg` e `sqlalchemy[asyncio]` do `pyproject.toml` enquanto o código for síncrono.
- Atualizar `componentes-e-responsabilidades.md` e `modelo-conceitual-e-fluxos.md` no infra repo para refletir a arquitetura event-driven.
- Atualizar o `README.md` do knowledge-injection-service para não descrever o clone/pull local como path principal.

---

## 7. Resumo Executivo

| Dimensão | Nota | Comentário |
|---|---|---|
| Clareza arquitetural | ★★★★☆ | ADRs sólidas, mas alguns docs não acompanharam a virada event-driven |
| Tech stack | ★★★★☆ | Escolhas coerentes, inconsistência async/sync controlada |
| Práticas de engenharia | ★★★★☆ | Hexagonal, idempotência, stubs explícitos — bem aplicado |
| Documentação geral | ★★★★☆ | `project_status.md` é excelente; alguns docs infra estão defasados |
| Qualidade agêntica | ★★★☆☆ | Prompts sequenciais são bons, mas faltam CLAUDE.md, precondições, e gestão de obsolescência |

O projeto tem uma base arquitetural sólida e documentação acima da média para um projeto pessoal. O maior risco para programação agêntica é **o agente não ter uma âncora clara do estado atual** — o `project_status.md` resolve isso, mas não está linkado de lugar nenhum de forma estrutural. Um `CLAUDE.md` raiz que aponte para ele resolveria isso em 15 minutos.
