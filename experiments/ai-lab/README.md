# AI Lab — Setup oficial da workstation (Fase 1: Docker Compose)

> **Referencia arquitetural:** DA-014 (Fase 1), DA-015, DA-016, DA-018, DA-019
> Promovido do experimento validado em `experiments/wsl-ai-lab/` (2026-04-27).

## Status: VALIDADO

**Data:** 2026-05-13
**Resultado:** stack subiu com sucesso; criterios de aceite confirmados.

**Pegadinhas encontradas — ver secao no final deste README.**

## Objetivo

Executar a stack Ollama + TEI full-GPU na workstation Ubuntu 26.04 com RTX 5070 12 GB,
exposta na LAN para consumo pelo Cluster B (Incident Analyzer, Knowledge Ingestion).

## Hardware

| Componente | Especificacao |
|---|---|
| CPU | AMD Ryzen 9 7900X — 12c/24t |
| GPU | Asus RTX 5070 ATS OC — 12 GB GDDR7, Blackwell (sm_120) |
| RAM | 64 GB DDR5 5600 MHz |
| SSD dados | NVMe 2 montado em `/data` — modelos, Docker data-root (DA-019) |
| OS | Ubuntu 26.04 LTS nativo (DA-018) |
| IP LAN | `192.168.15.103` (DHCP reservado) |

## Estrategia GPU

| Servico | Runtime | Justificativa |
|---|---|---|
| Ollama | **GPU** (RTX 5070) | Inferencia LLM — beneficia de GPU |
| TEI | **CPU** (workaround) | Sem imagem GPU funcional para Blackwell (sm_120) — `cpu-latest` como fallback viavel com 64 GB DDR5 |

### Impacto do TEI em CPU

| Dimensao | GPU (ideal) | CPU (atual) |
|---|---|---|
| Qualidade dos vetores | identica | identica |
| Latencia por chamada | ~2–30 ms | ~50–800 ms |
| Knowledge Ingestion (1000 chunks) | ~10–60 s | ~2–10 min |
| RAG em tempo real | insignificante | insignificante* |
| VRAM consumida | ~1 GB | 0 |

*Em queries RAG, a chamada Ollama domina (~2–5 s); os ~100 ms do TEI em CPU sao desprezíveis.

A GPU permanece dedicada integralmente ao Ollama — sem competicao de VRAM.
A qualidade dos embeddings e identica: os vetores sao matematicamente os mesmos independente do hardware.

## Modelos

| Servico | Modelo padrao | Alternativa |
|---|---|---|
| Ollama (LLM) | `qwen2.5:7b` | `llama3.1:8b`, `qwen2.5:14b` |
| TEI (embeddings) | `BAAI/bge-m3` (multilingual, pt-BR) | `nomic-ai/nomic-embed-text-v1.5` |

## Criterios de aceite

| Criterio | Status |
|---|---|
| Ollama `/v1/chat/completions` (API OpenAI-compat) | OK |
| TEI `/embed` retorna vetor | OK |
| TEI `/v1/embeddings` (compat OpenAI) disponivel | OK |
| Container Ollama com runtime NVIDIA configurado | OK |
| Container TEI em modo CPU (workaround Blackwell) | OK |
| Bind mounts em `/data` persistem apos `down/up` | OK |

## Estrutura de arquivos

```
experiments/ai-lab/
├── docker-compose.yml      # Stack principal
├── .env.example            # Variaveis necessarias — copiar para .env
├── README.md               # Este arquivo
└── scripts/
    └── validate.sh         # Script de criterios de aceite
```

## Pre-requisitos do host

### 1. /data montado e diretorios criados (DA-019)

```bash
df -h /data                          # deve mostrar o SSD NVMe 2
ls /data/models/ollama               # deve existir
ls /data/models/tei-cache            # deve existir
ls /data/docker                      # deve existir
```

### 2. Docker data-root em /data/docker

```bash
# Verificar se ja esta configurado
docker info | grep "Docker Root Dir"
# Esperado: Docker Root Dir: /data/docker

# Se nao estiver, configurar:
sudo tee /etc/docker/daemon.json <<'EOF'
{
  "data-root": "/data/docker"
}
EOF
sudo systemctl restart docker
docker info | grep "Docker Root Dir"
```

### 3. NVIDIA Container Toolkit

`nvidia-smi` funcionando nao e suficiente — o toolkit e necessario para o Docker acessar a GPU.

```bash
# Verificar se ja esta instalado
docker info | grep nvidia
# Se o runtime nvidia nao aparecer, instalar:

curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey \
  | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list \
  | sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' \
  | sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list

sudo apt-get update && sudo apt-get install -y nvidia-container-toolkit
sudo nvidia-ctk runtime configure --runtime=docker
sudo systemctl restart docker

# Confirmar
docker info | grep nvidia            # deve listar o runtime nvidia
```

## Inicio rapido

### 1. Configurar variaveis

```bash
cd experiments/ai-lab
cp .env.example .env
# O .env.example ja tem os valores corretos para este ambiente
# Edite apenas se quiser trocar o modelo
```

### 2. Subir o stack

```bash
docker compose up -d
docker compose ps
# Aguarde ambos os servicos ficarem "healthy"
# TEI pode demorar 2-5 min no primeiro start (download do bge-m3 ~1.1 GB)
```

### 4. Baixar o modelo LLM

```bash
# TEI baixa o modelo automaticamente; Ollama precisa de pull manual
docker exec ai-lab-ollama ollama pull qwen2.5:7b
```

### 5. Validar

```bash
chmod +x scripts/validate.sh
./scripts/validate.sh
```

### Testes manuais rapidos

```bash
# Testar Ollama (LLM)
curl http://192.168.15.103:11434/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "qwen2.5:7b",
    "messages": [{"role": "user", "content": "Diga apenas: funcionou"}],
    "max_tokens": 20,
    "stream": false
  }'

# Testar TEI (embeddings)
curl http://192.168.15.103:8080/embed \
  -H "Content-Type: application/json" \
  -d '{"inputs": "texto de teste"}'
```

## Portas expostas (LAN)

| Servico | Porta | Endpoint principal |
|---|---|---|
| Ollama | `0.0.0.0:11434` | `/v1/chat/completions` |
| TEI | `0.0.0.0:8080` | `/embed` |

Acessivel pelo Cluster B via `http://192.168.15.103:11434` e `http://192.168.15.103:8080`.

## Persistencia

Modelos ficam em bind mounts no SSD dedicado (DA-019):

```bash
ls /data/models/ollama/models/   # modelos Ollama GGUF
ls /data/models/tei-cache/       # modelo HuggingFace do TEI
```

`docker compose down` preserva todos os modelos.
`docker compose down` seguido de `docker compose up -d` nao requer novo download.

## Divergencias em relacao ao experimento WSL

| Aspecto | WSL (laptop admin) | Este setup (workstation) |
|---|---|---|
| Imagem TEI | `cpu-latest` (CPU) | `cpu-latest` (CPU — workaround Blackwell) |
| Runtime TEI | nenhum (CPU) | nenhum (CPU — workaround) |
| Modelos LLM | `qwen2.5:1.5b` | `qwen2.5:7b` |
| Modelos embed | `bge-small-en-v1.5` (384d) | `bge-m3` (1024d, multilingual) |
| Volume Ollama | Docker volume gerenciado | Bind mount `/data/models/ollama` |
| Volume TEI | Docker volume gerenciado | Bind mount `/data/models/tei-cache` |
| Binding | `127.0.0.1` (localhost) | `0.0.0.0` (LAN) |
| `OLLAMA_MAX_VRAM` | 1800 MB (limitado) | nao necessario |
| Docker data-root | padrao WSL | `/data/docker` |

---

## Pegadinhas encontradas durante a configuracao

| Problema | Causa | Solucao aplicada |
|---|---|---|
| SSD de dados montado em `/mnt/data` em vez de `/data` | Auto-mount do GNOME criou entrada no fstab como `/mnt/data` com opcoes de desktop (`nosuid,nodev,x-gvfs-show`) | Atualizar `/etc/fstab`: mount point `/mnt/data` → `/data`, tipo `auto` → `ext4`, opcoes → `defaults,noatime,nofail`; remontar com `umount` + `mount /data` |
| `could not select device driver "nvidia" with capabilities: [[gpu]]` | `nvidia-container-toolkit` nao instalado — `nvidia-smi` funcionar nao implica que o Docker tem acesso a GPU | Instalar `nvidia-container-toolkit` via apt, executar `nvidia-ctk runtime configure --runtime=docker`, reiniciar Docker |
| TEI `blackwell-latest`: `libcurand.so.10: cannot open shared object file` | Bug na imagem upstream: `libcurand.so.10` ausente na imagem `ghcr.io/huggingface/text-embeddings-inference:blackwell-latest` | Fallback para `hopper-latest` (tentativa intermediaria) |
| TEI `hopper-latest`: `Runtime compute cap 120 is not compatible with compile time compute cap 90` | Kernels CUDA compilados para Hopper (sm_90) nao executam em Blackwell (sm_120) — compute caps nao sao forward-compatible | Fallback para `cpu-latest`; TEI roda em CPU — viavel para POC com 64 GB DDR5 |

---

*Setup criado como parte do projeto techlead-joe-infra.*
*Decisoes arquiteturais de referencia: DA-014, DA-015, DA-016, DA-018, DA-019.*
