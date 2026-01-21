#!/usr/bin/env bash
set -euo pipefail

REPO_URL="https://github.com/<org>/platform-state-repo.git"
REVISION="main"

write_file () {
  local path="$1"
  shift
  mkdir -p "$(dirname "$path")"
  cat > "$path" <<EOF
$*
EOF
}

echo "==> Updating Argo CD App-of-Apps structure..."

# 1) bootstrap/argocd/app-of-apps/kustomization.yaml
write_file "bootstrap/argocd/app-of-apps/kustomization.yaml" \
"apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - root-app.yaml
  - projects/platform-project.yaml
  - projects/apps-project.yaml

  # Child apps (environments)
  - ../../../envs/dev/argocd-apps/platform-dev.yaml
  - ../../../envs/dev/argocd-apps/apps-dev.yaml
  - ../../../envs/prod/argocd-apps/platform-prod.yaml
  - ../../../envs/prod/argocd-apps/apps-prod.yaml
"

# 2) envs/dev/argocd-apps/platform-dev.yaml
write_file "envs/dev/argocd-apps/platform-dev.yaml" \
"apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: platform-dev
  namespace: argocd
  labels:
    idp.platform.io/env: dev
spec:
  project: platform
  source:
    repoURL: ${REPO_URL}
    targetRevision: ${REVISION}
    path: envs/dev/platform
  destination:
    server: https://kubernetes.default.svc
    namespace: pe-dev
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
"

# 3) envs/dev/argocd-apps/apps-dev.yaml
write_file "envs/dev/argocd-apps/apps-dev.yaml" \
"apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: apps-dev
  namespace: argocd
  labels:
    idp.platform.io/env: dev
spec:
  project: apps
  source:
    repoURL: ${REPO_URL}
    targetRevision: ${REVISION}
    path: apps/dev
    directory:
      recurse: true
  destination:
    server: https://kubernetes.default.svc
    namespace: pe-dev
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
"

# 4) envs/prod/argocd-apps/platform-prod.yaml
write_file "envs/prod/argocd-apps/platform-prod.yaml" \
"apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: platform-prod
  namespace: argocd
  labels:
    idp.platform.io/env: prod
spec:
  project: platform
  source:
    repoURL: ${REPO_URL}
    targetRevision: ${REVISION}
    path: envs/prod/platform
  destination:
    server: https://kubernetes.default.svc
    namespace: pe-prod
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
"

# 5) envs/prod/argocd-apps/apps-prod.yaml
write_file "envs/prod/argocd-apps/apps-prod.yaml" \
"apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: apps-prod
  namespace: argocd
  labels:
    idp.platform.io/env: prod
spec:
  project: apps
  source:
    repoURL: ${REPO_URL}
    targetRevision: ${REVISION}
    path: apps/prod
    directory:
      recurse: true
  destination:
    server: https://kubernetes.default.svc
    namespace: pe-prod
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
"

# 6) envs/dev/platform/kustomization.yaml + placeholder
write_file "envs/dev/platform/kustomization.yaml" \
"apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - ../namespace.yaml
  - platform-marker.yaml
  # Step 2 vai adicionar: Crossplane contract (XRD/Compositions) e ProviderConfig(s)
"

write_file "envs/dev/platform/platform-marker.yaml" \
"apiVersion: v1
kind: ConfigMap
metadata:
  name: platform-dev-marker
  namespace: pe-dev
  labels:
    idp.platform.io/env: dev
data:
  message: \"platform-dev is being managed by Argo CD (Step 1). Crossplane contract comes in Step 2.\"
"

# 7) envs/prod/platform/kustomization.yaml + placeholder
write_file "envs/prod/platform/kustomization.yaml" \
"apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - ../namespace.yaml
  - platform-marker.yaml
  # Step 2 vai adicionar: Crossplane contract (XRD/Compositions) e política PROD (bloqueado)
"

write_file "envs/prod/platform/platform-marker.yaml" \
"apiVersion: v1
kind: ConfigMap
metadata:
  name: platform-prod-marker
  namespace: pe-prod
  labels:
    idp.platform.io/env: prod
data:
  message: \"platform-prod is being managed by Argo CD (Step 1). Crossplane contract comes in Step 2.\"
"

echo "==> Done."
echo
echo "Next:"
echo "  1) git status"
echo "  2) git add -A && git commit -m \"step1: argo apps-of-apps for dev/prod\""
echo "  3) git push"
