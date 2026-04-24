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
- Fontes: GitHub, OpenSpec, README, docs, ADRs, runbooks, OpenAPI, Graphify graphs e manifests uteis.
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

### DA-009 - MVP com dois clusters k3s

- Status: Fechada
- Decisao: executar o MVP em dois clusters separados:
  - cluster dedicado ao Ollama Server (admin laptop)
  - cluster dedicado as demais aplicacoes (homelab server)
- Consequencia: isolamento do componente de inferencia e reducao de acoplamento direto entre LLM e workloads de plataforma.
- Trade-off: aumenta o custo operacional e de conectividade entre clusters.

### DA-010 - Cluster Ollama no AI Lab (workstation) para POC

- Status: Fechada (revisada)
- Decisao: hospedar o Cluster A (inferencia Ollama) na workstation AI Lab dedicada durante o desenvolvimento e a POC.
  - Hardware: AMD Ryzen 9 7900X, RTX 5070 12 GB GDDR7, 64 GB DDR5, Ubuntu.
  - Substitui o plano anterior de usar o admin laptop como host do Cluster A.
- Escopo: a maquina opera como AI Lab somente durante a POC/desenvolvimento ativo.
- Producao: o endpoint de inferencia sera migrado para outro provedor; nenhum componente do Cluster B depende de endere\u00e7o fixo do AI Lab (ver DA-013).
- Consequencia: GPU dedicada real viabiliza inferencia de qualidade com modelos 7B-14B; ambiente Ubuntu serve tambem como dev environment principal.
- Trade-off: quando a maquina estiver desligada, o fluxo de analise entra em modo de falha controlada (ver DA-013).

### DA-011 - Reuso de padrao operacional do homelab server

- Status: Fechada
- Decisao: cluster do Ollama deve seguir o mesmo padrao-base do cluster principal:
  - bootstrap com Terraform
  - deploy via ArgoCD/GitOps
  - baseline de observabilidade alinhada ao ecossistema Grafana ja praticado
- Consequencia: reduz variacao operacional entre clusters.
- Trade-off: exige adaptacoes explicitas para recursos de GPU.

### DA-012 - PostgreSQL permanece no cluster do homelab server

- Status: Fechada
- Decisao: manter PostgreSQL existente no cluster do homelab server nesta fase do MVP.
- Consequencia: evita migracao prematura de dados e simplifica continuidade operacional.
- Trade-off: cria dependencia de rede para componentes que consumirem dados a partir do cluster do laptop.

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

- Status: Parcialmente fechada
- Parte fechada: separacao em dois clusters k3s e permanencia do PostgreSQL no homelab server.
- Parte aberta: conectividade inter-cluster detalhada, SLOs de comunicacao, estrategia de fallback e padrao de observabilidade cross-cluster.

### AA-007 - Contrato de comunicacao inter-cluster

- Status: Aberta
- Pendente: protocolo, autenticacao de servico, timeout/retry, e padrao de erro para consumo remoto do Ollama.

### AA-008 - Baseline GPU para cluster Ollama

- Status: Aberta
- Pendente: padrao de enablement NVIDIA no host, constraints de agendamento e controles de capacidade para inferencia.

### DA-013 - Endpoint LLM dinamico e comportamento de falha controlada no MVP

- Status: Fechada
- Decisao:
  - o endere\u00e7o do LLM server e configurado por variavel de ambiente (`LLM_BASE_URL`) injetada via ConfigMap no Cluster B.
  - durante a POC/desenvolvimento: endpoint aponta para Ollama no AI Lab (workstation local) na rede LAN.
  - em producao ou quando o AI Lab nao estiver disponivel: endpoint aponta para provider externo (ex: OpenAI, Groq, Anthropic) ou infra dedicada.
  - o Incident Analyzer usa client compativel com a API OpenAI (`/v1/chat/completions`) para abstrair qualquer provider.
- Comportamento de falha MVP:
  - quando o LLM server nao estiver acessivel ou retornar erro, o Analyzer registra o incidente no PostgreSQL com status `nao_tratado`.
  - o registro inclui trilha de auditoria com motivo da falha e timestamp.
  - nenhuma acao automatica (Jira/Slack) e disparada nesse caso.
  - operador pode consultar incidentes `nao_tratados` para reprocessamento manual.
- Fase 2 (adiada):
  - fallback automatico para provider alternativo.
  - retentativas com backoff exponencial.
  - insercao em DLQ para reprocessamento assincrono.
- Consequencia: simplifica o MVP sem perder rastreabilidade; todo incidente tem registro independente de o LLM estar disponivel.
- Trade-off: incidentes em janelas de indisponibilidade do LLM nao sao analisados automaticamente nesta fase.

### AA-009 - Contrato remoto de consumo do LLM

- Status: Parcialmente fechada
- Fechado por DA-013: interface via API OpenAI-compatible, comportamento de falha e estrategia de configuracao dinamica.
- Pendente: latencia alvo, timeouts, observabilidade da chamada remota e criterios de SLO.

### DA-014 - Estrategia de execucao do LLM server no AI Lab (fases)

- Status: Fechada
- Decisao: adotar abordagem em duas fases para o Cluster A (AI Lab):
  - Fase 1 — POC/desenvolvimento ativo: Ollama + Docker Compose com NVIDIA Container Toolkit.
    - Setup rapido (~30-60 min incluindo GPU enablement no Docker).
    - `docker-compose.yml` versionado no repositorio (infra como codigo desde o inicio).
    - Endpoint LAN disponivel para Cluster B via `LLM_BASE_URL`.
    - Permite validar modelos, prompts e fluxo completo de analise de incidente sem bloqueio operacional.
  - Fase 2 — formalizacao do Cluster A: Ollama + k3s + ArgoCD (alinhamento pleno com DA-011).
    - Gatilho: POC validada com fluxo de analise de incidente funcional.
    - Bootstrap k3s com GPU enablement (fecha item 1.8).
    - Manifests gerenciados via ArgoCD.
    - Nenhuma mudanca necessaria no Cluster B para a transicao.
- Engine escolhida: Ollama em ambas as fases.
  - API OpenAI-compatible nativa (`/v1/chat/completions`, `/v1/embeddings`).
  - Gestao integrada de modelos.
  - Suporte a GGUF (eficiencia de storage no SSD de 1 TB).
  - Ecossistema amplo e atualizado.
- Consequencia: velocidade de inicio na Fase 1 sem criar divida de alinhamento; Fase 2 fecha os itens arquiteturais pendentes.
- Trade-off: dois caminhos operacionais temporarios (Docker no AI Lab, k3s no homelab server) durante a Fase 1.

### DA-015 - Perfil de carga do LLM server por consumidor

- Status: Fechada
- Contexto: o LLM server e consumido por dois componentes com perfis distintos:
  - Incident Analyzer: latencia-sensitiva, baixa concorrencia, 1 request por incidente, precisa de resposta em segundos.
  - Knowledge Ingestion: batch/assincrona, potencialmente alta concorrencia (N chunks por sync de repositorio), sem pressao de SLA imediato.
- Decisao: separar responsabilidades de inferencia por tipo de tarefa:
  - Geracao de texto (LLM): Ollama — atende o Incident Analyzer e qualquer necessidade de geracao da ingestao.
  - Embeddings (vetorizacao): servidor dedicado (ver DA-016) — atende o Knowledge Ingestion com throughput superior.
- Consequencia: cada componente usa o servidor mais adequado ao seu perfil de carga, sem acoplamento indevido.
- Trade-off: dois servicos no AI Lab em vez de um, mas ambos rodam no mesmo host e compartilham a GPU sem conflito.

### DA-016 - Servidor dedicado de embeddings para Knowledge Ingestion

- Status: Fechada
- Decisao: utilizar servidor dedicado de embeddings para o componente Knowledge Ingestion, em vez de delegar ao Ollama.
- Opcoes concretas avaliadas:
  - `text-embeddings-inference` (HuggingFace TEI): servidor de embeddings de alta performance, otimizado para GPU NVIDIA, suporte a modelos BGE, E5, nomic-embed, all-MiniLM. API REST simples. Imagem Docker oficial.
  - `infinity-emb`: servidor de embeddings Python-native, suporte a multiplos backends (torch, ONNX, TensorRT), API OpenAI-compatible para embeddings. Bom para experimentacao rapida.
- Preferencia para MVP: `text-embeddings-inference` (TEI) pela maturidade, performance documentada e alinhamento com o ecossistema HuggingFace.
- Modelo de embedding sugerido para inicio: `BAAI/bge-m3` (multilingual, suporta pt-BR, dense + sparse retrieval) ou `nomic-ai/nomic-embed-text-v1.5`.
- Execucao: container Docker no AI Lab, na mesma maquina que o Ollama, com acesso a GPU via NVIDIA Container Toolkit.
- Exposicao: porta dedicada (ex: `8080`) na rede LAN; `EMBEDDING_BASE_URL` como variavel de ambiente no Knowledge Ingestion (mesmo padrao de DA-013).
- Consequencias:
  - throughput de vetorizacao significativamente superior ao Ollama para cargas batch.
  - Ollama fica exclusivo para geracao de texto, sem competicao de VRAM durante syncs de repositorio.
  - Knowledge Ingestion tem endpoint de embedding independente e substituivel.
- Trade-off: um container adicional no AI Lab; modelos HuggingFace para embedding (mas TEI usa modelos leves, ~500 MB–1.5 GB).
- Evolutivo: se TEI mostrar gargalo em ingestao de alto volume, avaliar `infinity-emb` com backend TensorRT ou upgrade de VRAM.

### DA-017 - vLLM como opcao evolutiva condicionada a evidencia de gargalo

- Status: Evolutiva
- Decisao: vLLM nao sera adotado no MVP. A troca so se justifica com evidencia mensuravel.
- Gatilhos para reavaliar:
  - Multiplos incidentes simultaneos causando fila perceptivel no Ollama.
  - Latencia de geracao comprometendo SLA do Incident Analyzer.
  - Throughput de geracao insuficiente mesmo apos separacao de embeddings (DA-016).
- Restricao: trocar para vLLM sem evidencia aumenta custo operacional sem ganho comprovado (modelos safetensors ocupam 2-3x mais storage que GGUF, setup CUDA mais pesado, sem gestao integrada de modelos).

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
- Risco: indisponibilidade da rede local entre clusters interromper fluxo de analise.
  - Mitigacao: timeout curto, retry com backoff, fallback controlado e status explicito de "analise parcial".
- Risco: degradacao de inferencia por configuracao incompleta de GPU no cluster Ollama.
  - Mitigacao: trilha especifica de bootstrap GPU com criterios objetivos de aceite.
- Risco: aumento de complexidade de operacao com dois clusters.
  - Mitigacao: padronizar GitOps, observabilidade e runbooks nos dois clusters.
