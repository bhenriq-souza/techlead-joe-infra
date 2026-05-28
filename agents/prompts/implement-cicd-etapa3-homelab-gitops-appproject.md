# Prompt — Etapa 3 do Plano CI/CD: ArgoCD AppProject e Application no homelab-gitops

## Instrucoes para o chat

Use este prompt para um chat dedicado a configurar o ArgoCD no `homelab-gitops` para gerenciar os workloads do Techlead Joe.
Cole o conteudo abaixo como sua primeira mensagem.
O workspace principal e `/home/bhs/code/Personal/homelab-gitops`.
As Etapas 1 e 2 devem estar concluidas antes de iniciar esta etapa.

---

## Prompt

Voce e um Engenheiro de Plataforma especializado em ArgoCD e GitOps multi-cluster.

Preciso que voce configure o **ArgoCD** no repositorio `homelab-gitops` para que ele gerencie os workloads do projeto Techlead Joe no cluster ai-lab, consumindo o repositorio `techlead-joe-gitops`.

### Contexto do projeto

O homelab usa ArgoCD como ferramenta de GitOps. O repositorio `homelab-gitops` e a fonte de verdade para toda a configuracao do ArgoCD — incluindo quais Applications e AppProjects existem. A estrutura de bootstrap usa um `Application` raiz (App of Apps) que sincroniza os demais manifestos do ArgoCD.

O repositorio `techlead-joe-gitops` (criado na Etapa 2) contem os manifests Kubernetes dos workloads do Techlead Joe no cluster ai-lab.

O plano completo esta em `techlead-joe-infra/docs/cicd-gitops-plan.md`.

Leia o repositorio `homelab-gitops` antes de comecar para entender o padrao exato de:
- Onde ficam os manifests de `Application` e `AppProject` do ArgoCD.
- Como o bootstrap raiz referencia as Applications filhas.
- Como o cluster ai-lab esta configurado (verifique `clusters/ai-lab/bootstrap/`).

### Decisoes arquiteturais ja tomadas (nao discutir, apenas seguir)

1. AppProject `techlead-joe` com source restrito ao repositorio `techlead-joe-gitops`.
2. Destination restrito ao namespace `techlead-joe` no cluster ai-lab.
3. Seguir o mesmo padrao de Application/AppProject do restante do homelab-gitops.
4. Usar sincronizacao automatica com prune e selfHeal habilitados (padrao do homelab).
5. O `techlead-joe-gitops` deve ser registrado como repositorio confiavel no ArgoCD (via secret de repositorio ou configuracao existente).

### O que preciso que voce entregue

**1. AppProject `techlead-joe`**

Criar manifest `AppProject` com:
- `sourceRepos`: apenas `https://github.com/bhenriq-souza/techlead-joe-gitops`
- `destinations`: cluster ai-lab, namespace `techlead-joe`
- `clusterResourceWhitelist`: apenas recursos necessarios (Namespace, se aplicavel)
- `namespaceResourceWhitelist`: tipos de recursos usados (Deployment, ExternalSecret, Secret, ServiceAccount)

**2. Application de dev**

Criar manifest `Application` para o ambiente dev:
- Aponta para `clusters/ai-lab/workloads/dev/` do `techlead-joe-gitops`
- Namespace de destino: `techlead-joe` no cluster ai-lab
- Sync policy: automatica, com prune e selfHeal
- Project: `techlead-joe`

**3. Application de prd**

Criar manifest `Application` para o ambiente prd seguindo o mesmo padrao.

**4. Integrar ao bootstrap do cluster ai-lab**

Identificar onde o bootstrap do cluster ai-lab esta configurado (`clusters/ai-lab/bootstrap/`). Adicionar referencias para os novos Application e AppProject, seguindo o padrao App of Apps do homelab.

**5. Secret de repositorio para `techlead-joe-gitops`**

Verificar se o ArgoCD precisa de um secret de repositorio para acessar `techlead-joe-gitops`. Se o repositorio for publico, nao e necessario. Se for privado, criar o secret seguindo o padrao usado para `homelab-gitops` (provavelmente via ExternalSecret ou secret manual).

### Restricoes e preferencias

- Nao modificar Applications ou AppProjects existentes de outros workloads.
- Seguir exatamente o padrao de YAML e convencoes de nomenclatura encontrados no repositorio.
- Se o cluster ai-lab nao estiver registrado no ArgoCD ainda, documentar o passo necessario para registra-lo (mas nao implementar o bootstrap do cluster, que e escopo da Etapa 1 em `itens-em-aberto-e-backlog.md`).

### Ao concluir

Informe:
- Quais arquivos foram criados e onde.
- Se ha pre-requisitos de infraestrutura (ex: cluster ai-lab precisa estar registrado no ArgoCD, namespace precisa existir).
- O que o operador precisa fazer manualmente alem de commitar os manifests (ex: registrar o cluster no ArgoCD via CLI, aplicar secret de repositorio).
