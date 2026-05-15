# Relatório — Observabilidade do Ollama no AI Lab com Grafana Alloy + Loki

> Data: 2026-05-14  
> Ambiente: AI Lab workstation + Homelab K3s  
> Status: experimento validado com sucesso  
> Escopo: coleta de logs do container `ai-lab-ollama` via Grafana Alloy em Docker Compose e visualização no Grafana/Loki do homelab.

---

## 1. Contexto

O ambiente atual possui dois blocos principais:

| Componente | Papel | Endereço / Execução |
|---|---|---|
| `homelab-server` / K3s | Stack central de observabilidade | `192.168.15.97` |
| `ai-lab workstation` | Execução local do Ollama em GPU | `192.168.15.103` |
| Ollama | Servidor LLM consumido pelos serviços do homelab | Docker Compose, porta `11434` |
| Grafana | Visualização dos sinais de observabilidade | `grafana.homelab.local` |
| Loki | Armazenamento e consulta de logs | `loki.homelab.local` |
| Grafana Alloy | Coleta e encaminhamento de logs | Container no `ai-lab` |

O objetivo do experimento foi validar se seria possível observar o servidor Ollama, que roda fora do cluster K3s, usando a stack de observabilidade já existente no homelab.

---

## 2. Decisão principal

A decisão tomada foi **não mover o Ollama para o K3s neste momento**.

O Ollama continua rodando no `ai-lab workstation` via Docker Compose, usando a GPU local. A observabilidade passa a ser integrada à stack central do homelab por meio de um container adicional do Grafana Alloy no mesmo Compose.

### Decisão

```text
Manter Ollama em Docker Compose no AI Lab
+
Adicionar Grafana Alloy como container no mesmo Compose
+
Enviar logs do container Ollama para o Loki do homelab
+
Visualizar os dados no Grafana já existente
```

### Justificativa

Essa decisão reduz complexidade porque:

- não exige instalar K3s no AI Lab agora;
- aproveita o Loki/Grafana já existentes no homelab;
- mantém o Ollama próximo da GPU local da workstation;
- cria um primeiro fluxo real de observabilidade cross-host;
- permite evoluir depois para métricas de GPU, host e LLM sem refazer a arquitetura.

---

## 3. Arquitetura validada

```text
ai-lab workstation - 192.168.15.103
│
├─ Docker Compose
│  │
│  ├─ ai-lab-ollama
│  │   └─ logs stdout/stderr via Docker json-file
│  │
│  └─ ai-lab-alloy
│      ├─ lê Docker socket
│      ├─ descobre o container ai-lab-ollama
│      ├─ aplica labels
│      └─ envia logs para o Loki
│
└──────────────────────────────────────────────► homelab-server - 192.168.15.97
                                                │
                                                ├─ Loki
                                                └─ Grafana
```

Fluxo de dados:

```text
Ollama container logs
  ↓
Docker daemon / json-file logging
  ↓
Grafana Alloy no AI Lab
  ↓
Loki no Homelab
  ↓
Grafana Dashboard
```

---

## 4. Alterações no Docker Compose

Foi adicionada uma nova service ao Compose:

```yaml
alloy:
  image: grafana/alloy:latest
  container_name: ai-lab-alloy
  restart: unless-stopped

  depends_on:
    - ollama

  command:
    - run
    - --server.http.listen-addr=0.0.0.0:12345
    - --storage.path=/var/lib/alloy/data
    - /etc/alloy/config.alloy

  ports:
    - "127.0.0.1:12345:12345"

  volumes:
    - ./alloy/config.alloy:/etc/alloy/config.alloy:ro
    - alloy-data:/var/lib/alloy/data
    - /var/run/docker.sock:/var/run/docker.sock:ro

  environment:
    - LOKI_PUSH_URL=${LOKI_PUSH_URL:-http://loki.homelab.local/loki/api/v1/push}

  extra_hosts:
    - "loki.homelab.local:${HOMELAB_IP:-192.168.15.97}"

  networks:
    - ai-lab-net
```

Também foi adicionado o volume:

```yaml
volumes:
  alloy-data:
    name: ai-lab_alloy_data
```

---

## 5. Configuração do Alloy

Foi criado o arquivo:

```text
alloy/config.alloy
```

Objetivo do arquivo:

- conectar no Docker socket;
- descobrir containers em execução;
- filtrar apenas o container `ai-lab-ollama`;
- adicionar labels úteis para consulta no Loki;
- enviar logs para o Loki do homelab.

Configuração base:

```hcl
logging {
  level  = "info"
  format = "logfmt"
}

discovery.docker "containers" {
  host             = "unix:///var/run/docker.sock"
  refresh_interval = "10s"
}

discovery.relabel "ollama" {
  targets = discovery.docker.containers.targets

  rule {
    source_labels = ["__meta_docker_container_name"]
    regex         = "/ai-lab-ollama"
    action        = "keep"
  }

  rule {
    target_label = "job"
    replacement  = "ai-lab/ollama"
  }

  rule {
    target_label = "host"
    replacement  = "ai-lab"
  }

  rule {
    target_label = "service"
    replacement  = "ollama"
  }

  rule {
    target_label = "runtime"
    replacement  = "docker-compose"
  }

  rule {
    target_label = "env"
    replacement  = "lab"
  }

  rule {
    source_labels = ["__meta_docker_container_name"]
    regex         = "/(.*)"
    target_label  = "container"
  }

  rule {
    source_labels = ["__meta_docker_container_log_stream"]
    target_label  = "stream"
  }
}

loki.source.docker "ollama" {
  host             = "unix:///var/run/docker.sock"
  targets          = discovery.relabel.ollama.output
  refresh_interval = "10s"
  forward_to       = [loki.write.homelab.receiver]
}

loki.write "homelab" {
  endpoint {
    url = env("LOKI_PUSH_URL")
  }
}
```

---

## 6. Decisões técnicas tomadas

| Decisão | Resultado esperado |
|---|---|
| Rodar Alloy como container no mesmo Compose do Ollama | Reduz setup operacional e facilita testes locais |
| Montar `/var/run/docker.sock` como read-only | Permite descoberta e leitura dos logs de containers Docker |
| Filtrar explicitamente o container `ai-lab-ollama` | Evita envio desnecessário de logs de outros containers |
| Enviar logs para `loki.homelab.local` | Centraliza logs na stack já existente |
| Fixar labels `host`, `service`, `runtime` e `env` | Facilita queries e dashboards no Grafana |
| Expor UI do Alloy apenas em `127.0.0.1:12345` | Reduz exposição desnecessária na LAN |
| Manter Docker logging driver `json-file` | Compatível com a leitura do Alloy via Docker |

---

## 7. Experimento realizado

### 7.1 Subida do stack

O Compose foi atualizado para subir:

```text
ai-lab-ollama
ai-lab-alloy
```

Validações esperadas:

```bash
docker compose up -d
docker ps
docker logs -f ai-lab-alloy
docker logs ai-lab-ollama --tail=50
```

### 7.2 Geração de logs

Foram feitas chamadas ao Ollama, incluindo requests HTTP para a API.

Exemplo de endpoint utilizado para validação:

```bash
curl http://localhost:11434/api/tags
```

ou, a partir do homelab:

```bash
curl http://192.168.15.103:11434/api/tags
```

### 7.3 Consulta no Grafana

No Grafana, usando datasource Loki, foi possível consultar os logs com labels semelhantes a:

```logql
{host="ai-lab", service="ollama"}
```

Também foi possível filtrar eventos contendo `POST`:

```logql
{host="ai-lab", service="ollama"} |= "POST"
```

---

## 8. Resultado alcançado

O experimento foi **bem-sucedido**.

Foi possível:

- subir o Alloy como container junto do Ollama;
- coletar logs do container `ai-lab-ollama`;
- enviar os logs para o Loki do homelab;
- consultar os logs no Grafana;
- criar um primeiro dashboard de observabilidade do Ollama;
- criar um painel de **requests POST por minuto**.

Evidência visual:

```text
Dashboard: Ollama Server - AiLab
Painel: Requests por Minuto
Fonte: Loki
Métrica inicial: volume de logs contendo POST ao longo do tempo
```

O dashboard exibiu uma série temporal com eventos capturados entre aproximadamente `16:23` e `16:31`, confirmando que o fluxo `Ollama → Alloy → Loki → Grafana` está operacional.

---

## 9. Query inicial para requests

A query inicial usada conceitualmente foi baseada em contagem/rate de logs contendo `POST`.

Exemplo:

```logql
sum(
  rate({host="ai-lab", service="ollama"} |= "POST" [5m])
)
```

### Observação importante

A função `rate()` no Loki retorna uma taxa por segundo. Portanto, se o painel se chama **Requests por Minuto**, uma forma mais fiel é multiplicar por `60`:

```logql
sum(
  rate({host="ai-lab", service="ollama"} |= "POST" [5m])
) * 60
```

Outra alternativa, mais direta para contagem por janela móvel de 1 minuto:

```logql
sum(
  count_over_time({host="ai-lab", service="ollama"} |= "POST" [1m])
)
```

### Recomendação

Para um painel chamado **Requests por Minuto**, usar uma destas opções:

```logql
sum(rate({host="ai-lab", service="ollama"} |= "POST" [5m])) * 60
```

ou:

```logql
sum(count_over_time({host="ai-lab", service="ollama"} |= "POST" [1m]))
```

A primeira é melhor para tendência suavizada.  
A segunda é melhor para uma leitura mais literal de contagem por minuto.

---

## 10. Métricas que já são possíveis somente com logs

Com esse MVP, já é possível criar painéis como:

| Painel | Query base |
|---|---|
| Requests POST por minuto | `POST` nos logs |
| Erros por minuto | `error`, `failed`, `timeout`, `panic`, `500`, `503` |
| Últimos erros do Ollama | filtro textual de erro |
| Volume total de logs | `count_over_time` |
| Logs por stream | label `stream="stdout"` ou `stream="stderr"` |
| Requests por endpoint | filtros por `/api/chat`, `/api/generate`, `/v1/chat/completions` |

Exemplos:

```logql
sum(rate({host="ai-lab", service="ollama"} |~ "error|ERROR|failed|timeout|panic" [5m])) * 60
```

```logql
{host="ai-lab", service="ollama"} |~ "/api/chat|/api/generate|/v1/chat/completions"
```

```logql
{host="ai-lab", service="ollama", stream="stderr"}
```

---

## 11. Limitações conhecidas do MVP

Este experimento valida observabilidade por logs, mas ainda não entrega observabilidade completa de LLM.

### Ainda não é possível medir bem somente com logs padrão

| Métrica | Status |
|---|---|
| tokens de entrada | Não confiável somente por log padrão |
| tokens de saída | Não confiável somente por log padrão |
| tokens por segundo | Não disponível diretamente |
| latência p95/p99 confiável | Depende do formato dos logs |
| uso de GPU | Não vem dos logs do Ollama |
| VRAM utilizada | Não vem dos logs do Ollama |
| temperatura da GPU | Não vem dos logs do Ollama |
| CPU/RAM do container | Melhor via métricas Prometheus/cAdvisor/Alloy metrics |

---

## 12. Interpretação técnica

O experimento demonstrou que a stack atual já suporta observabilidade cross-host:

```text
K3s no homelab
+
Docker Compose no ai-lab
+
Loki centralizado
+
Grafana centralizado
```

Isso é importante porque o projeto Tech Lead Joe depende de um desenho onde serviços do homelab consomem inferência LLM no AI Lab. A validação mostra que o Ollama pode permanecer fora do cluster, sem perder visibilidade operacional básica.

---

## 13. Próximas evoluções recomendadas

### P1 — Melhorar dashboard atual

Adicionar painéis:

```text
- Requests POST/min
- Erros/min
- Últimos erros
- Logs recentes do Ollama
- Requests por endpoint
- Logs por stream stdout/stderr
```

### P1 — Ajustar a métrica de requests por minuto

Validar se o painel atual usa `rate()` puro. Se sim, ajustar para:

```logql
sum(rate({host="ai-lab", service="ollama"} |= "POST" [5m])) * 60
```

ou:

```logql
sum(count_over_time({host="ai-lab", service="ollama"} |= "POST" [1m]))
```

### P2 — Adicionar métricas do host AI Lab

Adicionar:

```text
node_exporter
cAdvisor ou Alloy metrics
```

Objetivo:

```text
CPU
RAM
disco /data
rede
containers
restarts
```

### P2 — Adicionar métricas de GPU

Adicionar:

```text
NVIDIA DCGM Exporter
```

Objetivo:

```text
GPU utilization
VRAM usada
temperatura
power draw
SM occupancy
```

### P3 — Criar ollama-gateway

Criar um gateway entre os serviços do homelab e o Ollama:

```text
Incident Analyzer / Knowledge Injector
  ↓
ollama-gateway
  ↓
Ollama no AI Lab
```

Esse gateway poderia expor métricas Prometheus reais:

```text
ollama_requests_total
ollama_request_duration_seconds
ollama_prompt_tokens_total
ollama_completion_tokens_total
ollama_tokens_per_second
ollama_errors_total
```

Além disso, ele poderia centralizar autenticação, rate limit e auditoria.

---

## 14. Status final do experimento

| Item | Status |
|---|---|
| Ollama rodando em Docker Compose | Concluído |
| Alloy rodando como container no AI Lab | Concluído |
| Alloy lendo Docker socket | Concluído |
| Logs do Ollama chegando no Loki | Concluído |
| Logs visíveis no Grafana | Concluído |
| Primeiro dashboard criado | Concluído |
| Painel de requests `POST` criado | Concluído |
| Métricas de GPU | Pendente |
| Métricas de host | Pendente |
| Métricas reais de tokens/latência por modelo | Pendente |

---

## 15. Conclusão

O experimento validou com sucesso o primeiro nível de observabilidade do Ollama no AI Lab.

A decisão de adicionar o Grafana Alloy como container no mesmo Docker Compose foi adequada para o momento atual porque entregou valor rápido, manteve o Ollama fora do K3s e reaproveitou a stack Grafana/Loki já existente no homelab.

O resultado prático é que o AI Lab agora produz logs observáveis centralmente no Grafana, permitindo criar dashboards operacionais para o Ollama.

A próxima etapa natural é evoluir de observabilidade baseada em logs para observabilidade baseada também em métricas, começando por host/GPU e, depois, por métricas específicas de LLM via um gateway ou exporter dedicado.
