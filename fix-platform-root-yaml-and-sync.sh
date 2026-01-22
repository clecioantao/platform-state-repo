#!/usr/bin/env bash
set -euo pipefail

# ==========================================================
# fix-platform-root-yaml-and-sync.sh
#
# Corrige o YAML quebrado do AppProject "apps" no Git (linha 12),
# com destinations incluindo apps-dev/apps-prod,
# faz commit+push e força o ArgoCD a reconciliar o platform-root.
# ==========================================================

ARGOCD_NS="${ARGOCD_NS:-argocd}"
ROOT_APP="${ROOT_APP:-platform-root}"

PROJECT_FILE="bootstrap/argocd/app-of-apps/projects/apps-project.yaml"

require() { command -v "$1" >/dev/null 2>&1 || { echo "ERRO: '$1' não encontrado"; exit 1; }; }
require kubectl
require git

# Detecta raiz do repo git
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
if [[ -z "${REPO_ROOT}" ]]; then
  echo "ERRO: este script precisa ser executado dentro de um repositório git."
  exit 1
fi
cd "${REPO_ROOT}"

echo "==> Repo root: ${REPO_ROOT}"

if [[ ! -f "${PROJECT_FILE}" ]]; then
  echo "ERRO: arquivo não encontrado: ${PROJECT_FILE}"
  echo "Confira o caminho. Procure assim:"
  echo "  find bootstrap/argocd/app-of-apps -maxdepth 3 -type f -name 'apps-project.yaml' -o -name '*apps*project*.yaml'"
  exit 1
fi

echo "==> (1/6) Reescrevendo ${PROJECT_FILE} com YAML válido (inclui apps-dev/apps-prod)"
cat > "${PROJECT_FILE}" <<'YAML'
apiVersion: argoproj.io/v1alpha1
kind: AppProject
metadata:
  name: apps
  namespace: argocd
spec:
  description: Applications and app-scoped infrastructure
  sourceRepos:
    - '*'

  # Permite deploy em namespaces de apps (novo) e mantém os anteriores (pe-*)
  destinations:
    - namespace: apps-dev
      server: https://kubernetes.default.svc
    - namespace: apps-prod
      server: https://kubernetes.default.svc
    - namespace: pe-dev
      server: https://kubernetes.default.svc
    - namespace: pe-prod
      server: https://kubernetes.default.svc

  # (Mantém permissivo pro lab; em produção você provavelmente vai restringir)
  clusterResourceWhitelist:
    - group: '*'
      kind: '*'
YAML

echo "OK: arquivo reescrito."

echo "==> (2/6) Validando YAML via kubectl (client dry-run)"
kubectl apply --dry-run=client -f "${PROJECT_FILE}" >/dev/null
echo "OK: YAML válido."

echo "==> (3/6) Commit + push (somente se houver mudança)"
if git diff --quiet -- "${PROJECT_FILE}"; then
  echo "INFO: Nenhuma mudança detectada em ${PROJECT_FILE} (já estava igual)."
else
  git add "${PROJECT_FILE}"
  git commit -m "fix(argocd): fix apps AppProject YAML + allow apps-dev/apps-prod"
  git push
  echo "OK: commit + push feitos."
fi

echo "==> (4/6) Forçando refresh hard no '${ROOT_APP}'"
kubectl -n "${ARGOCD_NS}" annotate application "${ROOT_APP}" argocd.argoproj.io/refresh=hard --overwrite >/dev/null
echo "OK: refresh hard aplicado."

echo "==> (5/6) (Opcional) Reiniciando repo-server e application-controller para limpar cache"
# Se algum desses não existir no seu install, não falha o script
kubectl -n "${ARGOCD_NS}" rollout restart deploy/argocd-repo-server >/dev/null 2>&1 || echo "WARN: deploy/argocd-repo-server não encontrado"
kubectl -n "${ARGOCD_NS}" rollout restart deploy/argocd-application-controller >/dev/null 2>&1 || echo "WARN: deploy/argocd-application-controller não encontrado"

echo "==> (6/6) Checando AppProject no cluster (destinations)"
echo "--- destinations atuais no cluster ---"
kubectl -n "${ARGOCD_NS}" get appproject apps -o jsonpath='{range .spec.destinations[*]}{.namespace}{"\n"}{end}' | sort || true

echo
echo "✅ Pronto."
echo "Agora valide:"
echo "  kubectl -n ${ARGOCD_NS} get application ${ROOT_APP} -o yaml | sed -n '1,120p'"
echo "  kubectl -n ${ARGOCD_NS} get appproject apps -o yaml | sed -n '1,220p'"
echo "  kubectl -n ${ARGOCD_NS} get applications | egrep 'platform-root|apps-dev|apps-prod'"
