# Prompt — Experimentacao em WSL: validacao do design do AI Lab (Ollama + TEI) em modo de teste

## Instrucoes para o chat

Use este prompt como ponto de partida para um chat dedicado a experimentacao do design do AI Lab no laptop admin via Ubuntu WSL2.
Cole o conteudo abaixo como sua primeira mensagem.

Este NAO e o setup oficial da workstation. E uma prova de design para validar a topologia de containers, contratos de API e operacao basica do stack antes de montar o ambiente final na workstation dedicada.

---

## Prompt

Voce e um Arquiteto de Sistemas e Engenheiro de Infraestrutura especializado em ambientes Linux, WSL2, Docker, NVIDIA CUDA e servicos de LLM local.

Preciso que voce me guie em uma EXPERIMENTACAO em modo de teste do design do meu AI Lab, executada no meu laptop admin via Ubuntu rodando em WSL2. O objetivo e validar o desenho da stack (Ollama + TEI + Docker Compose + API OpenAI-compatible), **nao** validar performance.

### Objetivo da experimentacao

- Validar o `docker-compose.yml` e a integracao entre Ollama e TEI.
- Validar que ambos respondem corretamente em endpoints OpenAI-compatible (ou endpoint nativo do TEI).
- Validar que um cliente externo (simulado via `curl`) consegue consumir via `LLM_BASE_URL` e `EMBEDDING_BASE_URL`.
- Validar comportamento basico de start/stop/restart do stack e persistencia de modelos em volumes.
- Aprender e documentar pegadinhas operacionais especificas do WSL2 (systemd, GPU passthrough, .wslconfig, localhost forwarding).

Fora de escopo:
- Latencia ou throughput representativos.
- Layout de storage `/data` em SSD dedicado (so existe na workstation).
- Exposicao na LAN para consumo de outro cluster.
- k3s, ArgoCD, Helm — esta fase e Docker Compose puro.

### Contexto da maquina (laptop admin via WSL2)

- **Host:** Windows com WSL2 + Ubuntu LTS dentro do WSL.
- **GPU:** a confirmar — pode ser:
  - laptop com GPU NVIDIA com suporte a WSL2 GPU passthrough, **ou**
  - laptop sem GPU NVIDIA (somente CPU, ou GPU integrada Intel/AMD que nao serve para CUDA).
- **Storage:** filesystem unico do WSL2. Sem SSD secundario. Volumes devem ficar dentro do filesystem do WSL, **nunca em `/mnt/c`** (I/O ruim).
- **RAM/CPU:** ajustaveis via `~/.wslconfig` no host Windows.

### Contexto arquitetural (referencia, nao escopo deste chat)

Esta experimentacao e prova de design para a workstation AI Lab final, que sera Ubuntu 26.04 LTS unico SO, RTX 5070 12 GB, 64 GB DDR5, 2x SSD NVMe 1 TB com `/data` dedicado a workloads de IA (decisoes DA-018 e DA-019 do projeto).

A plataforma final tem dois clusters:
- **Cluster A (AI Lab — workstation):** Ollama + TEI.
- **Cluster B (homelab server):** Incident Analyzer, Knowledge Ingestion, RabbitMQ, PostgreSQL etc.

Nesta experimentacao no WSL nao ha Cluster B real — o consumidor e simulado por `curl`.

### Decisoes do projeto que se aplicam (seguir, nao discutir)

1. Engine de geracao: **Ollama**, exposto via API OpenAI-compatible (`/v1/chat/completions`).
2. Engine de embeddings: **text-embeddings-inference (TEI)** em container dedicado, **nao** usar Ollama para embeddings.
3. Endpoint dinamico via env var (`LLM_BASE_URL`, `EMBEDDING_BASE_URL`) — nada hardcoded no consumidor.
4. **Docker Engine** instalado dentro do WSL Ubuntu. **Nao** usar Docker Desktop.
5. `docker-compose.yml` versionavel no repositorio. Servira de base para o setup oficial da workstation depois.
6. Manter compatibilidade com API OpenAI para que troca de provider (local -> cloud) seja transparente.

### Decisoes que NAO se aplicam neste teste

- Layout `/data` em SSD dedicado (DA-019). Use diretorio simples dentro do WSL (ex.: `~/ai-lab/data`).
- Exposicao na LAN. Use `127.0.0.1` para todos os bindings.
- Modelos 7B/14B em producao. Use modelos menores conforme cenario (ver entrega 4).
- Imagem TEI GPU obrigatoria. Variante CPU e aceitavel se nao houver GPU NVIDIA.
- Sem cluster Kubernetes nesta fase.

### O que preciso que voce entregue

#### 1. Pergunta inicial sobre hardware e ambiente

**Antes de qualquer codigo**, faca-me as perguntas abaixo e aguarde respostas para adaptar o setup:

- Qual a CPU e RAM do laptop? Quanto pretendo alocar ao WSL?
- Existe GPU NVIDIA? Se sim, qual modelo e qual a versao do driver Windows?
- Versao do Windows (10 ou 11) e numero de build?
- Versao do WSL (`wsl --version` no PowerShell) e da distro Ubuntu dentro do WSL (`lsb_release -a`)?
- Tenho preferencia entre testar via terminal so dentro do WSL, ou tambem chamar de Postman/navegador no Windows host?

A partir das respostas, escolha **explicitamente** entre os caminhos `[GPU NVIDIA disponivel]` ou `[CPU-only]` e siga somente o aplicavel.

#### 2. Checklist de pre-requisitos do WSL

- Confirmar WSL2 (nao WSL1) com `wsl -l -v`.
- Habilitar **systemd** em `/etc/wsl.conf` dentro do Ubuntu (`[boot]\nsystemd=true`) e como aplicar (`wsl --shutdown`).
- Configuracao recomendada de `~/.wslconfig` no Windows host (memoria, processadores) com base na resposta sobre RAM/CPU.
- Apenas no caminho GPU: driver NVIDIA do Windows com suporte a WSL2 GPU passthrough; verificacao de `nvidia-smi` dentro do WSL.
- Instalacao do Docker Engine dentro do WSL (repositorio oficial Docker, configuracao de servico via systemd, adicionar usuario ao grupo `docker`).
- Apenas no caminho GPU: instalacao do `nvidia-container-toolkit` dentro do WSL e configuracao do runtime no Docker (`/etc/docker/daemon.json`).
- Validacao final: `docker run --rm hello-world` e, no caminho GPU, `docker run --rm --gpus all nvidia/cuda:<tag> nvidia-smi`.

#### 3. Estrutura do `docker-compose.yml` em modo de teste

- Cabecalho do arquivo com comentario explicito: `# Modo de teste WSL — nao usar como base de producao sem revisao`.
- Servico `ollama`:
  - imagem oficial,
  - bind em `127.0.0.1:11434:11434`,
  - volume local persistente para modelos (`~/ai-lab/data/ollama` ou similar dentro do WSL),
  - runtime NVIDIA condicional (so no caminho GPU),
  - restart policy `unless-stopped`,
  - healthcheck simples.
- Servico `tei`:
  - **caminho GPU:** imagem GPU mais recente compativel,
  - **caminho CPU:** imagem `ghcr.io/huggingface/text-embeddings-inference:cpu-<versao>`,
  - modelo configuravel via env var (`MODEL_ID`),
  - bind em `127.0.0.1:8080:80`,
  - volume local para cache HuggingFace,
  - restart policy `unless-stopped`,
  - healthcheck simples.
- Arquivo `.env.example` com todas as variaveis (modelo Ollama default, modelo TEI default, paths de volume, portas).
- Rede do compose dedicada se util para isolamento.

#### 4. Sugestao de modelos para teste

Liste 2 alternativas por cenario, com tamanho aproximado e o porque da escolha:

- **LLM (Ollama):**
  - Caminho CPU: opcao primaria + alternativa (sugestoes razoaveis: familias `qwen2.5`, `llama3.2`, em tamanhos 1B-3B Q4_K_M).
  - Caminho GPU: opcao primaria + alternativa (3B a 7B Q4_K_M dependendo da VRAM disponivel).
- **Embeddings (TEI):**
  - Caminho CPU: modelos pequenos (sugestoes razoaveis: `BAAI/bge-small-en-v1.5`, `sentence-transformers/all-MiniLM-L6-v2`).
  - Caminho GPU: modelos medios (sugestoes razoaveis: `nomic-ai/nomic-embed-text-v1.5`, `BAAI/bge-m3`).

Comente brevemente os trade-offs (suporte a pt-BR, dimensao do vetor, custo de download).

#### 5. Comandos operacionais do dia a dia

- Subir/parar/derrubar o stack.
- Baixar modelos no Ollama (`ollama pull` dentro do container) sem recriar.
- Inspecionar uso de recursos (CPU/RAM/GPU) por container; no WSL, comandos especificos para verificar GPU passthrough.
- Acompanhar logs.
- Limpar volumes/cache de forma seletiva (apagar modelo X sem perder o resto).
- Fazer `docker compose down && docker compose up -d` mantendo modelos.

#### 6. Validacao do setup (criterios de aceite do teste)

Forneca scripts/comandos prontos para verificar:

1. `curl` em `http://127.0.0.1:11434/v1/chat/completions` com payload OpenAI-compat — esperar resposta JSON valida.
2. `curl` no endpoint de embeddings do TEI (`/embed` nativo e/ou `/v1/embeddings` se compativel) — esperar vetor numerico.
3. No caminho GPU: confirmar que ambos estao usando a GPU (e nao caindo em CPU silenciosamente).
4. No caminho CPU: confirmar que ambos sobem em modo CPU sem erros relacionados a CUDA.
5. Ciclo de persistencia: derrubar e subir o stack confirmando que o modelo nao precisa ser baixado de novo.
6. Acesso desde o Windows host (se aplicavel): testar do Postman/navegador em `http://localhost:11434` e `http://localhost:8080` — explicar como o localhost forwarding do WSL2 funciona aqui.

#### 7. Estrutura de diretorios no repositorio

Proponha estrutura clara para o repositorio `techlead-joe-infra`, isolando este ambiente de teste do futuro setup oficial da workstation. Sugestao inicial: algo como `experiments/wsl-ai-lab/` contendo `docker-compose.yml`, `.env.example`, `README.md` proprio do experimento, e scripts de validacao. Justifique a estrutura escolhida.

#### 8. Mapeamento de divergencias entre este teste WSL e o setup oficial da workstation

Ao final do chat, gere uma tabela com as divergencias entre este setup de teste e o setup oficial da workstation, deixando explicito o que precisara mudar na migracao:

- imagem do TEI (CPU vs GPU)
- modelo do Ollama (pequeno vs alvo 7B-14B)
- caminho de volumes (`~/ai-lab/data` vs `/data` da workstation)
- exposicao (`127.0.0.1` vs LAN)
- runtime (sem `nvidia` vs `nvidia` obrigatorio)
- presenca de `data-root` customizado em Docker (so na workstation)
- variaveis de ambiente

A tabela deve servir como guia de promocao do experimento para o ambiente oficial.

### Restricoes e preferencias

- Sem Docker Desktop. Apenas Docker Engine dentro do WSL.
- Volumes sempre dentro do filesystem do WSL, nunca em `/mnt/c`.
- Localhost-only nos bindings deste experimento.
- Manter compatibilidade com API OpenAI (`/v1/chat/completions`, `/v1/embeddings` quando aplicavel).
- Preferir open source e sem lock-in.
- Setup reproduzivel: outra pessoa deve conseguir replicar seguindo apenas o material gerado.
- Documentacao em portugues (pt-BR) para alinhar com o restante do projeto.
- Marcar **claramente** no `docker-compose.yml`, no README do experimento e no `.env.example` que se trata de modo de teste WSL.
- Nao otimizar nada para performance neste experimento — simplicidade e clareza sao prioritarias.

### Formato de resposta esperado

1. Faca primeiro as perguntas da entrega 1 e aguarde minha resposta.
2. Apos minhas respostas, escolha o caminho (`GPU` ou `CPU-only`) e produza as entregas 2-8 sequencialmente.
3. Use cabecalhos numerados conforme as entregas, em portugues.
4. Codigo em blocos com a linguagem correta (`bash`, `yaml`, `dockerfile`, `json`).
5. No final, inclua a tabela de divergencias (entrega 8) e um resumo de "proximos passos" para promover o experimento ao setup oficial da workstation.
