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
- define alocacao por 2 clusters k3s no MVP
- define dependencias entre cluster Ollama (admin laptop) e cluster plataforma (homelab server)
- define fronteiras de seguranca, secrets e observabilidade por cluster

9. `network-connectivity-between-clusters`
- define contrato de comunicacao inter-cluster entre Incident Analyzer e endpoint LLM
- define timeout, retry, fallback e requisitos minimos de seguranca de rede local

10. `gpu-enablement-for-ollama-cluster`
- define baseline de configuracao NVIDIA no host e no cluster de inferencia
- define validacoes de capacidade/estabilidade e sinais de observabilidade de GPU

11. `argocd-bootstrap-for-ollama-cluster`
- define bootstrap GitOps para o segundo cluster
- define alinhamento de padrao operacional com cluster principal sem copiar implementacao cegamente

12. `observability-baseline-for-second-cluster`
- define stack minima de observabilidade para cluster do Ollama
- define paineis/sinais minimos para saude de inferencia e comunicacao inter-cluster

13. `remote-llm-consumption-contract`
- define contrato de request/response para consumo remoto de inferencia
- define codigos de erro, degradacao controlada e campos obrigatorios de auditoria

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
