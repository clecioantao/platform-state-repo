# Fluxo GitOps (Backstage → GitHub → Argo CD → Crossplane)

1) Dev usa um Software Template no Backstage local:
   - escolhe flavor, appName, owner, env (dev/prod), size
2) Backstage gera commits/PR no `platform-state-repo` em `apps/<env>/<appName>/...`
3) Argo CD observa:
   - `envs/dev` e `apps/dev` (DEV)
   - `envs/prod` e `apps/prod` (PROD)
4) Argo aplica manifests:
   - Workloads da aplicação
   - Claims Crossplane (DEV: Postgres/Redis no cluster)
5) Crossplane reconcilia Claims → cria recursos correspondentes (via Compositions)

Remover a pasta da app no Git:
- Argo faz prune
- Claims removidas
- Crossplane remove os recursos associados
