#!/usr/bin/env bash
set -euo pipefail

# ==========================================================
# fix-argocd-platform-root-sync.sh
#
# Objetivo:
# - Forçar o ArgoCD a reconciliar o "platform-root" (app-of-apps),
#   que é quem aplica o AppProject 'apps' vindo do Git.
# - Validar se o AppProject no cluster passou a permitir apps-dev/apps-prod.
#
# Por que isso é necessário?
# - apps-dev/apps-prod NÃO gerenciam o AppProject.
# - Quem gerencia (tracking-id mostra isso) é o platform-root.
# ==========================================================

ARGOCD_NS="${ARGOCD_NS:-argocd}"
ROOT_APP="${ROOT_APP:-platform-root}"
PROJECT="${PROJECT:-apps}"
NEED_NS_1="${NEED_NS_1:-apps-dev}"
NEED_NS_2="${NEED_NS_2:-apps-prod}"

APPS_DEV_APP="${APPS_DEV_APP:-apps-dev}"
APPS_PROD_APP="${APPS_PROD_APP:-apps-prod}"

WAIT_SECONDS="${WAIT_SECONDS:-180}"

require() { command -v "$1" >/dev/null 2>&1 || { echo "ERRO: '$1' não encontrado"; exit 1; }; }
require kubectl
require grep
require sed

echo "==> Checando se Applications existem no namespace '${ARGOCD_NS}'"
kubectl -n "${ARGOCD_NS}" get application "${ROOT_APP}" >/dev/null 2>&1 || {
  echo "ERRO: Application '${ROOT_APP}' não encontrado em '${ARGOCD_NS}'."
  echo "Dica: liste apps: kubectl -n ${ARGOCD_NS} get applications"
  exit 1
}

echo "==> (1/4) Refresh hard no '${ROOT_APP}' (app-of-apps)"
kubectl -n "${ARGOCD_NS}" annotate application "${ROOT_APP}" argocd.argoproj.io/refresh=hard --overwrite >/dev/null
echo "OK: refresh hard aplicado em ${ROOT_APP}"

# Observação: sem argocd CLI, a forma segura é:
# - garantir refresh hard
# - e, se autosync estiver ligado, ele sincroniza sozinho
# - se não estiver, você dá sync pela UI (ou adiciona autosync no manifesto)
# Aqui vamos apenas "chacoalhar" novamente com refresh e esperar.

echo "==> (2/4) Refresh hard também em apps-dev/apps-prod (opcional)"
if kubectl -n "${ARGOCD_NS}" get application "${APPS_DEV_APP}" >/dev/null 2>&1; then
  kubectl -n "${ARGOCD_NS}" annotate application "${APPS_DEV_APP}" argocd.argoproj.io/refresh=hard --overwrite >/dev/null
  echo "OK: refresh hard em ${APPS_DEV_APP}"
else
  echo "WARN: ${APPS_DEV_APP} não encontrado"
fi

if kubectl -n "${ARGOCD_NS}" get application "${APPS_PROD_APP}" >/dev/null 2>&1; then
  kubectl -n "${ARGOCD_NS}" annotate application "${APPS_PROD_APP}" argocd.argoproj.io/refresh=hard --overwrite >/dev/null
  echo "OK: refresh hard em ${APPS_PROD_APP}"
else
  echo "WARN: ${APPS_PROD_APP} não encontrado"
fi

echo "==> (3/4) Aguardando o AppProject '${PROJECT}' refletir o Git (até ${WAIT_SECONDS}s)"
end=$((SECONDS + WAIT_SECONDS))

while (( SECONDS < end )); do
  # pega destinos do AppProject no cluster
  dests="$(kubectl -n "${ARGOCD_NS}" get appproject "${PROJECT}" -o jsonpath='{range .spec.destinations[*]}{.namespace}{"\n"}{end}' 2>/dev/null || true)"

  if echo "${dests}" | grep -qx "${NEED_NS_1}" && echo "${dests}" | grep -qx "${NEED_NS_2}"; then
    echo "OK: AppProject '${PROJECT}' agora permite '${NEED_NS_1}' e '${NEED_NS_2}' ✅"
    break
  fi

  sleep 5
done

echo
echo "==> (4/4) Status atual"
echo "--- AppProject '${PROJECT}' destinations (cluster) ---"
kubectl -n "${ARGOCD_NS}" get appproject "${PROJECT}" -o yaml | sed -n '1,220p'

echo
echo "--- Applications (apps-dev/apps-prod/platform-root) ---"
kubectl -n "${ARGOCD_NS}" get applications | egrep "(${ROOT_APP}|${APPS_DEV_APP}|${APPS_PROD_APP})" || true

echo
echo "Se ainda NÃO apareceu apps-dev/apps-prod em spec.destinations, rode estes diagnósticos:"
echo "  kubectl -n ${ARGOCD_NS} get application ${ROOT_APP} -o yaml | sed -n '1,260p'"
echo "  kubectl -n ${ARGOCD_NS} describe application ${ROOT_APP}"
echo "  kubectl -n ${ARGOCD_NS} get events --sort-by=.lastTimestamp | tail -n 80"
echo "  kubectl -n ${ARGOCD_NS} logs deploy/argocd-application-controller --tail=200"
echo "  kubectl -n ${ARGOCD_NS} logs deploy/argocd-repo-server --tail=200"
