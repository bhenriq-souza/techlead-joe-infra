# Report de Discovery

## 1. Objetivo

Este report consolida as decisoes arquiteturais iniciais da plataforma, com foco em:

- visao global da solucao
- motivacao de negocio e tecnica
- componentes principais
- responsabilidades por componente
- decisoes tomadas e pendentes
- riscos e trade-offs
- backlog inicial de detalhamento
- direcionamento para OpenSpec

Este material deve servir como baseline para novos chats de detalhamento por dominio e por componente.

## 2. Problema que a solucao resolve

A plataforma deve:

- receber sinais de incidente a partir do stack de observabilidade no Kubernetes
- correlacionar sinais com contexto tecnico e operacional dos projetos
- usar LLM local em servidor Ubuntu para:
  - analisar incidente
  - produzir descricao padronizada
  - gerar resumo operacional
  - apoiar criacao de ticket no Jira
  - apoiar mensagem no Slack
- utilizar base viva de conhecimento tecnico (GitHub e documentacao ativa)
- atender requisitos de seguranca, boas praticas, performance, custo e preferencia por open source

## 3. Principios orientadores

### 3.1 LLM nao e detector primario

Principio operacional:

- observabilidade detecta
- plataforma interpreta e enriquece
- LLM redige e padroniza
- camada de policy decide acao final

Rationale:

- previsibilidade
- menor custo
- menor risco de falso positivo
- maior auditabilidade
- separacao entre fato e interpretacao

### 3.2 LLM como analista/redator

Papel do modelo:

- resumir incidente
- descrever impacto
- levantar hipotese principal
- sugerir proximos passos
- padronizar conteudo de Jira e Slack

Nota: template de alerting (ex.: Grafana Alerting) nao substitui analise contextual.

### 3.3 Conhecimento vivo via RAG/context injection

Estrategia:

- manter conhecimento fora do modelo
- recuperar contexto relevante no momento do incidente
- injetar contexto no prompt

Fontes previstas:

- GitHub
- README
- OpenSpec
- ADRs
- runbooks
- docs
- OpenAPI
- manifests uteis

### 3.4 Fine-tuning apenas se necessario para estilo

Fine-tuning fica como opcao futura para:

- estilo e tom
- taxonomia organizacional
- aderencia a template fixo

Antes disso, esgotar:

- schema fixo de saida
- prompt forte
- few-shot
- RAG
- pos-processamento/template

### 3.5 Preferencia por open source

Diretriz:

- priorizar ferramentas open source no caminho critico
- evitar Zapier como nucleo da arquitetura
- preferir APIs diretas e componentes controlados pelo time

## 4. Visao geral da solucao

### 4.1 Macrofluxo

1. Kubernetes/aplicacoes geram sinais.
2. Observabilidade detecta evento objetivo.
3. Evento vai para Incident Analyzer.
4. Analyzer enriquece com logs + catalogo + base viva.
5. Analyzer chama LLM local.
6. Saida estruturada e validada.
7. Policy engine decide automacao.
8. Jira e Slack sao acionados.
9. Historico e trilha de auditoria sao persistidos.

### 4.2 Componentes macro

- Observability & Alert Source
- Incident Analyzer
- Knowledge Ingestion
- Retrieval / Knowledge Access
- Operational Catalog / Admin Platform
- LLM Server
- Messaging Broker
- Integration Layer
- Persistence Layer
- Security / Governance / Policy

## 5. Stack principal definida

- Incident Analyzer e Knowledge Ingestion: Python
- Admin API/UI: Node.js + TypeScript + React + Next.js
- Broker: RabbitMQ
- Banco principal: PostgreSQL
- Base viva: GitHub + OpenSpec + README + docs + runbooks + ADRs
- LLM: local em Ubuntu, usado para analise textual e redacao padronizada

## 6. Arquitetura logica (visao textual)

GitHub Repositories (README, OpenSpec, docs, ADRs, runbooks, OpenAPI/manifests)
-> Knowledge Ingestion Service (Python)
-> Operational Catalog (PostgreSQL) e Knowledge Index/Retrieval
-> Incident Analyzer (Python)
-> Integration Layer (Jira/Slack)

Grafana/Alert Source
-> RabbitMQ
-> Incident Analyzer

## 7. Estrategia de padronizacao de saida do modelo

Ordem recomendada:

1. schema fixo
2. prompt forte
3. few-shot
4. RAG
5. fine-tuning leve (se necessario)

Resultado esperado sem fine-tuning inicial:

- consistencia de formato
- consistencia de tom
- campos obrigatorios sempre presentes
- boa qualidade de descricao operacional
