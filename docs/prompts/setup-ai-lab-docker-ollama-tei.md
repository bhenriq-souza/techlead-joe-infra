# Prompt — Setup do AI Lab: Docker Compose + NVIDIA Container Toolkit + Ollama + TEI

## Instrucoes para o chat

Use este prompt como ponto de partida para um chat dedicado ao setup do AI Lab.
Cole o conteudo abaixo como sua primeira mensagem.

---

## Prompt

Voce e um Arquiteto de Sistemas e Engenheiro de Infraestrutura especializado em ambientes Linux, Docker, NVIDIA CUDA e servicos de LLM local.

Preciso que voce me guie no setup completo do meu AI Lab, que e uma workstation Ubuntu dedicada ao desenvolvimento e execucao local de LLM e embeddings durante minha POC.

### Contexto da maquina

- **OS:** Ubuntu 26.04 LTS — unico sistema operacional, sem dual boot (ver DA-018).
- **CPU:** AMD Ryzen 9 7900X (12 cores / 24 threads)
- **GPU:** ASUS NVIDIA GeForce RTX 5070 ATS OC, 12 GB GDDR7
- **RAM:** 64 GB DDR5
- **Placa-mae:** MSI PRO B650M-P (AM5, B650)
- **Cooler:** Water Cooler Gamemax IceBurg 360N2 360 mm
- **Fonte:** Corsair RM850e 850 W
- **Gabinete:** Montech King 65 Pro
- **Storage:** 2x SSD ADATA Legend 860 1 TB NVMe PCIe 4.0, com separacao funcional (ver DA-019):
  - **SSD 1 (`/`):** sistema, `/home`, ferramentas de desenvolvimento, repositorios.
  - **SSD 2 (`/data`):** workloads de IA — modelos (`/data/models`), datasets (`/data/datasets`), volumes Docker (`/data/docker`), indices vetoriais (`/data/vector-indexes`), bases RAG (`/data/rag`), cache (`/data/cache`).
- **Docker `data-root`:** configurado para `/data/docker` para evitar consumo do SSD do SO.

### Contexto arquitetural da solucao

Esta maquina e o **Cluster A (AI Lab)** de uma plataforma de analise automatica de incidentes com LLM + RAG. A plataforma tem dois clusters k3s:
- **Cluster A (AI Lab — esta maquina):** responsavel pela inferencia LLM e vetorizacao de embeddings.
- **Cluster B (homelab server):** responsavel pelos demais componentes (Incident Analyzer, Knowledge Ingestion, RabbitMQ, PostgreSQL, etc.).

O Cluster B consome o LLM server do Cluster A via variavel de ambiente `LLM_BASE_URL` (API OpenAI-compatible).
O componente de Knowledge Ingestion do Cluster B consome o servidor de embeddings do Cluster A via `EMBEDDING_BASE_URL`.

### Decisoes arquiteturais ja tomadas (nao discutir, apenas seguir)

1. **Fase 1 da POC:** Ollama + Docker Compose (nao k3s ainda). O `docker-compose.yml` deve ser versionado no repositorio.
2. **Engine de geracao (LLM):** Ollama. Serve o Incident Analyzer via API OpenAI-compatible (`/v1/chat/completions`).
3. **Engine de embeddings:** `text-embeddings-inference` (HuggingFace TEI) em container dedicado. Serve o Knowledge Ingestion. Nao usar o Ollama para embeddings em producao.
4. **GPU passthrough:** via NVIDIA Container Toolkit (nao NVIDIA Device Plugin do k3s — isso e Fase 2).
5. **Endpoint dinamico:** ambos os servicos devem expor suas portas na rede LAN para que o Cluster B possa consumir. Nenhum endereco deve ser hardcoded nos componentes consumidores.
6. **Modelo de LLM sugerido para inicio:** familia Qwen 2.5 ou Llama 3.1/3.2, tamanho 7B ou 14B, quantizacao Q4_K_M. A decisao exata de modelo ainda esta em aberto — inclua orientacoes para escolha.
7. **Modelo de embedding sugerido:** `BAAI/bge-m3` (multilingual, suporta pt-BR, dense + sparse) ou `nomic-ai/nomic-embed-text-v1.5`.

### O que preciso que voce entregue

**1. Checklist de pre-requisitos do host Ubuntu**
- Versao recomendada do Ubuntu (LTS)
- Drivers NVIDIA (versao minima para RTX 5070 / arquitetura Blackwell)
- CUDA Toolkit (necessario no host ou apenas no container?)
- Docker Engine (nao Docker Desktop)
- NVIDIA Container Toolkit: instalacao e configuracao do runtime

**1.1 Layout de storage e Docker data-root**
- Identificar UUID dos SSDs com `blkid`.
- Criar ponto de montagem `/data` e entrada em `/etc/fstab` por UUID:
  - filesystem: `ext4`
  - opcoes: `defaults,noatime`
  - dump/pass: `0 2`
- Criar subdiretorios em `/data` (`models`, `datasets`, `docker`, `vector-indexes`, `rag`, `cache`).
- Ajustar permissoes para o usuario principal (`chown -R <user>:<user> /data`).
- Configurar Docker para usar `/data/docker` como `data-root` em `/etc/docker/daemon.json` antes de baixar imagens grandes.
- Validar com `docker info | grep "Docker Root Dir"`.

**2. Estrutura do `docker-compose.yml`**
- Servico `ollama`: imagem, runtime NVIDIA, portas, volumes para modelos, politica de restart
- Servico `tei` (text-embeddings-inference): imagem, runtime NVIDIA, modelo configuravel via variavel de ambiente, porta dedicada, politica de restart
- Variaveis de ambiente relevantes para cada servico
- Volume nomeado para modelos do Ollama (considerar o limite de 1 TB do SSD)
- Rede interna entre servicos se necessario

**3. Comandos de operacao do dia a dia**
- Subir/parar os servicos (o AI Lab e ligado/desligado conforme necessidade)
- Baixar e trocar modelos no Ollama sem recriar o container
- Verificar uso de GPU por container
- Checar logs dos servicos

**4. Validacao do setup**
- Como testar que o Ollama esta respondendo via API (curl de exemplo com `/v1/chat/completions`)
- Como testar que o TEI esta respondendo via API (curl de exemplo com endpoint de embeddings)
- Como confirmar que ambos estao usando a GPU (nao CPU fallback)

**5. Consideracoes de seguranca e boas praticas**
- Exposicao de portas na LAN (o Cluster B precisa acessar, mas o servico nao deve ser publico)
- Gestao de storage: onde armazenar modelos, quanto espaco reservar, como limpar modelos nao utilizados
- Qualquer risco especifico da RTX 5070 (arquitetura Blackwell) com versoes de drivers/CUDA

**6. Estrutura de diretorios sugerida no repositorio**
- Onde o `docker-compose.yml` deve ficar no repositorio `techlead-joe-infra`
- Arquivo `.env.example` com as variaveis de ambiente necessarias
- README minimo para o modulo ai-lab

### Restricoes e preferencias

- Preferir solucoes open source e sem lock-in de plataforma.
- O setup deve ser reproducivel: outra pessoa deve conseguir replicar seguindo a documentacao.
- Nao incluir k3s, Helm ou ArgoCD nesta fase — isso e Fase 2.
- Nao usar Docker Desktop — apenas Docker Engine.
- O host Ubuntu tambem e ambiente de desenvolvimento ativo (VSCode, Python, Node, containers de dev). O setup do AI Lab nao deve conflitar com isso.
- Manter compatibilidade com a API OpenAI para que a troca de provider (local -> cloud) seja transparente para os consumidores.
