# Itens em Aberto e Backlog de Detalhamento

## 1. Itens em aberto (decisao arquitetural)

### 1.1 RabbitMQ - onde rodar

- Status: Aberto
- Prioridade: P0
- Pergunta: Kubernetes, host dedicado ou ambiente compartilhado?
- Criterios: disponibilidade, operacao, latencia, custo, backup/restore.

### 1.2 RabbitMQ - topologia

- Status: Aberto
- Prioridade: P0
- Pergunta: exchanges, roteamento, filas por dominio, retry, DLQ.
- Criterios: isolamento por dominio, throughput, simplicidade operacional.

### 1.3 Modelo LLM

- Status: Aberto
- Prioridade: P0
- Pergunta: modelo exato, tamanho, latencia alvo, fallback.
- Criterios: qualidade de texto, custo de inferencia, memoria/GPU, estabilidade.

### 1.4 Retrieval no MVP

- Status: Aberto
- Prioridade: P1
- Pergunta: textual puro ou hibrido desde o inicio?
- Criterios: relevancia, complexidade, custo de manutencao.

### 1.5 Politica de automacao do Jira

- Status: Aberto
- Prioridade: P0
- Pergunta: quando abrir automaticamente e quando exigir humano no loop?
- Criterios: severidade, confianca, risco de ruido, impacto no on-call.

### 1.6 Deploy topology

- Status: Parcialmente fechado
- Prioridade: P0
- Parte fechada: cluster dedicado para Ollama (admin laptop) e cluster dedicado para plataforma (homelab server).
- Parte aberta: contrato de comunicacao inter-cluster, fallback operacional, observabilidade cross-cluster.
- Criterios: seguranca de rede, resiliencia, observabilidade da plataforma.

### 1.7 Conectividade entre clusters

- Status: Parcialmente fechado
- Prioridade: P0
- Fechado por DA-013:
  - endpoint LLM configurado via `LLM_BASE_URL` por ConfigMap (sem hardcode).
  - comportamento de falha definido: registro com status `nao_tratado` + auditoria.
  - client OpenAI-compatible abstrai o provider subjacente.
- Ainda aberto:
  - autenticacao de servico para chamada remota (token, mTLS ou rede privada).
  - timeout e retry para o MVP (valores concretos).
  - observabilidade da latencia da chamada inter-cluster.

### 1.8 GPU enablement para o AI Lab

- Status: Parcialmente fechado
- Prioridade: P0
- Fechado por DA-014 Fase 1: GPU enablement via NVIDIA Container Toolkit no Docker (mais simples que Device Plugin k3s, resolve o bloqueio para inicio da POC).
- Ainda aberto (Fase 2 — k3s):
  - NVIDIA Device Plugin como DaemonSet no k3s.
  - constraints de scheduling (`nvidia.com/gpu: 1` no manifest do Ollama).
  - observabilidade de GPU (DCGM Exporter + Grafana).
- Criterios para Fase 2: estabilidade do Device Plugin, metricas de utilizacao de GPU no cluster.

### 1.9 ArgoCD/bootstrap para Cluster A

- Status: Parcialmente fechado
- Prioridade: P1
- Fechado por DA-014 Fase 1: Ollama gerenciado por Docker Compose versionado no repositorio (nao requer ArgoCD nesta fase).
- Ainda aberto (Fase 2): bootstrap k3s + ArgoCD para o Cluster A seguindo padrao da DA-011.
- Criterios: POC funcional com Incident Analyzer validado como gatilho para iniciar Fase 2.

### 1.10 Estrategia de backup do SSD 2 (workloads de IA)

- Status: Aberto
- Prioridade: P1
- Pergunta: o que entra em politica de backup ativa e o que e considerado regeneravel?
- Criterios:
  - regeneravel: `/data/models`, `/data/datasets` (publicos), `/data/cache`, `/data/vector-indexes` (regeneraveis a partir do RAG).
  - critico: volumes Docker em `/data/docker/volumes` (Postgres/Qdrant/etc.) e `/data/rag` (corpora curados).
  - frequencia, destino (HD externo/NAS), retencao e teste de restore precisam ser definidos.

## 2. Backlog inicial de detalhamento por chat/agente

1. P0 - Contratos de evento e schema de incidente
   - definir payload de alerta de entrada
   - definir schema de saida do LLM (JSON estrito)
   - definir versao de contrato

2. P0 - Policy engine
   - regras objetivas para Jira/Slack
   - deduplicacao por fingerprint
   - suppress window e limiares

3. P0 - Topologia RabbitMQ
   - desenho de exchanges/queues
   - retries e DLQ
   - ownership de consumidores

4. P0 - Seguranca e sanitizacao
   - mascaramento de secrets e tokens
   - protecao contra prompt injection
   - trilha de auditoria e retencao

5. P1 - Retrieval MVP
   - ranking por metadados
   - estrategia de chunking
   - criterio de priorizacao de runbooks

7. P1 - Servidor dedicado de embeddings para Knowledge Ingestion (ver DA-016)
   - servidor preferido: `text-embeddings-inference` (HuggingFace TEI)
   - alternativa: `infinity-emb` para experimentacao rapida
   - modelo sugerido: `BAAI/bge-m3` (multilingual, suporta pt-BR) ou `nomic-ai/nomic-embed-text-v1.5`
   - execucao: container Docker no AI Lab, porta dedicada (ex: 8080), variavel `EMBEDDING_BASE_URL` no Knowledge Ingestion
   - a ser implementado junto com o modulo de Knowledge Ingestion (nao bloqueia o MVP do Incident Analyzer)

6. P1 - Integracao Jira/Slack
   - idempotencia
   - mapeamento projeto/canal
   - tratamento de erro e reprocessamento

7. P1 - Modelo de dados PostgreSQL
   - entidades e relacionamentos
   - indices principais
   - estrategia de versionamento de analise

8. P2 - Benchmark de modelos LLM
   - suite de prompts de incidente
   - metricas de qualidade e consistencia
   - matriz custo x latencia x qualidade

9. P0 - Deployment topology MVP (2 clusters)
   - definir alocacao final de componentes por cluster
   - definir dependencias inter-cluster e caminho de falha
   - explicitar dependencia de PostgreSQL no homelab server

10. P0 - Network connectivity between clusters
   - definir contrato de comunicacao remota Analyzer -> LLM
   - definir timeout, retry, circuit-breaker e fallback
   - definir requisitos minimos de seguranca em rede local

11. P0 - GPU enablement for Ollama cluster
   - definir baseline de configuracao NVIDIA no host
   - definir validacoes operacionais de inferencia
   - definir telemetria minima de GPU para operacao

12. P1 - ArgoCD bootstrap for Ollama cluster
   - definir padrao de bootstrap GitOps para segundo cluster
   - alinhar estrutura de apps e ownership operacional
   - validar convergencia com padrao do homelab server

13. P1 - Observability baseline for second cluster
   - definir stack minima alinhada ao ecossistema Grafana
   - definir paineis basicos de saude do cluster Ollama
   - definir sinais para detectar degradacao da inferencia

14. P1 - Remote LLM consumption contract
   - definir schema de request/response entre clusters
   - definir codigos de erro e semantica de degradacao
   - definir requisitos de auditabilidade da chamada remota

## 3. Riscos de execucao do backlog

- Escopo crescer sem fechar contratos cedo.
- Sem policy clara, automacao pode gerar ruido.
- Sem curadoria de conhecimento, RAG degrada confiabilidade.
- Topologia em dois clusters sem contrato remoto fechado pode gerar instabilidade no fluxo de analise.
