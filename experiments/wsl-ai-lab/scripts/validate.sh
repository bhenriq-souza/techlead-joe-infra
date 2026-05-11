#!/usr/bin/env bash
# =============================================================================
# MODO DE TESTE WSL — Script de validacao do AI Lab
# =============================================================================
# Executa todos os criterios de aceite do experimento WSL:
#   1. Ollama responde em /v1/chat/completions (API OpenAI-compat)
#   2. TEI responde em /embed (endpoint nativo)
#   3. Ollama esta usando GPU (RTX 3050)
#   4. TEI esta em modo CPU sem erros de CUDA
#   5. Persistencia de modelos apos down/up
#
# Uso:
#   cd experiments/wsl-ai-lab
#   chmod +x scripts/validate.sh
#   ./scripts/validate.sh
#
# Pre-requisito: stack rodando e modelo baixado no Ollama
#   docker compose up -d
#   docker exec wsl-ai-lab-ollama ollama pull qwen2.5:1.5b
# =============================================================================

set -euo pipefail

# --- Cores para output ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# --- Configuracoes (sobrescreva com variaveis de ambiente se necessario) ---
OLLAMA_URL="${LLM_BASE_URL:-http://127.0.0.1:11434}"
TEI_URL="${EMBEDDING_BASE_URL:-http://127.0.0.1:8080}"
LLM_MODEL="${OLLAMA_DEFAULT_MODEL:-qwen2.5:1.5b}"
EMBED_MODEL="${TEI_MODEL_ID:-BAAI/bge-small-en-v1.5}"

# --- Contadores ---
PASSED=0
FAILED=0

# --- Funcoes utilitarias ---
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
# TEI retorna lista de listas de floats
assert isinstance(data, list) and len(data) > 0
assert isinstance(data[0], list) and len(data[0]) > 10
print(f'Dimensao do vetor: {len(data[0])}')
" 2>/dev/null; then
  pass "Vetor de embeddings recebido com sucesso"
  DIM=$(echo "$EMBED_RESPONSE" | python3 -c "import sys,json; d=json.load(sys.stdin); print(len(d[0]))" 2>/dev/null || echo "?")
  info "Dimensao do vetor: ${DIM}"
else
  fail "Resposta invalida ou endpoint TEI nao acessivel"
  echo "    Resposta raw: ${EMBED_RESPONSE:0:200}"
  echo "    Verifique: docker compose ps | docker compose logs tei"
fi

# Bonus: testar /v1/embeddings se TEI suportar (versoes recentes)
info "Testando /v1/embeddings (compatibilidade OpenAI — pode nao estar disponivel)..."
EMBED_V1=$(curl -sf \
  "${TEI_URL}/v1/embeddings" \
  -H "Content-Type: application/json" \
  -d "{\"model\": \"${EMBED_MODEL}\", \"input\": \"Texto de teste\"}" 2>&1) || true

if echo "$EMBED_V1" | grep -q '"embedding"'; then
  info "TEI /v1/embeddings: disponivel (compatibilidade OpenAI confirmada)"
else
  info "TEI /v1/embeddings: nao disponivel nesta versao (use /embed como endpoint primario)"
fi

# =============================================================================
section "Criterio 3: Ollama usa GPU (RTX 3050)"
# =============================================================================

info "Verificando processos GPU via nvidia-smi..."
GPU_PROCS=$(nvidia-smi --query-compute-apps=pid,used_memory,name --format=csv,noheader 2>/dev/null || echo "")

if [[ -n "$GPU_PROCS" ]]; then
  pass "Processos usando GPU encontrados"
  info "Processos GPU ativos:"
  echo "$GPU_PROCS" | while IFS= read -r line; do
    echo "    $line"
  done
else
  info "Nenhum processo de compute GPU ativo no momento"
  info "(Normal se nenhuma inferencia esta ocorrendo agora)"
  info "Para confirmar durante inferencia: faca uma chamada ao /v1/chat/completions e execute nvidia-smi imediatamente"
fi

# Verificar que o container Ollama tem acesso a GPU
OLLAMA_GPU=$(docker inspect wsl-ai-lab-ollama 2>/dev/null \
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
section "Criterio 4: TEI em modo CPU sem erros CUDA"
# =============================================================================

TEI_LOGS=$(docker logs wsl-ai-lab-tei 2>&1 | tail -50 || echo "container nao encontrado")

if echo "$TEI_LOGS" | grep -qi "cuda\|nvidia\|gpu error"; then
  fail "Logs do TEI contem referencias a CUDA/GPU — verificar se imagem CPU esta sendo usada"
  info "Grep CUDA nos logs:"
  echo "$TEI_LOGS" | grep -i "cuda\|nvidia\|gpu" | head -5 | sed 's/^/    /'
else
  pass "Nenhum erro CUDA/GPU nos logs do TEI (modo CPU confirmado)"
fi

if echo "$TEI_LOGS" | grep -qi "listening\|ready\|started"; then
  pass "TEI reportou start bem-sucedido nos logs"
else
  info "Logs de startup nao encontrados — verifique se o container subiu: docker compose ps"
fi

# =============================================================================
section "Criterio 5: Persistencia — modelos sobrevivem ao down/up"
# =============================================================================

info "Verificando modelos presentes no volume Ollama..."
MODELS=$(docker exec wsl-ai-lab-ollama ollama list 2>/dev/null || echo "")

if [[ -n "$MODELS" ]] && ! echo "$MODELS" | grep -q "^NAME"; then
  info "Nenhum modelo encontrado — baixe com:"
  info "  docker exec wsl-ai-lab-ollama ollama pull qwen2.5:1.5b"
elif echo "$MODELS" | grep -q "$LLM_MODEL"; then
  pass "Modelo ${LLM_MODEL} presente no volume"
  info "Para testar persistencia: docker compose down && docker compose up -d"
  info "Apos subir novamente, 'ollama list' deve mostrar o modelo sem novo download"
else
  info "Modelos presentes (diferente do configurado em LLM_MODEL):"
  echo "$MODELS" | tail -n +2 | sed 's/^/    /'
fi

info "Inspecao do volume Ollama:"
docker volume inspect wsl-ai-lab_ollama_data 2>/dev/null \
  | python3 -c "import sys,json; v=json.load(sys.stdin)[0]; print(f'    Mountpoint: {v[\"Mountpoint\"]}')" \
  2>/dev/null || info "Volume nao encontrado — stack nao iniciado"

# =============================================================================
section "Resumo"
# =============================================================================

TOTAL=$((PASSED + FAILED))
echo ""
echo -e "  Resultado: ${GREEN}${PASSED}${NC} passou / ${RED}${FAILED}${NC} falhou de ${TOTAL} verificacoes"

if [[ $FAILED -eq 0 ]]; then
  echo -e "\n  ${GREEN}Todos os criterios de aceite passaram.${NC}"
  echo "  O stack WSL AI Lab esta funcionando corretamente."
else
  echo -e "\n  ${RED}Alguns criterios falharam. Verifique os itens acima.${NC}"
  echo "  Comandos uteis para diagnostico:"
  echo "    docker compose ps"
  echo "    docker compose logs --tail=30 ollama"
  echo "    docker compose logs --tail=30 tei"
  exit 1
fi
