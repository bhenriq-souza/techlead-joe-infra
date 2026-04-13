# Decisoes Arquiteturais

## Decisoes fechadas

### DA-001 - Detector primario e a observabilidade

- Status: Fechada
- Decisao: deteccao primaria acontece no stack de observabilidade, nao no LLM.
- Consequencia: menor custo, maior previsibilidade e melhor auditabilidade.
- Trade-off: qualidade das regras de alerta vira fator critico.

### DA-002 - LLM local como analista/redator

- Status: Fechada
- Decisao: LLM local em Ubuntu para analise textual, hipotese e redacao padronizada.
- Restricao: modelo nao aciona sistema externo diretamente e nao recebe stream bruto.
- Trade-off: exige orquestracao forte no Incident Analyzer.

### DA-003 - Conhecimento vivo via RAG/context injection

- Status: Fechada
- Decisao: conhecimento tecnico fica fora do modelo e e recuperado sob demanda.
- Fontes: GitHub, OpenSpec, README, docs, ADRs, runbooks, OpenAPI e manifests uteis.
- Trade-off: qualidade do retrieval impacta diretamente a resposta.

### DA-004 - Fine-tuning adiado

- Status: Evolutiva
- Decisao: nao fazer fine-tuning no inicio; usar schema, prompt, few-shot e RAG.
- Gatilho para revisao: persistencia de baixa consistencia mesmo apos melhorias de prompt/retrieval.

### DA-005 - Prioridade open source

- Status: Fechada
- Decisao: privilegiar stack open source e controle interno do pipeline critico.
- Consequencia: menor lock-in e maior governanca.

### DA-006 - Stack por componente

- Status: Fechada
- Decisao:
  - Python para Incident Analyzer e Knowledge Ingestion
  - Node.js + TypeScript + React + Next.js para Admin Platform
  - RabbitMQ para broker
  - PostgreSQL para persistencia principal

### DA-007 - Policy engine decide automacao

- Status: Fechada
- Decisao: abrir Jira e notificar Slack depende de politica objetiva, nao apenas da opiniao do LLM.
- Criterios esperados: confidence minima, severidade minima, deduplicacao e suppress window.

### DA-008 - Seguranca por design

- Status: Fechada
- Decisao:
  - separar fato de interpretacao
  - sanitizar dados sensiveis antes do LLM
  - tratar logs como entrada nao confiavel
  - manter credenciais fora do modelo

## Decisoes abertas

### AA-001 - Topologia de execucao do RabbitMQ

- Status: Aberta
- Impacto: resiliencia, latencia, operacao e custo.
- Alternativas: Kubernetes, host dedicado, runtime compartilhado.

### AA-002 - Topologia logica do RabbitMQ

- Status: Aberta
- Pendente: exchanges, filas por dominio, DLQ e estrategia de retry.

### AA-003 - Modelo LLM para MVP

- Status: Aberta
- Pendente: familia/modelo exato, tamanho, throughput, fallback e tuning de inferencia.

### AA-004 - Estrategia inicial de retrieval

- Status: Aberta
- Pendente: textual puro no MVP vs hibrido/embeddings.

### AA-005 - Politica de automacao Jira

- Status: Aberta
- Pendente: thresholds para abertura automatica e casos com revisao humana.

### AA-006 - Deploy topology

- Status: Aberta
- Pendente: onde cada componente roda, rede interna, observabilidade da plataforma.

## Riscos e mitigacoes iniciais

- Risco: hallucination e inferencia fraca do LLM.
  - Mitigacao: schema estrito, validacao, policy, evidencias obrigatorias.
- Risco: prompt injection via logs/docs.
  - Mitigacao: sanitizacao, delimitacao de contexto, filtros e validacao de saida.
- Risco: ruido na deteccao de incidentes.
  - Mitigacao: regras objetivas, tuning de alertas, deduplicacao e suppression.
- Risco: sobrecarga operacional em picos.
  - Mitigacao: RabbitMQ, retries com backoff, DLQ e workers especializados.
- Risco: base de conhecimento desatualizada.
  - Mitigacao: sync por evento + agendado, versionamento e curadoria.
