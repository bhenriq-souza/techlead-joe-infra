# Deployment Topology MVP

## 1. Objetivo

Documentar a topologia de deployment do MVP apos a decisao de operar com dois clusters k3s, preservando alinhamento com o padrao operacional ja praticado no homelab server.

## 2. Escopo desta versao

### 2.1 Decisoes fechadas nesta etapa

- MVP operara com 2 clusters k3s:
  - cluster A: dedicado ao Ollama Server no AI Lab
  - cluster B: dedicado as demais aplicacoes no homelab server
- PostgreSQL permanece no cluster B neste estagio
- ambos clusters seguem padrao-base de operacao com GitOps via ArgoCD
- ambos clusters devem ter baseline de observabilidade alinhada ao ecossistema Grafana ja usado no cluster B

### 2.2 Itens ainda em aberto

- contrato detalhado de comunicacao inter-cluster
- padrao de autenticacao/seguranca para chamada remota de inferencia
- baseline detalhada de GPU para cluster A
- padrao de observabilidade cross-cluster e consolidacao de sinais

## 3. Topologia fisica e logica (MVP)

### 3.1 Cluster A - AI Lab (Docker Compose — Fase 1)

- papel primario: inferencia LLM local
- workloads em execucao (Docker Compose, DA-014 Fase 1):
  - `ai-lab-ollama`: servidor LLM (GPU RTX 5070), API OpenAI-compatible
  - `ai-lab-alloy`: coleta de logs via Docker socket e encaminha ao Loki do homelab (DA-022)
- operacao: Docker Compose versionado no repositorio; ArgoCD reservado para Fase 2 (k3s)
- observabilidade: logs do Ollama chegando ao Loki/Grafana do homelab via Alloy (DA-022); metricas de GPU e host ainda pendentes
- requisito de infraestrutura: NVIDIA Container Toolkit configurado no host
- baseline de host: Ubuntu 26.04 LTS unico SO; modelos, volumes Docker e caches em `/data` (SSD dedicado), conforme DA-018 e DA-019.

### 3.2 Cluster B - Homelab Server (k3s plataforma)

- papel primario: orquestracao da plataforma de incident analysis
- workloads esperados:
  - Observability & Alert Source
  - Incident Analyzer
  - Knowledge Ingestion
  - Retrieval / Knowledge Access
  - Operational Catalog / Admin Platform
  - Messaging Broker
  - Integration Layer (Jira/Slack)
  - Persistence Layer (PostgreSQL)
  - Policy Engine

### 3.3 Dependencias entre clusters

- Incident Analyzer no cluster B chama endpoint de inferencia no cluster A
- resposta de inferencia retorna ao cluster B para policy, integracao e persistencia
- dependencias de dados estruturados e auditoria permanecem no PostgreSQL do cluster B

## 4. Fluxo de comunicacao inter-cluster

1. evento de incidente e detectado pela observabilidade no cluster B
2. Analyzer prepara pacote de incidente com contexto e guardrails
3. pacote e enviado ao endpoint de inferencia no cluster A
4. cluster A retorna analise estruturada
5. cluster B aplica policy engine e executa integracoes externas
6. resultado final e persistido no PostgreSQL do cluster B

## 5. Fronteiras de seguranca e governanca

- LLM permanece isolado como componente de inferencia
- LLM nao recebe credenciais de Jira, Slack ou banco por padrao
- LLM nao executa automacao externa diretamente
- decisao de automacao continua centralizada no policy engine
- conhecimento tecnico continua fora do modelo e recuperado sob demanda

## 6. Riscos e trade-offs da topologia

### Beneficios

- isolamento funcional do LLM
- melhor controle de evolucao de capacidade de inferencia
- reuso de padrao operacional ja validado no homelab server

### Riscos

- dependencia da rede local entre clusters
- aumento da complexidade operacional multi-cluster
- dependencia de maturidade de GPU no cluster A

### Trade-offs

- maior resiliencia de fronteira funcional vs maior custo operacional
- reaproveitamento de padrao de operacao vs necessidade de adaptar para contexto de GPU

## 7. Alinhamento com padrao de referencia (homelab-infra)

- uso de K3s como baseline de cluster local
- bootstrap/foundation com Terraform
- GitOps com ArgoCD para reconciliacao continua
- organizacao incremental por ambientes
- observabilidade baseada em ecossistema Grafana

Nota:
Este alinhamento e de padrao operacional. Nao implica copiar implementacoes sem validacao de contexto do projeto de incident analysis.

## 8. Proximos passos de especificacao (OpenSpec)

- deployment-topology-mvp (detalhamento final por componente e ambiente)
- network-connectivity-between-clusters
- gpu-enablement-for-ollama-cluster
- argocd-bootstrap-for-ollama-cluster
- observability-baseline-for-second-cluster
- remote-llm-consumption-contract
