#!/usr/bin/env bash
set -euo pipefail

mkdir -p bootstrap/argocd/app-of-apps/apps

# Copia os filhos para dentro do app-of-apps (para kustomize não atravessar diretórios)
cp -f envs/dev/argocd-apps/platform-dev.yaml  bootstrap/argocd/app-of-apps/apps/platform-dev.yaml
cp -f envs/dev/argocd-apps/apps-dev.yaml      bootstrap/argocd/app-of-apps/apps/apps-dev.yaml
cp -f envs/prod/argocd-apps/platform-prod.yaml bootstrap/argocd/app-of-apps/apps/platform-prod.yaml
cp -f envs/prod/argocd-apps/apps-prod.yaml     bootstrap/argocd/app-of-apps/apps/apps-prod.yaml

# Atualiza o kustomization do app-of-apps para referenciar somente caminhos internos
cat > bootstrap/argocd/app-of-apps/kustomization.yaml <<'EOF'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - root-app.yaml
  - projects/platform-project.yaml
  - projects/apps-project.yaml

  # Child apps must be inside this directory tree (kustomize security)
  - apps/platform-dev.yaml
  - apps/apps-dev.yaml
  - apps/platform-prod.yaml
  - apps/apps-prod.yaml
EOF

echo "OK: child apps copied to bootstrap/argocd/app-of-apps/apps and kustomization updated."
