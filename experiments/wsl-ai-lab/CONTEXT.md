# Contexto: Experimento WSL AI Lab — VALIDADO em 2026-04-27

Validei com sucesso a prova de design do meu AI Lab no laptop admin (WSL2 Ubuntu 24.04 sobre Windows 11). Todos os 6 criterios de aceite passaram. Os artefatos estao em `experiments/wsl-ai-lab/` no repositorio `techlead-joe-infra`.

## Ambiente validado

- **Host:** Windows 11 Pro 25H2, WSL 2.6.3.0, Ubuntu 24.04.3 LTS
- **Hardware:** i7-12650H, 40 GB RAM (20 GB WSL), RTX 3050 Laptop 4 GB VRAM
- **Stack:** Docker Engine 28.1.1 nativo no WSL (sem Docker Desktop), nvidia-container-toolkit 1.19.0
- **systemd habilitado** no WSL via `/etc/wsl.conf`

## Stack final em funcionamento

- **Ollama** rodando na GPU (RTX 3050), modelo `qwen2.5:1.5b` carregado
  - Endpoint OpenAI-compat: `http://127.0.0.1:11434/v1/chat/completions`
- **TEI** (text-embeddings-inference) em modo CPU, modelo `BAAI/bge-small-en-v1.5` (384d)
  - Imagem: `ghcr.io/huggingface/text-embeddings-inference:cpu-latest`
  - Endpoint nativo: `http://127.0.0.1:8080/embed`
  - Endpoint OpenAI-compat: `http://127.0.0.1:8080/v1/embeddings` (disponivel a partir do `cpu-latest`)
- **Docker Compose** com volumes nomeados, healthchecks, rede dedicada `wsl-ai-lab_network`
- **Estrategia hibrida GPU+CPU** (Ollama na GPU, TEI na CPU) — necessaria pela limitacao de 4 GB VRAM no laptop com display Windows consumindo ~1.7 GB

## Artefatos versionados

```
experiments/wsl-ai-lab/
├── docker-compose.yml      # marcado como modo de teste, comentado
├── .env.example
├── README.md               # com status VALIDADO, criterios e pegadinhas
└── scripts/
    └── validate.sh         # 6 criterios automatizados, todos PASS
```

## Pegadinhas operacionais resolvidas (registrar para nao repetir)

1. **Porta 11434 em uso:** Ollama nativo no WSL conflita com o container. Parar o servico nativo antes de subir o compose.

2. **TEI `relative URL without a base`:** combinacao de tres causas:
   - `HUGGING_FACE_HUB_TOKEN=""` (string vazia) faz o `hf-hub` falhar na construcao de URL → solucao: nao passar a env var quando vazia
   - Volume `tei_cache` com estado parcial corrompido da tentativa anterior → solucao: `docker volume rm wsl-ai-lab_tei_cache`
   - Imagem `cpu-1.5.0` tem bug nesse cenario → solucao: usar `cpu-latest`
   - Tambem fixei `HF_ENDPOINT=https://huggingface.co` explicitamente como reforco

3. **`validate.sh` saindo silenciosamente apos primeiro `[PASS]`:** classico bash gotcha — `set -euo pipefail` + `((PASSED++))` com valor 0 faz pos-incremento retornar exit code 1. Fix: pre-incremento `((++PASSED))`.

## Divergencias documentadas para a workstation oficial

Tabela completa no README do experimento. Principais pontos para a migracao para a workstation Ubuntu 26.04 + RTX 5070 12 GB:

- TEI passa para imagem GPU
- Modelos crescem (qwen2.5:7b, nomic-embed/bge-m3)
- Volumes viram bind mounts em `/data` (SSD dedicado, DA-019)
- Binding muda de `127.0.0.1` para IP da LAN
- Docker `data-root` aponta para `/data/docker`
- Remover `OLLAMA_MAX_VRAM` (12 GB sem aperto)

## Proximo passo solicitado

[Descrever aqui o que deseja fazer a seguir — ex.: "criar o setup oficial em `environments/workstation/` aplicando as divergencias", "montar o stack do Cluster B (Incident Analyzer)", "documentar a DA-020 sobre k3s", etc.]
