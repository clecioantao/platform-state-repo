# Fluxo GitOps

1. Dev cria app via Backstage
2. Backstage gera commits no platform-state-repo
3. Argo CD detecta mudanças
4. Argo aplica manifests por ambiente
5. Crossplane reconcilia infraestrutura

Remover app do Git:
- Argo faz prune
- Crossplane remove dependências
