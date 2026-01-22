#!/usr/bin/env bash
set -euo pipefail

ARGOCD_NS="${ARGOCD_NS:-argocd}"
APP_PROD="${APP_PROD:-apps-prod}"
APP_DEV="${APP_DEV:-apps-dev}"

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
if [[ -z "${REPO_ROOT}" ]]; then
  echo "ERRO: execute na raiz do repo (onde existe .git)."
  exit 1
fi

cd "${REPO_ROOT}"

echo "==> Repo root: ${REPO_ROOT}"

echo "==> (1/6) Garantindo namespaces no cluster (idempotente)"
kubectl get ns apps-prod >/dev/null 2>&1 || kubectl create ns apps-prod
kubectl get ns apps-dev  >/dev/null 2>&1 || kubectl create ns apps-dev
echo "OK: namespaces apps-dev/apps-prod existem no cluster."

echo "==> (2/6) Garantindo manifests de Namespace no Git (GitOps-friendly)"
mkdir -p apps/prod
mkdir -p apps/dev

# Namespace do PROD (necessário)
cat > apps/prod/00-namespace.yaml <<'EOF'
apiVersion: v1
kind: Namespace
metadata:
  name: apps-prod
  labels:
    idp.platform.io/env: prod
EOF

# Namespace do DEV (opcional, mas deixa consistente)
cat > apps/dev/00-namespace.yaml <<'EOF'
apiVersion: v1
kind: Namespace
metadata:
  name: apps-dev
  labels:
    idp.platform.io/env: dev
EOF

echo "OK: manifests criados/atualizados:"
echo "  - apps/prod/00-namespace.yaml"
echo "  - apps/dev/00-namespace.yaml"

echo "==> (3/6) Commit + push (somente se houver mudança)"
if git status --porcelain | grep -q .; then
  git add apps/prod/00-namespace.yaml apps/dev/00-namespace.yaml
  git commit -m "fix(argocd): ensure apps-dev/apps-prod namespaces via GitOps manifests"
  git push
  echo "OK: commit + push feitos."
else
  echo "INFO: nenhum change para commitar."
fi

echo "==> (4/6) Refresh hard no ArgoCD (apps-prod e apps-dev)"
kubectl -n "${ARGOCD_NS}" annotate application "${APP_PROD}" argocd.argoproj.io/refresh=hard --overwrite >/dev/null || true
kubectl -n "${ARGOCD_NS}" annotate application "${APP_DEV}"  argocd.argoproj.io/refresh=hard --overwrite >/dev/null || true
echo "OK: refresh hard aplicado."

echo "==> (5/6) Aguardando apps-prod ficar Synced (até 180s)"
end=$((SECONDS+180))
while true; do
  s="$(kubectl -n "${ARGOCD_NS}" get application "${APP_PROD}" -o jsonpath='{.status.sync.status}' 2>/dev/null || echo "Unknown")"
  h="$(kubectl -n "${ARGOCD_NS}" get application "${APP_PROD}" -o jsonpath='{.status.health.status}' 2>/dev/null || echo "Unknown")"
  echo "  apps-prod => sync=${s} health=${h}"
  if [[ "${s}" == "Synced" ]]; then
    echo "OK: apps-prod Synced ✅"
    break
  fi
  if (( SECONDS >= end )); then
    echo "WARN: timeout esperando apps-prod Synced."
    echo "Mostrando trecho do describe (erro atual):"
    kubectl -n "${ARGOCD_NS}" describe application "${APP_PROD}" | sed -n '1,240p' || true
    exit 2
  fi
  sleep 5
done

echo "==> (6/6) Status final"
kubectl -n "${ARGOCD_NS}" get applications | egrep 'apps-dev|apps-prod|platform-root' || true

echo
echo "✅ Concluído."
echo "Se ainda aparecer OutOfSync por outro motivo, cole:"
echo "  kubectl -n argocd describe application apps-prod | sed -n '1,260p'"
