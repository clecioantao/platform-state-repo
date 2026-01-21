# Arquitetura da PoC

## Componentes

### Backstage (local)
- Executa fora do cluster
- Exposição de Software Templates
- Gera conteúdo GitOps
- Nunca aplica manifests

### GitHub
- Fonte única da verdade
- Armazena estado da plataforma, apps e infra

### Argo CD
- Observa o repositório
- Aplica manifests por ambiente
- Gerencia ciclo de vida

### Crossplane
- Implementa contratos de infraestrutura
- Provisiona dependências via Claims
- Separa intenção (claim) da implementação
