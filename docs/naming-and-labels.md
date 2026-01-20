# Naming / Labels / Annotations

## Namespaces
- DEV: `pe-dev`
- PROD: `pe-prod`

## Paths Git
- Aplicações DEV: `apps/dev/<app-name>/`
- Aplicações PROD: `apps/prod/<app-name>/`
- Infra (Claims) sempre dentro da app:
  - `apps/<env>/<app-name>/infra/*.yaml`

## Labels obrigatórios (em app e infra)
- `idp.platform.io/app: <app-name>`
- `idp.platform.io/env: dev|prod`
- `idp.platform.io/owner: <team-or-user>`

## Annotations recomendadas
- `idp.platform.io/source-repo: platform-state-repo`
- `idp.platform.io/managed-by: argocd`
