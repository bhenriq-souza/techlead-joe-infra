# Direcionamento OpenSpec

## Objetivo

Transformar o discovery em especificacoes incrementais, testaveis e rastreaveis.

## Sequencia recomendada de specs

1. `incident-event-contract`
- define contrato de entrada do alerta
- define campos minimos de correlacao (`service.name`, ambiente, namespace, timestamp)

2. `incident-analysis-schema`
- define schema JSON de saida do LLM
- define validacoes obrigatorias e codigo de erro de validacao

3. `policy-engine-rules`
- define regras para abrir Jira/notificar Slack
- define deduplicacao, suppress window e thresholds

4. `knowledge-ingestion-mvp`
- define fontes aceitas e regras de sync
- define chunking, metadados e versionamento

5. `retrieval-mvp`
- define algoritmo inicial (metadado + textual)
- define criterio de ordenacao e limite de contexto para prompt

6. `integrations-jira-slack`
- define contratos de integracao, idempotencia e retry

7. `security-governance-baseline`
- define mascaramento e classificacao de dado sensivel
- define trilha de auditoria e RBAC

8. `deployment-topology-mvp`
- define onde cada componente roda
- define conectividade, secrets e observabilidade da plataforma

## Template sugerido por spec

Cada spec deve incluir:

- contexto e problema
- objetivos e nao objetivos
- contrato (entrada/saida)
- regras de negocio
- fluxos de excecao
- observabilidade
- seguranca e compliance
- rollback/feature flags
- criterios de aceite
- plano de testes

## Definicao de pronto para cada spec

- contrato revisado e versionado
- exemplos validos e invalidos
- impacto em componentes mapeado
- riscos conhecidos documentados
- criterios de aceite objetivos
