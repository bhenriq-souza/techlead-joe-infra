# AI Lab WSL — Experimento de validacao do design

> **MODO DE TESTE WSL — Este experimento NAO e o setup oficial da workstation.**
> Serve como prova de design para o Cluster A (AI Lab) descrito nas decisoes
> arquiteturais DA-018 e DA-019 do projeto `techlead-joe-infra`.

## Status: VALIDADO

**Data:** 2026-04-27
**Resultado:** 6/6 criterios de aceite passaram.

| Criterio | Status |
|---|---|
| Ollama `/v1/chat/completions` (API OpenAI-compat) | PASS |
| TEI `/embed` retorna vetor 384d | PASS |
| TEI `/v1/embeddings` (compat OpenAI) disponivel | PASS |
| Container Ollama com runtime NVIDIA configurado | PASS |
| TEI em modo CPU sem erros CUDA | PASS |
| Modelos persistem apos `down/up` | PASS |

**Pegadinhas encontradas e resolvidas — ver secao abaixo.**

## Objetivo

Validar a stack Ollama + TEI + Docker Compose com API OpenAI-compatible
em ambiente WSL2, antes de promover o setup para a workstation final
(Ubuntu 26.04 LTS, RTX 5070 12 GB).

## Hardware de referencia (laptop admin)

| Componente | Valor |
|---|---|
| CPU | Intel Core i7-12650H |
| RAM WSL | 20 GB (de 40 GB total) |
| GPU | NVIDIA RTX 3050 Laptop GPU, 4 GB VRAM |
| Driver Windows | 572.83 |
| CUDA | 12.8 |
| WSL | 2.6.3.0, Ubuntu 24.04.3 LTS |

## Estrategia GPU/CPU

| Servico | Runtime | Justificativa |
|---|---|---|
| Ollama | **GPU** (RTX 3050) | Inferencia LLM se beneficia da GPU |
| TEI | **CPU** | VRAM limitada no laptop (~2.1 GB livres); embedding em CPU e suficiente para validacao |

> Na workstation oficial (RTX 5070, 12 GB VRAM), ambos rodarao em GPU.
> Veja tabela de divergencias no final deste README.

## Modelos recomendados para este teste

| Servico | Modelo primario | Alternativa |
|---|---|---|
| Ollama (LLM) | `qwen2.5:1.5b` | `llama3.2:1b` |
| TEI (embeddings) | `BAAI/bge-small-en-v1.5` | `sentence-transformers/all-MiniLM-L6-v2` |

## Estrutura de arquivos

```
experiments/wsl-ai-lab/
├── docker-compose.yml      # Stack principal (marcado como modo de teste)
├── .env.example            # Variaveis necessarias — copiar para .env
├── README.md               # Este arquivo
└── scripts/
    └── validate.sh         # Script de criterios de aceite
```

## Inicio rapido

### 1. Pre-requisitos

```bash
# Verificar que o stack WSL esta OK
wsl --version             # no PowerShell do Windows — deve ser WSL 2.x
docker --version          # Docker 28+
nvidia-smi                # RTX 3050 deve aparecer
docker info | grep nvidia # runtime nvidia deve estar listado
```

### 2. Configurar variaveis

```bash
cd experiments/wsl-ai-lab
cp .env.example .env
# O .env.example ja tem os valores corretos para este ambiente
# Edite apenas se quiser trocar o modelo
```

### 3. Subir o stack

```bash
docker compose up -d
docker compose ps
# Aguarde ambos os servicos ficarem "healthy"
# TEI pode demorar 1-3 min no primeiro start (download do modelo ~90MB)
```

### 4. Baixar o modelo LLM

```bash
# O TEI baixa o modelo automaticamente; o Ollama precisa de pull manual
docker exec wsl-ai-lab-ollama ollama pull qwen2.5:1.5b
```

### 5. Validar

```bash
./scripts/validate.sh
```

### Testes manuais rapidos

```bash
# Testar Ollama (LLM)
curl http://127.0.0.1:11434/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "qwen2.5:1.5b",
    "messages": [{"role": "user", "content": "Diga apenas: funcionou"}],
    "max_tokens": 20,
    "stream": false
  }'

# Testar TEI (embeddings)
curl http://127.0.0.1:8080/embed \
  -H "Content-Type: application/json" \
  -d '{"inputs": "texto de teste"}'
```

## Persistencia de modelos

Os modelos ficam em volumes Docker gerenciados dentro do filesystem WSL:

```bash
docker volume inspect wsl-ai-lab_ollama_data  # modelos Ollama
docker volume inspect wsl-ai-lab_tei_cache    # cache HuggingFace TEI
```

`docker compose down` preserva os volumes. `docker compose down -v` apaga tudo.

## Portas expostas (somente localhost)

| Servico | Porta | Endpoint principal |
|---|---|---|
| Ollama | 127.0.0.1:11434 | `/v1/chat/completions` |
| TEI | 127.0.0.1:8080 | `/embed` |

## Acesso do Windows host

O WSL2 no Windows 11 faz forward automatico de portas para o host.
Abra o Postman ou browser no Windows e acesse `http://localhost:11434`
e `http://localhost:8080` — funcionara sem configuracao adicional.

> **Como funciona:** O kernel WSL2 expoe as portas via NAT para o adaptador
> virtual `WSL` no Windows. O Windows 11 habilita `localhostForwarding` por
> padrao. Se nao funcionar, adicione `localhostForwarding=true` no `.wslconfig`.

## Divergencias em relacao ao setup oficial da workstation

| Aspecto | Este teste WSL | Workstation oficial |
|---|---|---|
| Imagem TEI | `cpu-latest` (CPU) | Imagem GPU compativel com RTX 5070 |
| Modelos LLM | `qwen2.5:1.5b` (1.5B) | `qwen2.5:7b` ou `llama3.1:8b` (7-14B) |
| Modelos embed | `bge-small-en-v1.5` (384d) | `nomic-embed-text-v1.5` ou `bge-m3` |
| Volume Ollama | Volume Docker gerenciado | Bind mount em `/data/ollama` (SSD dedicado) |
| Volume TEI | Volume Docker gerenciado | Bind mount em `/data/tei-cache` |
| Binding | `127.0.0.1` (localhost only) | IP LAN para consumo do Cluster B |
| Runtime Ollama | `nvidia` (GPU) | `nvidia` (GPU) — igual |
| Runtime TEI | nenhum (CPU) | `nvidia` (GPU) — **diferente** |
| `data-root` Docker | padrao WSL | `/data/docker` (SSD dedicado) |
| `OLLAMA_MAX_VRAM` | 1800 MB (limitado) | nao necessario (12 GB disponivel) |

---

## Pegadinhas encontradas durante a validacao

| Problema | Causa | Solucao aplicada |
|---|---|---|
| `address already in use` na porta 11434 | Ollama nativo rodando fora do Docker no WSL | Parar o processo Ollama nativo antes de subir o compose |
| TEI falha com `relative URL without a base` | `HUGGING_FACE_HUB_TOKEN=""` (string vazia) causa falha de URL no `hf-hub` + volume com estado corrompido da tentativa anterior | Remover a env var quando vazia; apagar volume com `docker volume rm wsl-ai-lab_tei_cache`; usar `cpu-latest` (versao `cpu-1.5.0` tem bug nesse cenario) |
| `validate.sh` encerra apos primeiro `[PASS]` | `set -euo pipefail` + `((PASSED++))` com valor 0 faz pós-incremento retornar exit code 1 | Trocar para pré-incremento `((++PASSED))` e `((++FAILED))` |

---

*Experimento criado como parte do projeto techlead-joe-infra.*
*Decisoes arquiteturais de referencia: DA-018, DA-019.*
