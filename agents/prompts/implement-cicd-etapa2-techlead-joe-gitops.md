# Prompt — Etapa 2 do Plano CI/CD: Criar repositorio techlead-joe-gitops

## Instrucoes para o chat

Use este prompt para um chat dedicado a criar o repositorio `techlead-joe-gitops` e implementar os primeiros manifests Kubernetes.
Cole o conteudo abaixo como sua primeira mensagem.
A Etapa 1 (Terraform WIF + Secrets) deve estar concluida antes de iniciar esta etapa.

---

## Prompt

Voce e um Engenheiro de Plataforma especializado em Kubernetes, Kustomize e GitOps com ArgoCD.

Preciso que voce crie o repositorio **`techlead-joe-gitops`** e implemente os manifests Kubernetes para o servico `knowledge-injection-service` do projeto Techlead Joe.

### Contexto do projeto

O homelab usa GitOps com ArgoCD. O repositorio `homelab-gitops` e a fonte de verdade para a infraestrutura do homelab. Para o projeto Techlead Joe, foi decidido criar um repositorio GitOps separado (`techlead-joe-gitops`) para manter autonomia de deploy e separacao de responsabilidades.

O cluster alvo e o **ai-lab** (Cluster A), uma workstation Ubuntu dedicada a inferencia LLM com RTX 5070. O cluster roda k3s e sera gerenciado pelo mesmo ArgoCD do homelab.

O plano completo esta em `techlead-joe-infra/docs/cicd-gitops-plan.md`.

Referencia de estrutura: o repositorio `homelab-gitops` (disponivel em `/home/bhs/code/Personal/homelab-gitops`) serve como modelo de estrutura, convencoes de Kustomize e ExternalSecrets.

### Contexto do servico `knowledge-injection-service`

- Repositorio: `bhenriq-souza/techlead-joe-knowledge-injection-service`
- Imagem Docker: `us-central1-docker.pkg.dev/homelab-492918/homelab-apps/knowledge-injection-service:{sha}`
- Funcao: servico Python que ingere repositorios Git no pgvector para pipelines RAG
- Runtime: container de longa duracao (Deployment), nao batch
- Variaveis de ambiente necessarias (todas vindas de secrets):
  - `POSTGRES_HOST`, `POSTGRES_DB`, `POSTGRES_USER`, `POSTGRES_PASSWORD`
  - `OLLAMA_BASE_URL`
- Porta: nao expoe porta HTTP (servico interno sem ingress)
- Recursos: leve — pode usar `requests: { cpu: 100m, memory: 256Mi }`, `limits: { cpu: 500m, memory: 512Mi }`

### Decisoes arquiteturais ja tomadas (nao discutir, apenas seguir)

1. Estrutura de diretorios espelha `homelab-gitops`: `clusters/ai-lab/workloads/{dev,prd}/manifests/{app}/`.
2. Kustomize para composicao de manifests (sem Helm por enquanto).
3. External Secrets Operator (ESO) para injetar secrets do GCP Secret Manager nos pods.
4. Image pull secret via ExternalSecret (padrao `externalsecret-image-pull` do homelab).
5. Namespace dedicado: `techlead-joe` no cluster ai-lab.
6. Secrets no GCP Secret Manager com prefixo `tj-` (criados na Etapa 1).
7. `ClusterSecretStore` a ser reutilizado do padrao do homelab (verificar se existe no cluster ai-lab ou se precisa ser criado).

### O que preciso que voce entregue

**1. Estrutura de diretorios do repositorio**

Criar a seguinte estrutura (verifique `homelab-gitops` para se basear no padrao exato de kustomization.yaml):

```
techlead-joe-gitops/
├── clusters/
│   └── ai-lab/
│       └── workloads/
│           ├── dev/
│           │   ├── kustomization.yaml
│           │   └── manifests/
│           │       └── knowledge-injection-service/
│           │           ├── deployment.yaml
│           │           ├── externalsecret.yaml
│           │           └── kustomization.yaml
│           └── prd/
│               └── (mesmo padrao que dev)
├── components/
└── README.md
```

**2. Manifests para `knowledge-injection-service` (ambiente dev)**

- `deployment.yaml`: Deployment com a imagem do Artifact Registry, variaveis de ambiente vindas do Secret, sem porta exposta, sem ingress.
- `externalsecret.yaml`:
  - ExternalSecret para secrets de aplicacao (`tj-postgres-*`, `tj-ollama-base-url`) referenciando o `ClusterSecretStore` do homelab.
  - ExternalSecret para image pull secret (padrao `externalsecret-image-pull` do homelab — verifique o template em `homelab-gitops/clusters/homelab/workloads/dev/manifests/`).
- `kustomization.yaml`: lista os recursos acima.

**3. Kustomization do ambiente dev**

`clusters/ai-lab/workloads/dev/kustomization.yaml` referenciando `./manifests/knowledge-injection-service/`.

**4. Namespace**

Incluir o manifest de Namespace `techlead-joe` em local adequado (pode ser no kustomization raiz ou como recurso separado).

**5. Replicar para prd**

Criar os mesmos manifests em `prd/` com as variaveis de ambiente apontando para os secrets de producao (`tj-*-prd` ou conforme nomenclatura adotada na Etapa 1).

### Restricoes e preferencias

- Seguir exatamente o padrao de Kustomize e ExternalSecret encontrado em `homelab-gitops`.
- Nao usar Helm.
- Nao criar recursos de Ingress ou Service (o servico nao expoe HTTP).
- Tags de imagem ficam como placeholder (ex: `image: us-central1-docker.pkg.dev/homelab-492918/homelab-apps/knowledge-injection-service:latest`) — o CI vai atualize-las.
- README.md minimo: descricao do repo, estrutura, como adicionar um novo servico.

### Ao concluir

Informe:
- Lista de arquivos criados.
- Como o ArgoCD devera ser configurado para apontar para este repo (input para a Etapa 3).
- Qualquer dependencia encontrada (ex: `ClusterSecretStore` precisa existir no cluster antes do ESO funcionar).
