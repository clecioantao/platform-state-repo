# platform-state-repo

Fonte única da verdade (GitOps) para a PoC de IDP com:
- Backstage (local, fora do cluster) → gera conteúdo GitOps
- Argo CD (no cluster) → aplica manifests
- Crossplane (no cluster) → provisiona dependências via Claims/Compositions

## Princípios
- Infra nunca existe fora do contexto de uma APLICAÇÃO e de um AMBIENTE.
- Ambientes obrigatórios desde o Day 0: dev e prod.
- Backstage não aplica nada no cluster; apenas versiona no Git.
- Argo CD é o único aplicador de manifests.
- Crossplane materializa infraestrutura via Claims.

## Estrutura
- `bootstrap/`: bootstrap da plataforma (ArgoCD root apps; contrato Crossplane)
- `envs/`: entradas GitOps por ambiente (dev/prod)
- `apps/`: aplicações por ambiente (apps/dev/<app>, apps/prod/<app>)
- `backstage/`: catálogos e templates consumidos pelo Backstage local
- `docs/`: documentação da PoC

## Convenções rápidas
- Namespaces por ambiente: `pe-dev`, `pe-prod`
- Labels obrigatórios: `idp.platform.io/app`, `idp.platform.io/env`, `idp.platform.io/owner`
