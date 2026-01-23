#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="${1:-.}"

cd "$REPO_ROOT"

echo "[1/5] Garantindo que estamos no repo certo..."
test -d apps/dev || { echo "ERRO: não encontrei apps/dev (rode no root do platform-state-repo)"; exit 1; }

echo "[2/5] Removendo manifests que não devem ser aplicados pelo Argo (Backstage catalog-info.yaml)..."
# Remove catalog-info.yaml dentro de apps/dev/** (o Argo não deve aplicar isso no cluster)
find apps/dev -type f -name "catalog-info.yaml" -print -delete || true

echo "[3/5] Removendo Kustomization (Flux) que o Argo está tentando aplicar (CRD não existe)..."
# Se você tem kustomization.yaml gerado dentro do out/, isso costuma ser do Flux/kustomize-toolkit
find apps/dev -type f -name "kustomization.yaml" -print -delete || true

echo "[4/5] Mantendo apenas workload "aplicável" (ex: app.yaml) e limpando diretórios vazios..."
find apps/dev -type d -empty -print -delete || true

echo "[5/5] Git status e commit (opcional)..."
git status --porcelain || true

cat <<'EOF'

PRÓXIMOS PASSOS (IMPORTANTES)
1) Commit e push dessas remoções:
   git add -A
   git commit -m "fix: remove catalog-info and kustomization from apps/dev for Argo"
   git push

2) No Argo App apps-dev, o ideal é DESLIGAR recurse=true e/ou migrar para app-of-apps.
   O padrão mais saudável: Argo aponta para apps/dev e só encontra YAML "aplicável" (Namespace, Deploy, Service, etc).

EOF
