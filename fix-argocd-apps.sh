#!/usr/bin/env bash
set -euo pipefail

# ==========================================================
# fix-argocd-apps.sh
#
# Corrige:
# 1) ArgoCD Project 'apps' não permitindo namespace apps-dev/apps-prod
# 2) apps-prod com "app path does not exist" (cria apps/prod/app1)
# 3) Refresh hard nas apps (apps-dev / apps-prod)
#
# Requisitos: kubectl + git
# Rodar na RAIZ do repo platform-state-repo
# ==========================================================

# --- Ajuste se necessário ---
ARGOCD_NS="${ARGOCD_NS:-argocd}"          # namespace onde ficam AppProject/Applications
APPS_PROJECT="${APPS_PROJECT:-apps}"      # nome do AppProject
APP_DEV_NAME="${APP_DEV_NAME:-apps-dev}"  # nome da Application dev
APP_PROD_NAME="${APP_PROD_NAME:-apps-prod}" # nome da Application prod

# Namespaces de destino que o Project deve permitir
ALLOW_NS_DEV="${ALLOW_NS_DEV:-apps-dev}"
ALLOW_NS_PROD="${ALLOW_NS_PROD:-apps-prod}"

# App exemplo que você já tem no dev
DEV_APP_DIR="${DEV_APP_DIR:-apps/dev/app1}"
PROD_APP_DIR="${PROD_APP_DIR:-apps/prod/app1}"

# Ajustes de environment dentro dos manifests (DEV -> PROD)
DEV_ENV_VALUE="${DEV_ENV_VALUE:-dev}"
PROD_ENV_VALUE="${PROD_ENV_VALUE:-prod}"

echo "==> (1/4) Validando pré-requisitos"
command -v kubectl >/dev/null 2>&1 || { echo "ERRO: kubectl não encontrado"; exit 1; }
command -v git >/dev/null 2>&1 || { echo "ERRO: git não encontrado"; exit 1; }

# Garantir que está na raiz do repo (heurística simples)
if [[ ! -d ".git" ]]; then
  echo "ERRO: rode este script na raiz do repositório (onde existe a pasta .git)."
  exit 1
fi

# Evitar bagunçar commits se o repo já estiver sujo (você pode remover esse bloqueio se quiser)
if [[ -n "$(git status --porcelain)" ]]; then
  echo "ERRO: seu repositório está com mudanças pendentes (working tree suja)."
  echo "Faça commit/stash antes, ou remova este bloqueio no script."
  git status --porcelain
  exit 1
fi

echo "==> (2/4) Corrigindo AppProject '${APPS_PROJECT}' para permitir namespaces apps-dev/apps-prod"

# Checa se AppProject existe
if ! kubectl -n "${ARGOCD_NS}" get appproject "${APPS_PROJECT}" >/dev/null 2>&1; then
  echo "ERRO: AppProject '${APPS_PROJECT}' não encontrado no namespace '${ARGOCD_NS}'."
  echo "Dica: liste com: kubectl -n ${ARGOCD_NS} get appprojects"
  exit 1
fi

# Patch: adiciona/garante destinos permitidos
# Observação: usamos JSONPatch para adicionar destinos (se já existir, pode falhar ao duplicar).
# Então: primeiro aplicamos um patch MERGE com uma lista completa mínima de destinos.
kubectl -n "${ARGOCD_NS}" patch appproject "${APPS_PROJECT}" --type merge -p "
spec:
  destinations:
    - namespace: ${ALLOW_NS_DEV}
      server: https://kubernetes.default.svc
    - namespace: ${ALLOW_NS_PROD}
      server: https://kubernetes.default.svc
" >/dev/null

echo "OK: AppProject '${APPS_PROJECT}' agora permite '${ALLOW_NS_DEV}' e '${ALLOW_NS_PROD}'."

echo "==> (3/4) Corrigindo apps-prod: garantindo path ${PROD_APP_DIR} no Git"

if [[ ! -d "${DEV_APP_DIR}" ]]; then
  echo "ERRO: diretório DEV não encontrado: ${DEV_APP_DIR}"
  echo "Verifique se existe apps/dev/app1 no seu repo."
  exit 1
fi

if [[ -d "${PROD_APP_DIR}" ]]; then
  echo "INFO: ${PROD_APP_DIR} já existe. Vou apenas garantir ajustes de PROD nos manifests."
else
  echo "Criando ${PROD_APP_DIR} copiando de ${DEV_APP_DIR} ..."
  mkdir -p "${PROD_APP_DIR}"
  cp -a "${DEV_APP_DIR}/." "${PROD_APP_DIR}/"
fi

# Ajustar namespace e env nos YAMLs do prod
# - Troca apps-dev -> apps-prod
# - Troca env: dev -> env: prod (e variantes com "env: dev")
# - Troca valores soltos ": dev" quando fizer sentido (com cautela)
shopt -s nullglob
for f in "${PROD_APP_DIR}"/*.yaml "${PROD_APP_DIR}"/*.yml; do
  echo "Ajustando arquivo: $f"
  # Troca namespace
  sed -i "s/\b${ALLOW_NS_DEV}\b/${ALLOW_NS_PROD}/g" "$f"

  # Troca env em linhas YAML (env: dev -> env: prod)
  sed -i "s/\benv:[[:space:]]*${DEV_ENV_VALUE}\b/env: ${PROD_ENV_VALUE}/g" "$f"

  # Troca label comum (se você usa algo tipo idp.platform.io/env: dev)
  sed -i "s/\bidp\.platform\.io\/env:[[:space:]]*${DEV_ENV_VALUE}\b/idp.platform.io\/env: ${PROD_ENV_VALUE}/g" "$f"
done
shopt -u nullglob

# Commit e push para ArgoCD enxergar o path novo
echo "==> Commitando e enviando alterações para o Git"
git add -A
git commit -m "fix(argocd): allow apps namespaces + create apps/prod/app1" >/dev/null
git push

echo "==> (4/4) Forçando refresh hard nas Applications (se existirem)"
# Se as Applications não estiverem no ARGOCD_NS, isso falha. Mostro dica.
if kubectl -n "${ARGOCD_NS}" get application "${APP_DEV_NAME}" >/dev/null 2>&1; then
  kubectl -n "${ARGOCD_NS}" annotate application "${APP_DEV_NAME}" argocd.argoproj.io/refresh=hard --overwrite >/dev/null
  echo "OK: refresh hard aplicado em ${APP_DEV_NAME}"
else
  echo "WARN: Application ${APP_DEV_NAME} não encontrada em ${ARGOCD_NS} (ignore se ela estiver em outro namespace)."
fi

if kubectl -n "${ARGOCD_NS}" get application "${APP_PROD_NAME}" >/dev/null 2>&1; then
  kubectl -n "${ARGOCD_NS}" annotate application "${APP_PROD_NAME}" argocd.argoproj.io/refresh=hard --overwrite >/dev/null
  echo "OK: refresh hard aplicado em ${APP_PROD_NAME}"
else
  echo "WARN: Application ${APP_PROD_NAME} não encontrada em ${ARGOCD_NS} (ignore se ela estiver em outro namespace)."
fi

echo
echo "✅ Concluído!"
echo "Próximos checks:"
echo "  kubectl -n ${ARGOCD_NS} get appproject ${APPS_PROJECT} -o yaml | sed -n '1,220p'"
echo "  (ArgoCD UI) Sync apps-dev e apps-prod"
echo "  (Git) confira se apps/prod/app1 existe no repo remoto"
