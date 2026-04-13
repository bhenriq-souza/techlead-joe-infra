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

1. Observabilidade dispara alerta.
2. Incident Analyzer recebe e valida evento.
3. Projeto/servico sao resolvidos.
4. Analyzer consulta Loki para evidencias.
5. Analyzer consulta catalogo e base viva.
6. Prompt e montado com contexto e guardrails.
7. LLM retorna analise estruturada.
8. Policy engine decide acao automatica.
9. Jira/Slack sao acionados quando elegiveis.
10. Incidente e analise sao persistidos com auditoria.

## Requisitos transversais por fluxo

- Auditabilidade completa de entradas, prompt, output e decisoes.
- Idempotencia e deduplicacao para evitar tickets duplicados.
- Retry com backoff e DLQ para falhas externas.
- Versionamento de conhecimento e de templates.
