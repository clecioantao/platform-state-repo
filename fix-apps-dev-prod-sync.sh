#!/usr/bin/env bash
set -euo pipefail

ARGOCD_NS="${ARGOCD_NS:-argocd}"
APPS=("apps-dev" "apps-prod")
ROOT_APP="${ROOT_APP:-platform-root}"

echo "==> (1/6) Refresh hard em platform-root e apps-dev/apps-prod"
kubectl -n "${ARGOCD_NS}" annotate application "${ROOT_APP}" argocd.argoproj.io/refresh=hard --overwrite >/dev/null || true
for a in "${APPS[@]}"; do
  kubectl -n "${ARGOCD_NS}" annotate application "$a" argocd.argoproj.io/refresh=hard --overwrite >/dev/null || true
done
echo "OK."

echo "==> (2/6) Status atual"
kubectl -n "${ARGOCD_NS}" get applications | egrep 'platform-root|apps-dev|apps-prod' || true
echo

echo "==> (3/6) Descrevendo apps-dev/apps-prod (motivo do OutOfSync aparece aqui)"
for a in "${APPS[@]}"; do
  echo "---- describe application/${a} ----"
  kubectl -n "${ARGOCD_NS}" describe application "${a}" | sed -n '1,220p' || true
  echo
done

echo "==> (4/6) Garantindo namespaces apps-dev/apps-prod"
kubectl create ns apps-dev --dry-run=client -o yaml | kubectl apply -f - >/dev/null
kubectl create ns apps-prod --dry-run=client -o yaml | kubectl apply -f - >/dev/null
echo "OK."

echo "==> (5/6) Tentando aplicar sync via Argo (sem argocd CLI: forçamos nova reconciliação)"
# Sem argocd CLI, o melhor é refresh + esperar o controller auto-sync (se habilitado)
# e garantir que o source/path está OK.
for a in "${APPS[@]}"; do
  echo "---- application/${a} source/path ----"
  kubectl -n "${ARGOCD_NS}" get application "${a}" -o jsonpath='{.spec.source.repoURL}{" | "}{.spec.source.path}{" | "}{.spec.source.targetRevision}{"\n"}' || true
done
echo

echo "==> (6/6) Dicas de checagem rápida (rode se continuar OutOfSync)"
cat <<'EOF'

Se continuar OutOfSync, rode:
  # 1) Ver o erro exato do controller (ComparisonError, SyncError etc)
  kubectl -n argocd get application apps-dev -o yaml | sed -n '1,220p'
  kubectl -n argocd get application apps-prod -o yaml | sed -n '1,220p'

  # 2) Ver os eventos do ArgoCD
  kubectl -n argocd get events --sort-by=.lastTimestamp | tail -n 80

  # 3) Logs do repo-server (renderização) — útil se path/helm/kustomize falhar
  kubectl -n argocd logs deploy/argocd-repo-server --tail=200

  # 4) Logs do application-controller (sync/apply) — útil se RBAC ou apply falhar
  # (nome do deploy varia, liste primeiro)
  kubectl -n argocd get deploy | grep -i controller

EOF
