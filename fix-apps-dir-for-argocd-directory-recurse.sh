#!/usr/bin/env bash
set -euo pipefail

ROOT="$(pwd)"
APPS_DIR="${ROOT}/apps"
CATALOG_DIR="${ROOT}/backstage/catalog/apps"

if [[ ! -d "${APPS_DIR}" ]]; then
  echo "ERRO: diretório ./apps não encontrado. Rode na raiz do platform-state-repo."
  exit 1
fi

echo "==> 1) Garantindo diretórios de catálogo (Backstage) fora de apps/*"
mkdir -p "${CATALOG_DIR}/dev" "${CATALOG_DIR}/prod"

echo "==> 2) Movendo catalog-info.yaml (Backstage) para backstage/catalog/apps/<env>/<app>/"
# move apps/<env>/<app>/catalog-info.yaml -> backstage/catalog/apps/<env>/<app>/catalog-info.yaml
find "${APPS_DIR}" -type f -name "catalog-info.yaml" | while read -r f; do
  # tenta extrair env e app pelo path: apps/<env>/<app>/catalog-info.yaml
  rel="${f#${APPS_DIR}/}"          # dev/novo-teste-001/catalog-info.yaml
  env="${rel%%/*}"                 # dev
  rest="${rel#*/}"                 # novo-teste-001/catalog-info.yaml
  app="${rest%%/*}"                # novo-teste-001

  # se não bater o padrão, joga num "misc"
  if [[ "${env}" != "dev" && "${env}" != "prod" ]]; then
    env="misc"
    app="misc"
    mkdir -p "${CATALOG_DIR}/${env}/${app}"
  else
    mkdir -p "${CATALOG_DIR}/${env}/${app}"
  fi

  dest="${CATALOG_DIR}/${env}/${app}/catalog-info.yaml"
  echo "  - MOVENDO: ${f} -> ${dest}"
  mv -f "${f}" "${dest}"
done

echo "==> 3) Removendo YAMLs que são Kustomization (kustomize.config.k8s.io) de dentro de apps/*"
# Esses arquivos quebram seu Application (Directory+recurse), porque o Argo tenta aplicar como recurso K8s
find "${APPS_DIR}" -type f \( -name "*.yaml" -o -name "*.yml" \) | while read -r f; do
  if grep -qE '^[[:space:]]*apiVersion:[[:space:]]*kustomize\.config\.k8s\.io/' "${f}" \
     && grep -qE '^[[:space:]]*kind:[[:space:]]*Kustomization' "${f}"; then
    echo "  - REMOVENDO (Kustomization CR): ${f}"
    rm -f "${f}"
  fi
done

echo "==> 4) Limpando diretórios residuais (out/ e skeleton-gitops/) dentro de apps/* (se existirem)"
# 4.1) Se tiver apps/<env>/<app>/out/**, move conteúdo para apps/<env>/<app>/ e remove out/
find "${APPS_DIR}" -type d -name "out" | while read -r d; do
  parent="$(dirname "${d}")"
  echo "  - ACHATANDO: ${d} -> ${parent}"
  shopt -s dotglob nullglob
  for item in "${d}"/*; do
    # evita sobrescrever sem querer
    base="$(basename "${item}")"
    if [[ -e "${parent}/${base}" ]]; then
      echo "    * SKIP (já existe): ${parent}/${base}"
    else
      mv "${item}" "${parent}/"
    fi
  done
  shopt -u dotglob nullglob
  rmdir "${d}" 2>/dev/null || true
done

# 4.2) Se tiver apps/<env>/<app>/skeleton-gitops/**, move conteúdo para apps/<env>/<app>/gitops/ (ou root) e remove skeleton-gitops
find "${APPS_DIR}" -type d -name "skeleton-gitops" | while read -r d; do
  parent="$(dirname "${d}")"
  mkdir -p "${parent}/gitops"
  echo "  - MIGRANDO: ${d} -> ${parent}/gitops"
  shopt -s dotglob nullglob
  for item in "${d}"/*; do
    base="$(basename "${item}")"
    if [[ -e "${parent}/gitops/${base}" ]]; then
      echo "    * SKIP (já existe): ${parent}/gitops/${base}"
    else
      mv "${item}" "${parent}/gitops/"
    fi
  done
  shopt -u dotglob nullglob
  rm -rf "${d}"
done

echo "==> 5) Verificando annotation env vazia dentro de apps/*"
if grep -RIn --exclude-dir=.git -E 'idp\.platform\.io/env:[[:space:]]*$' "${APPS_DIR}" >/dev/null 2>&1; then
  echo "ATENÇÃO: encontrei 'idp.platform.io/env:' vazio em:"
  grep -RIn --exclude-dir=.git -E 'idp\.platform\.io/env:[[:space:]]*$' "${APPS_DIR}" || true
  echo "Corrija esses arquivos (env precisa ser string dev|prod)."
else
  echo "OK: não existe 'idp.platform.io/env:' vazio em apps/*"
fi

echo "==> 6) Resumo do que ficou em apps/dev (arquivos YAML/YML)"
find "${APPS_DIR}/dev" -type f \( -name "*.yaml" -o -name "*.yml" \) | sed "s#^${ROOT}/##" | sort || true

echo
echo "DONE ✅"
echo "Próximos passos:"
echo "  1) git status"
echo "  2) git add -A && git commit -m 'fix(gitops): remove non-k8s yaml from apps/* and move catalog to backstage/'"
echo "  3) git push"
