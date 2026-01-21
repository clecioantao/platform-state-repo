# Contrato Crossplane (Fase 1)

Este documento define o **contrato de infraestrutura** (API) oferecido pela plataforma via Crossplane.

## Objetivo
Garantir que dependências (Postgres/Redis) sejam provisionadas **sempre no contexto**:
- Aplicação (`app`)
- Ambiente (`env`)
- Owner (`owner`)
- Sizing (`size`)

## Recursos do contrato (planejado na Fase 1)

### 1) Postgres
- Claim: `PostgresInstance`
- Composite: `XPostgresInstance`

### 2) Redis
- Claim: `RedisInstance`
- Composite: `XRedisInstance`

## Campos mínimos (parâmetros)
- `app`: string (slug)
- `env`: dev|prod
- `owner`: string (time)
- `size`: small|medium|large

## Estratégia por ambiente

### DEV (Fase 1)
- Dependências rodam **no cluster**
- Provisionamento via Compositions usando provider Kubernetes (ou Helm provider)
- Namespaces: `pe-dev`
- Regras:
  - cada app tem claims no namespace do ambiente
  - labels obrigatórias em tudo

### PROD (Fase 1)
- PROD existe desde o Day 0 como contrato e caminho.
- Estratégia recomendada (Fase 1): **BLOQUEAR** a criação de infraestrutura em PROD no template do Backstage
  - Mantém o contrato existente
  - Evita “produção fake”
  - Permite habilitar a implementação real na Fase 2 sem quebrar o contrato

## Fase 2 (direção)
- Postgres/Redis em PROD via serviços gerenciados (cloud)
- Crossplane Providers cloud (AWS/Azure/GCP) e/ou Terraform via Crossplane
- Políticas e governança mais rígidas por ambiente
