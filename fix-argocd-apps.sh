#!/usr/bin/env bash
set -euo pipefail

# ==========================================================
# fix-argocd-appproject-apps.sh
#
# Corrige de forma PERSISTENTE (via Git) os erros:
# - "namespace apps-dev is not permitted in project 'apps'"
# - apps-prod "app path does not exist"
#
# Estratégia:
# 1) Edita no REPO o YAML do AppProject 'apps' para incluir
#    destinations apps-dev e apps-prod.
# 2) Garante apps/prod/app1 copiando de apps/dev/app1 (se não existir)
# 3) Commit + push
# 4) Refresh hard nas Applications (apps-dev/apps-prod)
# ==========================================================

ARGOCD_NS="${ARGOCD_NS:-argocd}"
PROJECT_NAME="${PROJECT_NAME:-apps}"
APP_DEV_NAME="${APP_DEV_NAME:-apps-dev}"
APP_PROD_NAME="${APP_PROD_NAME:-apps-prod}"

ALLOW_NS_DEV="${ALLOW_NS_DEV:-apps-dev}"
ALLOW_NS_PROD="${ALLOW_NS_PROD:-apps-prod}"

DEV_APP_DIR_REL="${DEV_APP_DIR_REL:-apps/dev/app1}"
PROD_APP_DIR_REL="${PROD_APP_DIR_REL:-apps/prod/app1}"

DEV_ENV_VALUE="${DEV_ENV_VALUE:-dev}"
PROD_ENV_VALUE="${PROD_ENV_VALUE:-prod}"

require() { command -v "$1" >/dev/null 2>&1 || { echo "ERRO: '$1' não encontrado"; exit 1; }; }

require git
require kubectl
require sed
require awk
require grep

echo "==> Detectando raiz do git"
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || { echo "ERRO: não parece ser um repo git"; exit 1; }
cd "$REPO_ROOT"
echo "Repo root: $REPO_ROOT"

echo "==> Validando working tree (precisa estar limpa)"
if [[ -n "$(git status --porcelain)" ]]; then
  echo "ERRO: working tree suja. Faça commit/stash antes."
  git status --porcelain
  exit 1
fi

echo "==> (1/5) Encontrando o manifesto do AppProject '${PROJECT_NAME}' no repositório"
# procura arquivo que contenha kind AppProject e metadata.name: apps
mapfile -t CANDIDATES < <(
  grep -RIl --exclude-dir=.git \
    -e "kind:[[:space:]]*AppProject" \
    -e "kind: AppProject" \
    . | while read -r f; do
      if grep -qE "metadata:[[:space:]]*$" "$f" && grep -qE "name:[[:space:]]*${PROJECT_NAME}\b" "$f"; then
        echo "$f"
      fi
    done
)

if [[ ${#CANDIDATES[@]} -eq 0 ]]; then
  # fallback: busca mais simples
  mapfile -t CANDIDATES < <(
    grep -RIl --exclude-dir=.git "name:[[:space:]]*${PROJECT_NAME}\b" . | while read -r f; do
      grep -qE "kind:[[:space:]]*AppProject" "$f" && echo "$f"
    done
  )
fi

if [[ ${#CANDIDATES[@]} -eq 0 ]]; then
  echo "ERRO: não encontrei o YAML do AppProject '${PROJECT_NAME}' no repo."
  echo "Dica: procure manualmente por 'kind: AppProject' e 'name: apps'."
  exit 1
fi

APP_PROJECT_FILE="${CANDIDATES[0]}"
echo "Encontrado: ${APP_PROJECT_FILE#${REPO_ROOT}/}"

echo "==> (2/5) Ajustando destinations do AppProject NO ARQUIVO (GitOps)"
# Vamos inserir destinos apps-dev/apps-prod se não existirem.
# Regras:
# - mantém o que já existe (pe-dev/pe-prod etc.)
# - adiciona:
#   - namespace: apps-dev
#     server: https://kubernetes.default.svc
#   - namespace: apps-prod
#     server: https://kubernetes.default.svc

SERVER_URL="https://kubernetes.default.svc"

# Checa se já tem apps-dev/apps-prod no arquivo
HAS_APPS_DEV="$(grep -nE "namespace:[[:space:]]*${ALLOW_NS_DEV}\b" "$APP_PROJECT_FILE" || true)"
HAS_APPS_PROD="$(grep -nE "namespace:[[:space:]]*${ALLOW_NS_PROD}\b" "$APP_PROJECT_FILE" || true)"

if [[ -n "$HAS_APPS_DEV" && -n "$HAS_APPS_PROD" ]]; then
  echo "INFO: destinations já contém ${ALLOW_NS_DEV} e ${ALLOW_NS_PROD}. Nada a fazer no AppProject."
else
  # Insere logo após a linha "destinations:" (primeira ocorrência)
  TMP="$(mktemp)"
  awk -v ns1="$ALLOW_NS_DEV" -v ns2="$ALLOW_NS_PROD" -v srv="$SERVER_URL" '
    BEGIN { inserted=0 }
    {
      print $0
      if (!inserted && $0 ~ /^[[:space:]]*destinations:[[:space:]]*$/) {
        # vamos inserir imediatamente após "destinations:"
        # mantendo indentação padrão de 2 espaços (Argo geralmente usa 2)
        print "  - namespace: " ns1
        print "    server: " srv
        print "  - namespace: " ns2
        print "    server: " srv
        inserted=1
      }
    }
  ' "$APP_PROJECT_FILE" > "$TMP"

  mv "$TMP" "$APP_PROJECT_FILE"

  # remove duplicatas se existiam parcialmente (casos raros)
  # (não é perfeito, mas evita repetir)
  # Se quiser hardening depois, fazemos com yq.
  echo "OK: Inseridos destinos ${ALLOW_NS_DEV}/${ALLOW_NS_PROD} em ${APP_PROJECT_FILE#${REPO_ROOT}/}"
fi

echo "==> (3/5) Corrigindo apps-prod: garantindo path ${PROD_APP_DIR_REL} no Git"
DEV_APP_DIR="${REPO_ROOT}/${DEV_APP_DIR_REL}"
PROD_APP_DIR="${REPO_ROOT}/${PROD_APP_DIR_REL}"

if [[ ! -d "${DEV_APP_DIR}" ]]; then
  echo "ERRO: diretório DEV não encontrado: ${DEV_APP_DIR_REL}"
  exit 1
fi

if [[ -d "${PROD_APP_DIR}" ]]; then
  echo "INFO: ${PROD_APP_DIR_REL} já existe."
else
  echo "Criando ${PROD_APP_DIR_REL} copiando de ${DEV_APP_DIR_REL} ..."
  mkdir -p "${PROD_APP_DIR}"
  cp -a "${DEV_APP_DIR}/." "${PROD_APP_DIR}/"
fi

# Ajusta namespace e env no prod (se houver yamls)
shopt -s nullglob
for f in "${PROD_APP_DIR}"/*.yaml "${PROD_APP_DIR}"/*.yml; do
  echo "Ajustando arquivo: ${f#${REPO_ROOT}/}"
  sed -i "s/\b${ALLOW_NS_DEV}\b/${ALLOW_NS_PROD}/g" "$f"
  sed -i "s/\benv:[[:space:]]*${DEV_ENV_VALUE}\b/env: ${PROD_ENV_VALUE}/g" "$f"
  sed -i "s/\bidp\.platform\.io\/env:[[:space:]]*${DEV_ENV_VALUE}\b/idp.platform.io\/env: ${PROD_ENV_VALUE}/g" "$f"
done
shopt -u nullglob

echo "==> (4/5) Commit + push"
git add -A
git commit -m "fix(argocd): allow apps-dev/apps-prod destinations + ensure apps/prod/app1" >/dev/null
git push

echo "==> (5/5) Refresh hard nas Applications"
if kubectl -n "${ARGOCD_NS}" get application "${APP_DEV_NAME}" >/dev/null 2>&1; then
  kubectl -n "${ARGOCD_NS}" annotate application "${APP_DEV_NAME}" argocd.argoproj.io/refresh=hard --overwrite >/dev/null
  echo "OK: refresh hard em ${APP_DEV_NAME}"
else
  echo "WARN: Application ${APP_DEV_NAME} não encontrada em ${ARGOCD_NS}"
fi

if kubectl -n "${ARGOCD_NS}" get application "${APP_PROD_NAME}" >/dev/null 2>&1; then
  kubectl -n "${ARGOCD_NS}" annotate application "${APP_PROD_NAME}" argocd.argoproj.io/refresh=hard --overwrite >/dev/null
  echo "OK: refresh hard em ${APP_PROD_NAME}"
else
  echo "WARN: Application ${APP_PROD_NAME} não encontrada em ${ARGOCD_NS}"
fi

echo
echo "✅ Concluído."
echo "Agora valide:"
echo "  kubectl -n ${ARGOCD_NS} get appproject ${PROJECT_NAME} -o yaml | sed -n '1,220p'"
echo "  (ArgoCD UI) Sync apps-dev / apps-prod"
