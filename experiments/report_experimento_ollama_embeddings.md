# Report do Experimento — Ollama como Servidor de LLM e Embeddings

## 1. Contexto

Este relatório consolida o experimento realizado com o uso do **Ollama Server via Docker** em uma máquina local de alto desempenho, utilizando o **Open WebUI** como interface principal para interação com modelos generativos.

O objetivo inicial foi avaliar uma arquitetura local para uso de modelos LLM e embeddings, considerando cenários futuros de **RAG**, análise de documentação técnica, troubleshooting, arquitetura de software, DevOps, Kubernetes, Terraform, código e bases de conhecimento locais.

## 2. Setup utilizado

O experimento foi realizado no seguinte ambiente:

| Componente | Especificação |
|---|---|
| CPU | AMD Ryzen 9 7900X, 12 cores / 24 threads |
| GPU | Asus NVIDIA GeForce RTX 5070, 12 GB VRAM |
| Memória RAM | 64 GB DDR5 |
| Armazenamento | 2x SSD NVMe Adata Legend 860 1 TB |
| Sistema operacional | Ubuntu |
| Runtime | Docker |
| LLM Server | Ollama |
| Interface | Open WebUI |

O ponto mais relevante para a escolha dos modelos foi a **GPU com 12 GB de VRAM**, que favorece modelos quantizados na faixa de 7B, 8B, 12B e 14B.

---

## 3. Objetivos do experimento

Os principais objetivos foram:

1. Validar o uso do **Ollama Server** como backend local para modelos generativos.
2. Avaliar o uso do **Open WebUI** como interface de chat para interação com os modelos.
3. Testar o uso de modelos de embedding para cenários de RAG.
4. Comparar a necessidade de usar um serviço separado de embeddings, como **TEI — Text Embeddings Inference**, contra o uso do próprio Ollama.
5. Definir um conjunto inicial de modelos para uso local.
6. Identificar possíveis caminhos futuros para evolução da stack local de IA.

---

## 4. Experimento realizado

### 4.1 Uso do Ollama como servidor de modelos

O Ollama foi utilizado como servidor local para disponibilizar modelos via API.

A interação inicial com o modelo generativo foi feita por meio do **Open WebUI**, que se conectou ao Ollama e permitiu testar modelos de chat de forma visual, sem necessidade de chamadas manuais via `curl`.

O modelo generativo principal testado foi:

```text
qwen2.5-coder:14b-instruct-q4_K_M
```

Esse modelo foi indicado como uma boa opção para o perfil de uso esperado, especialmente por envolver:

- Desenvolvimento de software;
- Análise de código;
- Terraform;
- Kubernetes;
- Docker;
- Python;
- Node.js / TypeScript;
- DevOps;
- Arquitetura de software;
- Troubleshooting técnico.

### 4.2 Teste com embeddings

Para embeddings, foi avaliado o uso do modelo:

```text
bge-m3
```

A ideia foi utilizar o Ollama também como servidor de embeddings, usando chamadas para o endpoint de embeddings em vez de manter uma stack separada apenas para esse fim.

O fluxo esperado para RAG é:

```text
Documento / texto
  ↓
Quebra em chunks
  ↓
Geração de embeddings com bge-m3 via Ollama
  ↓
Persistência em um vector database
  ↓
Busca semântica dos trechos relevantes
  ↓
Envio dos trechos recuperados para o modelo generativo
  ↓
Resposta final gerada pelo modelo de chat
```

### 4.3 Integração com Open WebUI

O Open WebUI foi utilizado para interagir com o modelo generativo e validar a experiência de uso.

Também foi discutido que o Open WebUI pode ser usado para fluxos de RAG, configurando o modelo de embedding como `bge-m3` e o modelo generativo como `qwen2.5-coder`.

Um ponto importante identificado foi que receber uma resposta no chat não comprova, por si só, que o Ollama está sendo usado como embedding server. Para validar isso, foram indicados testes como:

- Monitorar os logs do container do Ollama;
- Verificar chamadas para `/api/embed`;
- Usar `ollama ps` durante upload, reindexação ou consulta;
- Forçar erro configurando um modelo de embedding inexistente;
- Reindexar documentos após alterar o modelo de embedding.

---

## 5. Conclusões do experimento

### 5.1 Decisão: não utilizar TEI neste momento

A principal conclusão foi:

> Não será utilizado TEI para embeddings neste momento. A opção escolhida será utilizar o próprio Ollama como servidor de embeddings.

Essa decisão faz sentido para o estágio atual do projeto pelos seguintes motivos:

- Reduz a complexidade operacional;
- Evita manter mais um serviço dedicado apenas para embeddings;
- Facilita o setup local;
- Aproveita a stack já existente com Ollama;
- Simplifica testes iniciais de RAG;
- É suficiente para uma fase de prototipação e validação local.

O TEI pode continuar sendo considerado no futuro, principalmente se houver necessidade de:

- Maior throughput;
- Melhor performance em produção;
- Separação clara entre inferência generativa e embeddings;
- Escalabilidade independente;
- Deploy dedicado para múltiplos consumidores;
- Uso de modelos de embedding em ambiente mais controlado.

Para o momento atual, porém, o Ollama atende bem à necessidade.

---

## 6. Modelos escolhidos

### 6.1 Modelo generativo principal

```text
qwen2.5-coder:14b-instruct-q4_K_M
```

Este modelo foi escolhido como principal modelo generativo local.

#### Principais motivos

- Boa aderência a tarefas de código;
- Adequado para DevOps e infraestrutura;
- Bom equilíbrio entre qualidade e viabilidade no hardware disponível;
- Compatível com o perfil de uso técnico;
- Mais indicado para tarefas envolvendo código, automação, scripts e troubleshooting.

#### Casos de uso esperados

- Revisão de código;
- Geração de scripts;
- Explicação de erros;
- Terraform / Terragrunt;
- Kubernetes;
- Docker;
- Python;
- TypeScript;
- Node.js;
- Criação de documentação técnica;
- Apoio a decisões de arquitetura.

---

### 6.2 Modelo de embeddings

```text
bge-m3
```

O `bge-m3` foi escolhido como modelo inicial para geração de embeddings.

#### Principais motivos

- Modelo adequado para embeddings;
- Boa opção para cenários multilíngues;
- Útil para RAG;
- Pode ser servido diretamente pelo Ollama;
- Reduz a necessidade de componentes adicionais na stack;
- Serve bem para documentos técnicos, READMEs, ADRs, especificações, logs e bases de conhecimento.

#### Casos de uso esperados

- Indexação de documentos;
- Busca semântica;
- RAG;
- Base de conhecimento local;
- Análise de documentação viva;
- Busca em arquivos de projeto;
- Recuperação de contexto para modelos generativos.

---

## 7. Arquitetura sugerida após o experimento

A arquitetura local recomendada para o momento é:

```text
Usuário
  ↓
Open WebUI
  ↓
Ollama Server
  ├── qwen2.5-coder:14b-instruct-q4_K_M  → geração de respostas
  └── bge-m3                             → geração de embeddings
```

Para cenários de RAG mais completos:

```text
Documentos
  ↓
Chunking
  ↓
Ollama + bge-m3
  ↓
Vector Database
  ↓
Retriever
  ↓
Ollama + qwen2.5-coder
  ↓
Resposta final
```

Vector databases possíveis:

- Qdrant;
- PostgreSQL + pgvector;
- ChromaDB;
- LanceDB;
- Milvus.

Para o contexto local/homelab, as opções mais interessantes inicialmente são:

1. **Qdrant**, pela simplicidade, boa UI e foco em vector search;
2. **PostgreSQL + pgvector**, caso o objetivo seja manter tudo em uma stack PostgreSQL já conhecida.

---

## 8. Possíveis caminhos futuros

Além dos modelos escolhidos, alguns caminhos podem ser considerados conforme o projeto evoluir.

### 8.1 Modelo alternativo para raciocínio geral

```text
qwen3:14b
```

Pode ser considerado para:

- Raciocínio geral;
- Arquitetura;
- Planejamento;
- Análise técnica;
- Discussões mais amplas;
- Geração de documentação.

Pode ser uma boa alternativa ou complemento ao `qwen2.5-coder`, principalmente quando a tarefa não for centrada em código.

### 8.2 Modelo para raciocínio mais profundo

```text
deepseek-r1:8b
```

Pode ser avaliado para:

- Debugging complexo;
- Análise de causa raiz;
- Problemas de lógica;
- Troubleshooting;
- Comparação de alternativas técnicas.

Apesar disso, pode ser mais verboso e não necessariamente ideal como modelo padrão.

### 8.3 Modelo multimodal

```text
gemma3:12b
```

Pode ser considerado caso exista necessidade de análise de imagens, prints, telas, diagramas ou screenshots.

Esse caminho pode ser útil porque boa parte dos troubleshooting técnicos envolve prints de terminal, telas de configuração, dashboards e erros visuais.

### 8.4 UI dedicada para RAG

Além do Open WebUI, ferramentas futuras que podem ser avaliadas:

- AnythingLLM;
- Langflow;
- Flowise;
- Dify;
- Open WebUI com pipelines/customizações.

O **AnythingLLM** pode ser interessante para testar workspaces e chat com documentos de forma mais próxima de um produto pronto.

O **Langflow** pode ser útil para prototipar visualmente pipelines de RAG.

### 8.5 Vector database dedicado

Para uma fase mais avançada, vale considerar o uso de um vector database dedicado.

Opção recomendada para próximos testes:

```text
Qdrant
```

Motivos:

- Fácil de subir via Docker;
- Possui dashboard;
- Boa experiência para debug;
- Permite visualizar collections, payloads e resultados;
- Facilita validar se os chunks e embeddings estão bons.

---

## 9. Recomendações práticas

### 9.1 Manter a stack inicial simples

A recomendação para a fase atual é manter:

```text
Open WebUI + Ollama + qwen2.5-coder + bge-m3
```

Essa combinação é suficiente para validar:

- Chat local;
- Uso de LLM para desenvolvimento;
- RAG inicial;
- Embeddings via Ollama;
- Provas de conceito com documentos próprios.

### 9.2 Evitar complexidade prematura

Neste momento, não parece necessário adicionar TEI, Kubernetes, autoscaling ou múltiplos serviços de inferência.

A stack atual é adequada para:

- Desenvolvimento local;
- Prototipação;
- Estudos;
- Avaliação de modelos;
- Primeiros testes de RAG;
- Validação de arquitetura.

### 9.3 Validar tecnicamente o uso de embeddings

Para garantir que o Open WebUI está realmente usando o Ollama como embedding server, recomenda-se usar:

```bash
docker logs -f ollama | grep --line-buffered -Ei "api/embed|/api/embed|embed|bge-m3"
```

E também:

```bash
watch -n 0.5 "docker exec ollama ollama ps"
```

Durante upload, reindexação ou consulta baseada em documentos, espera-se observar uso do modelo:

```text
bge-m3
```

### 9.4 Reindexar documentos ao trocar o modelo de embedding

Sempre que o modelo de embedding for alterado, os documentos devem ser reindexados.

Isso é importante porque embeddings gerados por modelos diferentes podem não ser compatíveis semanticamente no mesmo espaço vetorial.

---

## 10. Decisão final

A decisão final após o experimento é:

```text
Embedding Server:
Ollama

Modelo de Embedding:
bge-m3

Modelo Generativo Principal:
qwen2.5-coder:14b-instruct-q4_K_M

Interface Inicial:
Open WebUI

TEI:
Não será utilizado neste momento
```

---

## 11. Próximos passos sugeridos

1. Fixar a stack inicial com Docker Compose.
2. Documentar as variáveis de ambiente usadas pelo Open WebUI.
3. Confirmar nos logs que o `bge-m3` está sendo usado para embeddings.
4. Criar um pequeno dataset de teste com documentos controlados.
5. Testar perguntas sobre os documentos e validar a qualidade da recuperação.
6. Avaliar Qdrant como vector database dedicado.
7. Medir performance dos modelos:
   - tempo de primeira resposta;
   - tokens por segundo;
   - uso de VRAM;
   - uso de RAM;
   - tempo de embedding por documento;
   - qualidade da resposta com e sem RAG.
8. Comparar `qwen2.5-coder` com `qwen3:14b` em tarefas não centradas em código.
9. Avaliar `gemma3:12b` para análise de imagens e prints.
10. Criar uma base inicial de conhecimento para projetos locais, homelab e documentação técnica.

---

## 12. Resumo executivo

O experimento demonstrou que o uso do **Ollama como servidor único para modelos generativos e embeddings** é uma abordagem adequada para o momento atual.

A decisão de não utilizar TEI reduz complexidade e permite avançar mais rapidamente na validação de RAG local. O modelo `qwen2.5-coder:14b-instruct-q4_K_M` atende bem ao perfil técnico do ambiente, enquanto o `bge-m3` cobre a necessidade inicial de embeddings.

A stack recomendada é simples, pragmática e alinhada ao objetivo de construir uma base local de IA para desenvolvimento, arquitetura, documentação e futuros fluxos de RAG.

