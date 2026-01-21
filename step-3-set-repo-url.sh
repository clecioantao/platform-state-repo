#!/usr/bin/env bash
set -euo pipefail

REPO_URL="https://github.com/clecioantao/platform-state-repo.git"
REVISION="main"

# Substitui placeholders em todos os YAMLs do Argo
# (root-app e env apps)
FILES=(
  "bootstrap/argocd/app-of-apps/root-app.yaml"
  "envs/dev/argocd-apps/platform-dev.yaml"
  "envs/dev/argocd-apps/apps-dev.yaml"
  "envs/prod/argocd-apps/platform-prod.yaml"
  "envs/prod/argocd-apps/apps-prod.yaml"
)

for f in "${FILES[@]}"; do
  if [[ -f "$f" ]]; then
    sed -i "s|repoURL: .*platform-state-repo.git|repoURL: ${REPO_URL}|g" "$f" || true
    # garante targetRevision
    sed -i "s|targetRevision: .*|targetRevision: ${REVISION}|g" "$f" || true
  fi
done

echo "Updated repoURL/targetRevision in Argo Application manifests."
