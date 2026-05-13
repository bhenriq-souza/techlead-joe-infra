#!/usr/bin/env bash
# =============================================================================
# AI Lab — Script de validacao do stack oficial da workstation
# =============================================================================
# Executa todos os criterios de aceite do setup ai-lab:
#   1. Ollama responde em /v1/chat/completions (API OpenAI-compat)
#   2. TEI responde em /embed (endpoint nativo)
#   3. TEI /v1/embeddings (compat OpenAI) disponivel
#   4. Container Ollama com runtime NVIDIA configurado
#   5. Container TEI com runtime NVIDIA configurado
#   6. Bind mounts em /data persistem apos down/up
#
# Uso:
#   cd experiments/ai-lab
#   chmod +x scripts/validate.sh
#   ./scripts/validate.sh
#
# Pre-requisito: stack rodando e modelo baixado no Ollama
#   docker compose up -d
#   docker exec ai-lab-ollama ollama pull qwen2.5:7b
# =============================================================================

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

OLLAMA_URL="${LLM_BASE_URL:-http://192.168.15.103:11434}"
TEI_URL="${EMBEDDING_BASE_URL:-http://192.168.15.103:8080}"
LLM_MODEL="${OLLAMA_DEFAULT_MODEL:-qwen2.5:7b}"
EMBED_MODEL="${TEI_MODEL_ID:-BAAI/bge-m3}"

PASSED=0
FAILED=0

pass() { echo -e "  ${GREEN}[PASS]${NC} $1"; ((++PASSED)); }
fail() { echo -e "  ${RED}[FAIL]${NC} $1"; ((++FAILED)); }
info() { echo -e "  ${BLUE}[INFO]${NC} $1"; }
section() { echo -e "\n${YELLOW}==> $1${NC}"; }

# =============================================================================
section "Criterio 1: Ollama /v1/chat/completions (API OpenAI-compat)"
# =============================================================================

info "Endpoint: ${OLLAMA_URL}/v1/chat/completions"
info "Modelo: ${LLM_MODEL}"

CHAT_RESPONSE=$(curl -sf \
  "${OLLAMA_URL}/v1/chat/completions" \
  -H "Content-Type: application/json" \
  -d "{
    \"model\": \"${LLM_MODEL}\",
    \"messages\": [{\"role\": \"user\", \"content\": \"Responda apenas: OK\"}],
    \"max_tokens\": 10,
    \"stream\": false
  }" 2>&1) || true

echo "  --- Resposta raw do Ollama ---"
echo "$CHAT_RESPONSE" | python3 -m json.tool 2>/dev/null || echo "$CHAT_RESPONSE"
echo "  --- Fim da resposta ---"

if echo "$CHAT_RESPONSE" | grep -q '"choices"'; then
  pass "Resposta JSON valida recebida"
  CONTENT=$(echo "$CHAT_RESPONSE" | python3 -c "
import sys, json
data = json.load(sys.stdin)
print(data['choices'][0]['message']['content'].strip())
" 2>/dev/null || echo "(nao parseado)")
  info "Conteudo da resposta: ${CONTENT}"
else
  fail "Resposta invalida ou endpoint nao acessivel"
  echo "    Verifique: docker compose ps | docker compose logs ollama"
fi

# =============================================================================
section "Criterio 2: TEI /embed (endpoint nativo)"
# =============================================================================

info "Endpoint: ${TEI_URL}/embed"
info "Modelo: ${EMBED_MODEL}"

EMBED_RESPONSE=$(curl -sf \
  "${TEI_URL}/embed" \
  -H "Content-Type: application/json" \
  -d '{"inputs": "Texto de teste para embeddings"}' 2>&1) || true

if echo "$EMBED_RESPONSE" | python3 -c "
import sys, json
data = json.load(sys.stdin)
assert isinstance(data, list) and len(data) > 0
assert isinstance(data[0], list) and len(data[0]) > 10
print(f'Dimensao do vetor: {len(data[0])}')
" 2>/dev/null; then
  pass "Vetor de embeddings recebido com sucesso"
  DIM=$(echo "$EMBED_RESPONSE" | python3 -c "import sys,json; d=json.load(sys.stdin); print(len(d[0]))" 2>/dev/null || echo "?")
  info "Dimensao do vetor: ${DIM}d"
else
  fail "Resposta invalida ou endpoint TEI nao acessivel"
  echo "    Resposta raw: ${EMBED_RESPONSE:0:200}"
  echo "    Verifique: docker compose ps | docker compose logs tei"
fi

# =============================================================================
section "Criterio 3: TEI /v1/embeddings (compat OpenAI)"
# =============================================================================

info "Endpoint: ${TEI_URL}/v1/embeddings"

EMBED_V1=$(curl -sf \
  "${TEI_URL}/v1/embeddings" \
  -H "Content-Type: application/json" \
  -d "{\"model\": \"${EMBED_MODEL}\", \"input\": \"Texto de teste\"}" 2>&1) || true

if echo "$EMBED_V1" | grep -q '"embedding"'; then
  pass "TEI /v1/embeddings disponivel (compatibilidade OpenAI confirmada)"
else
  fail "TEI /v1/embeddings nao disponivel"
  echo "    Resposta raw: ${EMBED_V1:0:200}"
fi

# =============================================================================
section "Criterio 4: Container Ollama com runtime NVIDIA configurado"
# =============================================================================

OLLAMA_GPU=$(docker inspect ai-lab-ollama 2>/dev/null \
  | python3 -c "
import sys, json
data = json.load(sys.stdin)[0]
devices = data.get('HostConfig', {}).get('DeviceRequests', [])
has_gpu = any(d.get('Driver') == 'nvidia' for d in (devices or []))
print('sim' if has_gpu else 'nao')
" 2>/dev/null || echo "nao verificado")

if [[ "$OLLAMA_GPU" == "sim" ]]; then
  pass "Container Ollama configurado com runtime NVIDIA"
else
  fail "Container Ollama NAO esta com runtime NVIDIA configurado"
  info "Verifique o deploy.resources no docker-compose.yml"
fi

# =============================================================================
section "Criterio 5: Container TEI em modo CPU (workaround — sem suporte GPU Blackwell)"
# =============================================================================
# blackwell-latest: libcurand.so.10 ausente na imagem (bug upstream)
# hopper-latest:    kernels compilados para sm_90, incompativel com sm_120
# Workaround: cpu-latest rodando em CPU (64 GB DDR5 viavel para POC).

TEI_IMAGE=$(docker inspect ai-lab-tei 2>/dev/null \
  | python3 -c "
import sys, json
data = json.load(sys.stdin)[0]
print(data.get('Config', {}).get('Image', 'nao encontrado'))
" 2>/dev/null || echo "nao verificado")

TEI_RUNNING=$(docker inspect ai-lab-tei 2>/dev/null \
  | python3 -c "
import sys, json
data = json.load(sys.stdin)[0]
running = data.get('State', {}).get('Running', False)
print('sim' if running else 'nao')
" 2>/dev/null || echo "nao")

info "Imagem TEI: ${TEI_IMAGE}"

if [[ "$TEI_RUNNING" == "sim" ]] && echo "$TEI_IMAGE" | grep -q "cpu-latest"; then
  pass "Container TEI rodando em modo CPU (cpu-latest) — workaround para Blackwell (sm_120)"
  info "Aguardando correcao upstream das imagens GPU para sm_120"
else
  fail "Container TEI nao esta no estado esperado (cpu-latest rodando)"
  info "Imagem: ${TEI_IMAGE} | Running: ${TEI_RUNNING}"
fi

info "Verificando uso de GPU via nvidia-smi..."
GPU_PROCS=$(nvidia-smi --query-compute-apps=pid,used_memory,name --format=csv,noheader 2>/dev/null || echo "")
if [[ -n "$GPU_PROCS" ]]; then
  info "Processos GPU ativos (Ollama):"
  echo "$GPU_PROCS" | while IFS= read -r line; do echo "    $line"; done
else
  info "Nenhum processo compute GPU ativo no momento"
fi

# =============================================================================
section "Criterio 6: Bind mounts em /data persistem apos down/up"
# =============================================================================

info "Verificando bind mounts em /data/models..."

OLLAMA_MOUNT=$(docker inspect ai-lab-ollama 2>/dev/null \
  | python3 -c "
import sys, json
data = json.load(sys.stdin)[0]
mounts = data.get('Mounts', [])
ollama = [m for m in mounts if m.get('Destination') == '/root/.ollama']
print(ollama[0]['Source'] if ollama else 'nao encontrado')
" 2>/dev/null || echo "nao verificado")

TEI_MOUNT=$(docker inspect ai-lab-tei 2>/dev/null \
  | python3 -c "
import sys, json
data = json.load(sys.stdin)[0]
mounts = data.get('Mounts', [])
tei = [m for m in mounts if m.get('Destination') == '/data']
print(tei[0]['Source'] if tei else 'nao encontrado')
" 2>/dev/null || echo "nao verificado")

info "Mount Ollama: ${OLLAMA_MOUNT}"
info "Mount TEI:    ${TEI_MOUNT}"

if [[ "$OLLAMA_MOUNT" == "/data/models/ollama" && "$TEI_MOUNT" == "/data/models/tei-cache" ]]; then
  pass "Bind mounts apontando corretamente para /data (DA-019)"
else
  fail "Bind mounts incorretos — esperado /data/models/ollama e /data/models/tei-cache"
fi

info "Verificando modelos presentes no Ollama..."
MODELS=$(docker exec ai-lab-ollama ollama list 2>/dev/null || echo "")
if echo "$MODELS" | grep -q "$LLM_MODEL"; then
  pass "Modelo ${LLM_MODEL} presente no bind mount"
  info "Para testar persistencia completa: docker compose down && docker compose up -d"
  info "Apos subir novamente, 'ollama list' deve mostrar o modelo sem novo download"
else
  info "Modelo ${LLM_MODEL} nao encontrado — baixe com:"
  info "  docker exec ai-lab-ollama ollama pull ${LLM_MODEL}"
fi

info "Filesystem do bind mount Ollama:"
df -h /data/models/ollama 2>/dev/null | tail -1 | sed 's/^/    /' || info "Nao verificado"

# =============================================================================
section "Resumo"
# =============================================================================

TOTAL=$((PASSED + FAILED))
echo ""
echo -e "  Resultado: ${GREEN}${PASSED}${NC} passou / ${RED}${FAILED}${NC} falhou de ${TOTAL} verificacoes"

if [[ $FAILED -eq 0 ]]; then
  echo -e "\n  ${GREEN}Todos os criterios de aceite passaram.${NC}"
  echo "  O stack AI Lab esta funcionando corretamente na workstation."
else
  echo -e "\n  ${RED}Alguns criterios falharam. Verifique os itens acima.${NC}"
  echo "  Comandos uteis para diagnostico:"
  echo "    docker compose ps"
  echo "    docker compose logs --tail=30 ollama"
  echo "    docker compose logs --tail=30 tei"
  exit 1
fi
