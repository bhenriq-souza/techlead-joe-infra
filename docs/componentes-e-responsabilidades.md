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
  - chamar LLM local
  - validar schema da resposta
  - aplicar policy
  - acionar Jira/Slack
  - persistir historico e trilha de auditoria
- Principios:
  - separar fatos de interpretacao
  - nao confiar cegamente no modelo
  - versionar prompt/output

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

## 7. Messaging Broker (RabbitMQ)

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

## 10. Security / Governance / Policy

- Papel: controlar risco tecnico e operacional.
- Regras basicas:
  - separar fato de interpretacao
  - sanitizar secrets/tokens/cookies/connection strings
  - tratar logs como nao confiaveis
  - decisao final por policy engine
  - RBAC (admin, platform engineer, service owner, viewer)
  - credenciais fora do modelo

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
