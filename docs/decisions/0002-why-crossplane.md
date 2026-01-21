# ADR 0002 – Por que Crossplane

## Decisão
Adotar Crossplane como mecanismo de **contrato** e **lifecycle** de infraestrutura, usando:
- Claims (intenção)
- Compositions (implementação)
- Reconciliação contínua

## Motivo
1. **Contrato estável**: DEV e PROD podem variar a implementação sem quebrar a API oferecida ao dev.
2. **Governança**: plataforma controla como infra é criada, com padrões, políticas e metadados.
3. **Ciclo de vida**: infra nasce e morre junto da aplicação (prune + reconciliação).
4. **Evolução natural**: Fase 1 (in-cluster) → Fase 2 (cloud/managed) mantendo o contrato.

## Alternativas consideradas
- Helm direto via Argo: simples, mas sem API de contrato por tipo de recurso.
- Terraform/Ansible: bons, mas o “reconcile contínuo” e modelo de composição exigiriam mais cola.

## Consequência
- Maior curva inicial, mas ganho forte em padronização e evolução do produto plataforma.
