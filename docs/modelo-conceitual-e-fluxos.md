# Modelo Conceitual e Fluxos

## Entidades conceituais

- Project: sistema/produto.
- Service: servico tecnico de um projeto.
- ServiceDependency: dependencias criticas do servico.
- ServiceOwner: ownership e escalonamento.
- TechProfile: resumo tecnico-operacional.
- KnowledgeSource: fonte documental.
- KnowledgeChunk: trecho indexado para retrieval.
- IncidentRuleProfile: padrao conhecido de incidente.
- Incident: incidente recebido/processado.
- IncidentAnalysis: resultado estruturado da analise.

## Fluxo 1 - Ingestao de conhecimento

1. Projeto e servico sao cadastrados no catalogo.
2. Repositorio e fontes documentais sao associados.
3. Sync coleta documentos permitidos.
4. Conteudo e processado e indexado.
5. Catalogo e retrieval ficam enriquecidos para uso runtime.

## Fluxo 2 - Analise de incidente

### Caminho nominal
1. Observabilidade dispara alerta.
2. Incident Analyzer recebe e valida evento.
3. Projeto/servico sao resolvidos.
4. Analyzer consulta Loki para evidencias.
5. Analyzer consulta catalogo e base viva.
6. Prompt e montado com contexto e guardrails.
7. Analyzer chama `LLM_BASE_URL` (endpoint configuravel por ambiente).
8. LLM retorna analise estruturada.
9. Policy engine decide acao automatica.
10. Jira/Slack sao acionados quando elegiveis.
11. Incidente e analise sao persistidos com status `analisado` e auditoria completa.

### Caminho de falha — LLM indisponivel (MVP)
1. Passos 1-6 identicos ao caminho nominal.
2. Chamada ao `LLM_BASE_URL` falha (timeout, conexao recusada ou erro do provider).
3. Analyzer captura o erro e monta registro de falha estruturado.
4. Incidente e persistido no PostgreSQL com:
   - status: `nao_tratado`
   - motivo: descricao tecnica do erro de inferencia
   - timestamp e trilha de auditoria
5. Nenhuma acao automatica e disparada (sem Jira/Slack).
6. Operador pode consultar incidentes `nao_tratados` para reprocessamento manual.

> Nota: fallback automatico, DLQ e retentativas com backoff estao adiados para Fase 2 (ver DA-013).

## Fluxo 3 - Comunicacao entre clusters no MVP

1. Incident Analyzer roda no Cluster B (homelab server).
2. Analyzer monta pacote de incidente com contexto e guardrails.
3. Analyzer envia requisicao de inferencia para `LLM_BASE_URL` (Ollama no AI Lab durante POC, provider externo em producao).
4. Ollama processa inferencia com aceleracao GPU (RTX 5070) e retorna analise estruturada.
5. Resposta retorna ao Analyzer no Cluster B.
6. Policy engine decide automacao (Jira/Slack) no Cluster B.
7. Persistencia final ocorre no PostgreSQL do Cluster B.

> Nota: Knowledge Ingestion consome `EMBEDDING_BASE_URL` (TEI no AI Lab) de forma independente, sem passar pelo fluxo de analise de incidente.

## Fluxo 4 - Operacao GitOps em dois clusters

1. Repositorio Git registra manifesto/valores por cluster e ambiente.
2. ArgoCD no cluster A reconcilia workloads do Ollama cluster.
3. ArgoCD no cluster B reconcilia workloads da plataforma principal.
4. Observabilidade em cada cluster publica sinais para operacao local do proprio cluster.
5. Incidentes de conectividade inter-cluster entram no fluxo normal de deteccao e analise.

## Topologia conceitual de deployment (MVP)

- Cluster A (AI Lab — workstation Ubuntu): inferencia LLM dedicada (Ollama + RTX 5070), ArgoCD e observabilidade baseline. Ativo durante POC/desenvolvimento.
- Cluster B (homelab server): ingestao, analise, policy, integracoes externas, broker e PostgreSQL.
- Comunicacao A <-> B: rede LAN; endpoint de inferencia configurado via `LLM_BASE_URL` no Cluster B (dinamico por ambiente).
- Producao: `LLM_BASE_URL` aponta para provider externo; Cluster A nao e requisito de runtime.
- Restricao de seguranca: LLM permanece isolado como componente de inferencia, sem credenciais de integracao e sem automacao externa direta.

## Requisitos transversais por fluxo

- Auditabilidade completa de entradas, prompt, output e decisoes.
- Idempotencia e deduplicacao para evitar tickets duplicados.
- Retry com backoff e DLQ para falhas externas.
- Versionamento de conhecimento e de templates.
- Observabilidade por cluster e rastreabilidade de chamadas inter-cluster.
