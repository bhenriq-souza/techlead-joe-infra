# Componentes e Responsabilidades

## 1. Observability & Alert Source

- Papel: detectar sinais objetivos e disparar evento.
- Escopo: Kubernetes, Loki, Grafana (eventualmente Alloy/OTel Collector).
- Responsabilidades:
  - coletar logs
  - indexar e permitir consulta
  - executar regras objetivas de alerta
  - publicar alerta para analise
- Diretrizes:
  - chave principal de correlacao: service.name
  - namespace e ambiente como apoio
  - evitar alta cardinalidade

## 2. Incident Analyzer (Python)

- Papel: orquestrador principal do fluxo.
- Entradas:
  - alerta
  - evidencias do Loki
  - contexto operacional
  - contexto documental
- Responsabilidades:
  - validar payload
  - resolver projeto/servico
  - montar pacote de incidente
  - chamar LLM local ou qualquer outro provider
  - validar schema da resposta
  - aplicar policy
  - acionar Jira/Slack
  - persistir historico e trilha de auditoria
- Principios:
  - separar fatos de interpretacao
  - nao confiar cegamente no modelo
  - versionar prompt/output
- Topologia MVP:
  - roda no cluster de aplicacoes (homelab server)
  - consome inferencia do LLM por comunicacao de rede local com o cluster do admin laptop

## 3. Knowledge Ingestion (Python)

- Papel: transformar documentacao viva em conhecimento recuperavel.
- Fontes: README, OpenSpec, docs, ADRs, runbooks, OpenAPI, manifests.
- Responsabilidades:
  - receber webhook ou sync agendado
  - baixar arquivos permitidos
  - extrair metadados
  - chunking e indexacao
  - classificar confiabilidade da fonte
  - atualizar referencias no catalogo
- Regras:
  - lista de caminhos aprovados
  - nao indexar indiscriminadamente
  - versionar sincronizacao

## 4. Retrieval / Knowledge Access

- Papel: entregar contexto mais util no momento da analise.
- Estrategia inicial: metadados + busca textual.
- Evolucao possivel: hibrido/embeddings quando justificar.
- Responsabilidades:
  - recuperar docs por projeto/servico
  - priorizar runbook oficial
  - retornar evidencias de alto valor para prompt

## 5. Operational Catalog / Admin Platform

- Stack: Node.js, TypeScript, React, Next.js.
- Papel: curadoria e governanca operacional.
- Responsabilidades:
  - cadastro de projeto/servico/owners
  - mapeamento service.name
  - configuracao Jira/Slack
  - definicao de runbook oficial
  - controle de documentos no RAG
  - cadastro de padroes conhecidos
- Nota: nao substitui doc tecnica viva; normaliza e governa uso runtime.

## 6. LLM Server (Ubuntu)

- Papel: inferencia textual padronizada.
- Responsabilidades:
  - analisar pacote de incidente pronto
  - retornar output estruturado
- Restricoes:
  - sem acesso direto a credenciais
  - sem execucao de automacao externa
  - sem deteccao primaria de incidente
- Topologia MVP:
  - roda em cluster k3s dedicado no admin laptop
  - segue padrao-base de deploy por ArgoCD e baseline de observabilidade alinhada ao cluster principal
  - requer configuracao de GPU NVIDIA no host para capacidade de inferencia
- Host: Ubuntu 26.04 LTS unico SO (ver DA-018). Modelos, volumes Docker e caches do Ollama/TEI residem em `/data` (SSD dedicado a workloads de IA, ver DA-019).

## 7. Messaging Broker (Sistema de filas MQTT - ainda não definido, mas com forte tendência a utilizar GCP Pub/Sub)

- Papel: desacoplamento, resiliencia e controle de throughput.
- Usos previstos:
  - analise assincrona
  - ingestao/indexacao
  - notificacoes externas
  - retries e reprocessamento
- Aberto: topologia de exchanges/queues e modelo de consumo.

## 8. Integration Layer

- Papel: executar integracoes externas com confiabilidade.
- Alvos: Jira e Slack.
- Responsabilidades:
  - criar/atualizar tickets
  - notificar canal correto
  - deduplicacao
  - retry e tratamento de falha
- Diretriz: API direta ou camada propria; evitar Zapier no core.

## 9. Persistence Layer (PostgreSQL)

- Papel: armazenar estado e historico da plataforma.
- Dados previstos:
  - catalogo operacional
  - knowledge sources/chunks
  - incidentes e analises
  - historico de integracao
  - templates e politicas
- Topologia MVP:
  - PostgreSQL permanece no cluster do homelab server nesta fase
  - componentes do cluster do admin laptop nao recebem credenciais diretas de banco por padrao
  - acesso a dados para fluxo de analise ocorre via servicos da plataforma e contratos controlados

## 10. Security / Governance / Policy

- Papel: controlar risco tecnico e operacional.
- Regras basicas:
  - separar fato de interpretacao
  - sanitizar secrets/tokens/cookies/connection strings
  - tratar logs como nao confiaveis
  - decisao final por policy engine
  - RBAC (admin, platform engineer, service owner, viewer)
  - credenciais fora do modelo

## 11. Alocacao de componentes por cluster (MVP)

### Cluster A - Ai Lab (Ollama)

- LLM Server
- observabilidade baseline do proprio cluster (alinhada ao padrao Grafana praticado)
- ArgoCD para reconciliacao GitOps de workloads do cluster A
#### PS: Preciso analisar as possibilidades de executar o LLM Server e se um cluster k3s faria sentido para ele.

### Cluster B - homelab server (k3s plataforma)

- Observability & Alert Source
- Incident Analyzer
- Knowledge Ingestion
- Retrieval / Knowledge Access
- Operational Catalog / Admin Platform
- Messaging Broker (topologia ainda em aberto)
- Integration Layer (Jira/Slack)
- Persistence Layer (PostgreSQL)
- Policy Engine e trilha de governanca

### Dependencias inter-cluster

- Incident Analyzer (cluster B) depende do endpoint de inferencia no cluster A
- fluxo depende de conectividade LAN entre clusters
- contratos de timeout/retry/fallback permanecem como detalhamento em aberto

## Contrato de saida esperado do LLM

Campos obrigatorios (MVP):

- titulo
- resumo_executivo
- impacto
- hipotese_principal
- hipoteses_alternativas
- evidencias
- acoes_sugeridas
- severidade
- confianca
- recomendacao_jira
- recomendacao_slack
