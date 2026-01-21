#!/usr/bin/env bash
set -euo pipefail

mkdir -p bootstrap/crossplane/providers bootstrap/crossplane/contract

# -----------------------------
# Provider: provider-kubernetes
# -----------------------------
cat > bootstrap/crossplane/providers/provider-kubernetes.yaml <<'YAML'
apiVersion: pkg.crossplane.io/v1
kind: Provider
metadata:
  name: provider-kubernetes
spec:
  package: xpkg.upbound.io/crossplane-contrib/provider-kubernetes:v0.14.0
YAML

# ProviderConfig: in-cluster
cat > bootstrap/crossplane/providers/providerconfig-incluster.yaml <<'YAML'
apiVersion: kubernetes.crossplane.io/v1alpha1
kind: ProviderConfig
metadata:
  name: incluster
spec:
  credentials:
    source: InjectedIdentity
YAML

# -----------------------------
# XRD: PostgresInstance
# -----------------------------
cat > bootstrap/crossplane/contract/xrd-postgresinstance.yaml <<'YAML'
apiVersion: apiextensions.crossplane.io/v1
kind: CompositeResourceDefinition
metadata:
  name: xpostgresinstances.idp.platform.io
spec:
  group: idp.platform.io
  names:
    kind: XPostgresInstance
    plural: xpostgresinstances
  claimNames:
    kind: PostgresInstance
    plural: postgresinstances
  versions:
    - name: v1alpha1
      served: true
      referenceable: true
      schema:
        openAPIV3Schema:
          type: object
          properties:
            spec:
              type: object
              required: ["parameters"]
              properties:
                parameters:
                  type: object
                  required: ["app", "env", "owner", "size"]
                  properties:
                    app:
                      type: string
                      minLength: 2
                      maxLength: 63
                    env:
                      type: string
                      enum: ["dev", "prod"]
                    owner:
                      type: string
                      minLength: 2
                      maxLength: 63
                    size:
                      type: string
                      enum: ["small", "medium", "large"]
YAML

# -----------------------------
# XRD: RedisInstance
# -----------------------------
cat > bootstrap/crossplane/contract/xrd-redisinstance.yaml <<'YAML'
apiVersion: apiextensions.crossplane.io/v1
kind: CompositeResourceDefinition
metadata:
  name: xredisinstances.idp.platform.io
spec:
  group: idp.platform.io
  names:
    kind: XRedisInstance
    plural: xredisinstances
  claimNames:
    kind: RedisInstance
    plural: redisinstances
  versions:
    - name: v1alpha1
      served: true
      referenceable: true
      schema:
        openAPIV3Schema:
          type: object
          properties:
            spec:
              type: object
              required: ["parameters"]
              properties:
                parameters:
                  type: object
                  required: ["app", "env", "owner", "size"]
                  properties:
                    app:
                      type: string
                      minLength: 2
                      maxLength: 63
                    env:
                      type: string
                      enum: ["dev", "prod"]
                    owner:
                      type: string
                      minLength: 2
                      maxLength: 63
                    size:
                      type: string
                      enum: ["small", "medium", "large"]
YAML

# ----------------------------------------------------------
# Composition DEV: Postgres (in-cluster)
# ----------------------------------------------------------
cat > bootstrap/crossplane/contract/composition-dev-postgres.yaml <<'YAML'
apiVersion: apiextensions.crossplane.io/v1
kind: Composition
metadata:
  name: postgres-dev
  labels:
    idp.platform.io/env: dev
spec:
  compositeTypeRef:
    apiVersion: idp.platform.io/v1alpha1
    kind: XPostgresInstance

  resources:
    - name: postgres-secret
      base:
        apiVersion: kubernetes.crossplane.io/v1alpha2
        kind: Object
        spec:
          providerConfigRef:
            name: incluster
          forProvider:
            manifest:
              apiVersion: v1
              kind: Secret
              metadata:
                name: postgres-credentials
                namespace: pe-dev
                labels: {}
              type: Opaque
              stringData:
                POSTGRES_DB: appdb
                POSTGRES_USER: appuser
                POSTGRES_PASSWORD: changeme
      patches:
        - fromFieldPath: "spec.parameters.app"
          toFieldPath: "spec.forProvider.manifest.metadata.labels.idp.platform.io/app"
        - fromFieldPath: "spec.parameters.env"
          toFieldPath: "spec.forProvider.manifest.metadata.labels.idp.platform.io/env"
        - fromFieldPath: "spec.parameters.owner"
          toFieldPath: "spec.forProvider.manifest.metadata.labels.idp.platform.io/owner"

    - name: postgres-service
      base:
        apiVersion: kubernetes.crossplane.io/v1alpha2
        kind: Object
        spec:
          providerConfigRef:
            name: incluster
          forProvider:
            manifest:
              apiVersion: v1
              kind: Service
              metadata:
                name: postgres
                namespace: pe-dev
                labels: {}
              spec:
                ports:
                  - name: tcp
                    port: 5432
                    targetPort: 5432
                selector:
                  app: postgres
      patches:
        - fromFieldPath: "spec.parameters.app"
          toFieldPath: "spec.forProvider.manifest.metadata.labels.idp.platform.io/app"
        - fromFieldPath: "spec.parameters.env"
          toFieldPath: "spec.forProvider.manifest.metadata.labels.idp.platform.io/env"
        - fromFieldPath: "spec.parameters.owner"
          toFieldPath: "spec.forProvider.manifest.metadata.labels.idp.platform.io/owner"

    - name: postgres-statefulset
      base:
        apiVersion: kubernetes.crossplane.io/v1alpha2
        kind: Object
        spec:
          providerConfigRef:
            name: incluster
          forProvider:
            manifest:
              apiVersion: apps/v1
              kind: StatefulSet
              metadata:
                name: postgres
                namespace: pe-dev
                labels:
                  app: postgres
              spec:
                serviceName: postgres
                replicas: 1
                selector:
                  matchLabels:
                    app: postgres
                template:
                  metadata:
                    labels:
                      app: postgres
                  spec:
                    containers:
                      - name: postgres
                        image: postgres:16
                        ports:
                          - containerPort: 5432
                        env:
                          - name: POSTGRES_DB
                            valueFrom:
                              secretKeyRef:
                                name: postgres-credentials
                                key: POSTGRES_DB
                          - name: POSTGRES_USER
                            valueFrom:
                              secretKeyRef:
                                name: postgres-credentials
                                key: POSTGRES_USER
                          - name: POSTGRES_PASSWORD
                            valueFrom:
                              secretKeyRef:
                                name: postgres-credentials
                                key: POSTGRES_PASSWORD
                        volumeMounts:
                          - name: data
                            mountPath: /var/lib/postgresql/data
                volumeClaimTemplates:
                  - metadata:
                      name: data
                    spec:
                      accessModes: ["ReadWriteOnce"]
                      resources:
                        requests:
                          storage: 1Gi
      patches:
        - fromFieldPath: "spec.parameters.app"
          toFieldPath: "spec.forProvider.manifest.metadata.labels.idp.platform.io/app"
        - fromFieldPath: "spec.parameters.env"
          toFieldPath: "spec.forProvider.manifest.metadata.labels.idp.platform.io/env"
        - fromFieldPath: "spec.parameters.owner"
          toFieldPath: "spec.forProvider.manifest.metadata.labels.idp.platform.io/owner"
YAML

# ----------------------------------------------------------
# Composition DEV: Redis (in-cluster)
# ----------------------------------------------------------
cat > bootstrap/crossplane/contract/composition-dev-redis.yaml <<'YAML'
apiVersion: apiextensions.crossplane.io/v1
kind: Composition
metadata:
  name: redis-dev
  labels:
    idp.platform.io/env: dev
spec:
  compositeTypeRef:
    apiVersion: idp.platform.io/v1alpha1
    kind: XRedisInstance

  resources:
    - name: redis-service
      base:
        apiVersion: kubernetes.crossplane.io/v1alpha2
        kind: Object
        spec:
          providerConfigRef:
            name: incluster
          forProvider:
            manifest:
              apiVersion: v1
              kind: Service
              metadata:
                name: redis
                namespace: pe-dev
                labels: {}
              spec:
                ports:
                  - name: tcp
                    port: 6379
                    targetPort: 6379
                selector:
                  app: redis
      patches:
        - fromFieldPath: "spec.parameters.app"
          toFieldPath: "spec.forProvider.manifest.metadata.labels.idp.platform.io/app"
        - fromFieldPath: "spec.parameters.env"
          toFieldPath: "spec.forProvider.manifest.metadata.labels.idp.platform.io/env"
        - fromFieldPath: "spec.parameters.owner"
          toFieldPath: "spec.forProvider.manifest.metadata.labels.idp.platform.io/owner"

    - name: redis-deploy
      base:
        apiVersion: kubernetes.crossplane.io/v1alpha2
        kind: Object
        spec:
          providerConfigRef:
            name: incluster
          forProvider:
            manifest:
              apiVersion: apps/v1
              kind: Deployment
              metadata:
                name: redis
                namespace: pe-dev
                labels:
                  app: redis
              spec:
                replicas: 1
                selector:
                  matchLabels:
                    app: redis
                template:
                  metadata:
                    labels:
                      app: redis
                  spec:
                    containers:
                      - name: redis
                        image: redis:7-alpine
                        ports:
                          - containerPort: 6379
      patches:
        - fromFieldPath: "spec.parameters.app"
          toFieldPath: "spec.forProvider.manifest.metadata.labels.idp.platform.io/app"
        - fromFieldPath: "spec.parameters.env"
          toFieldPath: "spec.forProvider.manifest.metadata.labels.idp.platform.io/env"
        - fromFieldPath: "spec.parameters.owner"
          toFieldPath: "spec.forProvider.manifest.metadata.labels.idp.platform.io/owner"
YAML

# ----------------------------------------------------------
# PROD blocked compositions (Phase 1)
# ----------------------------------------------------------
cat > bootstrap/crossplane/contract/composition-prod-blocked-postgres.yaml <<'YAML'
apiVersion: apiextensions.crossplane.io/v1
kind: Composition
metadata:
  name: postgres-prod-blocked
  labels:
    idp.platform.io/env: prod
spec:
  compositeTypeRef:
    apiVersion: idp.platform.io/v1alpha1
    kind: XPostgresInstance
  # Phase 1: intentionally no resources. PROD is a contract only.
YAML

cat > bootstrap/crossplane/contract/composition-prod-blocked-redis.yaml <<'YAML'
apiVersion: apiextensions.crossplane.io/v1
kind: Composition
metadata:
  name: redis-prod-blocked
  labels:
    idp.platform.io/env: prod
spec:
  compositeTypeRef:
    apiVersion: idp.platform.io/v1alpha1
    kind: XRedisInstance
  # Phase 1: intentionally no resources. PROD is a contract only.
YAML

# ----------------------------------------------------------
# Wire contract into envs/*/platform kustomizations
# NOTE: these paths stay within repo, but will be processed by Argo in env folders.
# ----------------------------------------------------------
cat > envs/dev/platform/kustomization.yaml <<'YAML'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - ../namespace.yaml
  - platform-marker.yaml

  - ../../../bootstrap/crossplane/providers/provider-kubernetes.yaml
  - ../../../bootstrap/crossplane/providers/providerconfig-incluster.yaml

  - ../../../bootstrap/crossplane/contract/xrd-postgresinstance.yaml
  - ../../../bootstrap/crossplane/contract/xrd-redisinstance.yaml

  - ../../../bootstrap/crossplane/contract/composition-dev-postgres.yaml
  - ../../../bootstrap/crossplane/contract/composition-dev-redis.yaml
YAML

cat > envs/prod/platform/kustomization.yaml <<'YAML'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - ../namespace.yaml
  - platform-marker.yaml

  - ../../../bootstrap/crossplane/providers/provider-kubernetes.yaml
  - ../../../bootstrap/crossplane/providers/providerconfig-incluster.yaml

  - ../../../bootstrap/crossplane/contract/xrd-postgresinstance.yaml
  - ../../../bootstrap/crossplane/contract/xrd-redisinstance.yaml

  - ../../../bootstrap/crossplane/contract/composition-prod-blocked-postgres.yaml
  - ../../../bootstrap/crossplane/contract/composition-prod-blocked-redis.yaml
YAML

echo "OK: Step 5 created/updated (bootstrap/crossplane)."
