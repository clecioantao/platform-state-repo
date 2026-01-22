#!/usr/bin/env bash
set -euo pipefail

echo "==> Detectando raiz do git"
ROOT="$(git rev-parse --show-toplevel)"
cd "$ROOT"

for ENV in dev prod; do
  echo "==> Corrigindo envs/${ENV}/platform"

  ENV_DIR="envs/${ENV}"
  PLATFORM_DIR="${ENV_DIR}/platform"
  NS_SRC="${ENV_DIR}/namespace.yaml"
  NS_DST="${PLATFORM_DIR}/00-namespace.yaml"

  if [[ ! -d "$PLATFORM_DIR" ]]; then
    echo "ERRO: ${PLATFORM_DIR} não existe"
    exit 1
  fi

  # Move namespace.yaml para dentro do platform/
  if [[ -f "$NS_SRC" ]]; then
    echo " - Movendo namespace.yaml para ${PLATFORM_DIR}"
    mv "$NS_SRC" "$NS_DST"
  else
    echo " - namespace.yaml já não existe em ${ENV_DIR} (ok)"
  fi

  # Garante referência correta no kustomization.yaml
  KUSTOM="${PLATFORM_DIR}/kustomization.yaml"

  if [[ ! -f "$KUSTOM" ]]; then
    echo "ERRO: kustomization.yaml não encontrado em ${PLATFORM_DIR}"
    exit 1
  fi

  # Remove referências proibidas
  sed -i '/\.\.\/namespace.yaml/d' "$KUSTOM"

  # Garante inclusão correta
  if ! grep -q "00-namespace.yaml" "$KUSTOM"; then
    echo " - Inserindo 00-namespace.yaml em kustomization.yaml"
    sed -i '/resources:/a\  - 00-namespace.yaml' "$KUSTOM"
  fi
done

echo "==> Commitando correções"
git add envs/dev envs/prod
git commit -m "fix(kustomize): move namespace.yaml into platform dirs (dev/prod)"

git push

echo "==> Forçando refresh hard no ArgoCD"
kubectl -n argocd annotate application platform-dev argocd.argoproj.io/refresh=hard --overwrite || true
kubectl -n argocd annotate application platform-prod argocd.argoproj.io/refresh=hard --overwrite || true

echo "✅ Correção aplicada com sucesso"
echo "Agora valide:"
echo "  kubectl -n argocd get applications | egrep 'platform-dev|platform-prod'"
