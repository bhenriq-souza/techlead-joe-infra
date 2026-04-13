# Plataforma de Analise de Incidentes - Base de Conhecimento

Este diretorio consolida os registros de discovery da plataforma de analise de incidentes com observabilidade, conhecimento vivo e geracao de tickets com LLM local.

## Objetivo

Servir como base de conhecimento para detalhamento incremental da arquitetura em novos chats e novas especificacoes OpenSpec.

## Como navegar

- [discovery-report.md](discovery-report.md): visao global, motivacoes e macroarquitetura.
- [decisoes-arquiteturais.md](decisoes-arquiteturais.md): decisoes fechadas, rationale, riscos e trade-offs.
- [componentes-e-responsabilidades.md](componentes-e-responsabilidades.md): fronteiras, responsabilidades e contratos por componente.
- [modelo-conceitual-e-fluxos.md](modelo-conceitual-e-fluxos.md): entidades conceituais e fluxos ponta a ponta.
- [itens-em-aberto-e-backlog.md](itens-em-aberto-e-backlog.md): decisoes pendentes, perguntas e backlog de detalhamento.
- [openspec-roadmap.md](openspec-roadmap.md): direcionamento para transformar discovery em specs executaveis.

## Convencoes

- Status de decisao:
  - `Fechada`: decisao tomada e aceita.
  - `Aberta`: decisao pendente.
  - `Evolutiva`: decisao valida para MVP, revisavel por metrica.
- Prioridade:
  - `P0`: bloqueia arquitetura/MVP.
  - `P1`: importante para robustez operacional.
  - `P2`: melhoria posterior.

## Escopo deste pacote

- Foco em arquitetura logica e estrategia de implementacao.
- Nao inclui ainda schema fisico de banco, IaC, SLOs formais ou topologia final de deploy.
