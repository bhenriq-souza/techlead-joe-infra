# Contexto: AI Lab — Setup oficial da workstation — VALIDADO em 2026-05-13

Stack Ollama + TEI full-GPU rodando na workstation Ubuntu 26.04 com RTX 5070 12 GB,
exposta na LAN para consumo pelo Cluster B. Artefatos em `experiments/ai-lab/`.

## Ambiente validado

- **Host:** Ubuntu 26.04 LTS nativo (workstation ai-lab, IP LAN 192.168.15.103)
- **Hardware:** Ryzen 9 7900X, 64 GB DDR5, RTX 5070 12 GB GDDR7 (Blackwell, sm_120)
- **Driver NVIDIA:** 595.58.03 | CUDA 13.2
- **Stack:** Docker Engine, nvidia-container-toolkit, Docker data-root em `/data/docker`
- **Armazenamento:** SSD NVMe 2 montado em `/data` (ext4, noatime) — bind mounts para modelos

## Stack em funcionamento

- **Ollama** rodando na GPU (RTX 5070), modelo `qwen2.5:7b`
  - Endpoint OpenAI-compat: `http://192.168.15.103:11434/v1/chat/completions`
- **TEI** rodando em CPU (workaround — sem suporte GPU para Blackwell sm_120), modelo `BAAI/bge-m3` (1024d, multilingual, pt-BR)
  - Imagem: `ghcr.io/huggingface/text-embeddings-inference:cpu-latest`
  - Endpoint nativo: `http://192.168.15.103:8080/embed`
  - Endpoint OpenAI-compat: `http://192.168.15.103:8080/v1/embeddings`
  - Latencia: ~50–800 ms/chamada (CPU) vs ~2–30 ms (GPU ideal) — qualidade dos vetores identica
  - Impacto POC: Knowledge Ingestion em batch aceitavel; RAG em tempo real irrelevante (Ollama domina a latencia)
- **Bind mounts** em `/data/models/ollama` e `/data/models/tei-cache` (DA-019)
- **Binding LAN** em `0.0.0.0` — acessivel pelo Cluster B via IP fixo

## Pegadinhas operacionais resolvidas

1. **fstab com `/mnt/data` em vez de `/data`:** O auto-mount do GNOME criou o SSD de dados
   em `/mnt/data` com opcoes de desktop (`nosuid,nodev,x-gvfs-show`). DA-019 especifica `/data`.
   Corrigido atualizando o fstab: mount point `/mnt/data` → `/data`, tipo `auto` → `ext4`,
   opcoes → `defaults,noatime,nofail`; remontado com `umount /mnt/data && mount /data`.

2. **NVIDIA Container Toolkit ausente:** `nvidia-smi` funcionava (driver 595.58.03 OK), mas
   `nvidia-container-toolkit` nao estava instalado. Docker reportou:
   `could not select device driver "nvidia" with capabilities: [[gpu]]`.
   Instalado via apt + `nvidia-ctk runtime configure --runtime=docker` + restart Docker.

3. **TEI sem suporte GPU para Blackwell (sm_120):** Duas tags tentadas e falharam:
   - `blackwell-latest`: existe, mas `libcurand.so.10` ausente na imagem (bug upstream).
   - `hopper-latest`: kernels compilados para sm_90 (Hopper), incompativel com sm_120 — `Runtime compute cap 120 is not compatible with compile time compute cap 90`.
   Solucao: fallback para `cpu-latest`. TEI roda em CPU; 64 GB DDR5 e viavel para POC.
   Ollama permanece na GPU (RTX 5070).

## Artefatos versionados

```
experiments/ai-lab/
├── docker-compose.yml      # stack full-GPU, bind mounts, binding LAN
├── .env.example
├── README.md               # com status VALIDADO, pegadinhas e divergencias do WSL
└── scripts/
    └── validate.sh         # 6 criterios automatizados
```
