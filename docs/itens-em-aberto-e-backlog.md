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

- Status: Aberto
- Prioridade: P0
- Pergunta: posicionamento de cada componente e comunicacao interna.
- Criterios: seguranca de rede, resiliencia, observabilidade da plataforma.

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

## 3. Riscos de execucao do backlog

- Escopo crescer sem fechar contratos cedo.
- Sem policy clara, automacao pode gerar ruido.
- Sem curadoria de conhecimento, RAG degrada confiabilidade.
