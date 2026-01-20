# Contrato Crossplane (Fase 1)

## Contratos (XRD/Claim)
- Postgres: `PostgresInstance` (XPostgresInstance)
- Redis: `RedisInstance` (XRedisInstance)

## Parâmetros
- app (string)
- env (dev|prod)
- owner (string)
- size (small|medium|large)

## DEV
- Provisiona Postgres e Redis no cluster (namespace `pe-dev`) via provider-kubernetes.

## PROD (Fase 1)
- Contrato existe e caminho está definido.
- Estratégia recomendada: BLOQUEADO via Software Template (não gera Claims em PROD),
  mantendo compatibilidade para habilitar PROD na Fase 2 sem quebrar o contrato.
