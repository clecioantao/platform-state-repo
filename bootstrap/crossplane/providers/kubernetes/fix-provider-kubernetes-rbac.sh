#!/usr/bin/env bash
set -euo pipefail

echo "==> Corrigindo RBAC do provider-kubernetes (Crossplane)"

NAMESPACE="crossplane-system"
SA_NAME="provider-kubernetes"
CLUSTERROLE_NAME="crossplane-provider-kubernetes"
BINDING_NAME="crossplane-provider-kubernetes"

echo "==> Criando ServiceAccount"
kubectl apply -f - <<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: ${SA_NAME}
  namespace: ${NAMESPACE}
EOF

echo "==> Criando ClusterRole"
kubectl apply -f - <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: ${CLUSTERROLE_NAME}
rules:
- apiGroups: ["", "apps"]
  resources:
    - pods
    - services
    - secrets
    - configmaps
    - deployments
    - statefulsets
    - persistentvolumeclaims
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
EOF

echo "==> Criando ClusterRoleBinding"
kubectl apply -f - <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: ${BINDING_NAME}
subjects:
- kind: ServiceAccount
  name: ${SA_NAME}
  namespace: ${NAMESPACE}
roleRef:
  kind: ClusterRole
  name: ${CLUSTERROLE_NAME}
  apiGroup: rbac.authorization.k8s.io
EOF

echo "==> Reiniciando provider-kubernetes"
kubectl -n ${NAMESPACE} rollout restart deployment \
  -l pkg.crossplane.io/provider=provider-kubernetes

echo "==> RBAC aplicado com sucesso ✅"
