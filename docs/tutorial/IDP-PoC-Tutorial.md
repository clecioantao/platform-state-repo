# IDP PoC – Tutorial Passo a Passo (até o momento)

> Objetivo: construir uma PoC local e replicável de IDP usando:
> - Backstage (local) → gera GitOps
> - GitHub → fonte única da verdade
> - Argo CD (cluster) → aplica manifests via GitOps
> - Crossplane (cluster) → contrato e provisionamento (ainda não instalado)

---

## 0) Pré-requisitos

### Ferramentas locais
- kind
- kubectl
- helm
- git

### Repositório Git
- Repo: `https://github.com/clecioantao/platform-state-repo`

### Token GitHub
- Variável de ambiente:
  - `GITHUB_TOKEN` (com acesso ao repo)

---

## 1) Criar o cluster Kubernetes local (Kind)

### 1.1 Arquivo de configuração do Kind
Arquivo: `kind/platform-kind-config.yaml`

Exemplo usado:

```yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
  image: kindest/node:v1.30.2
  kubeadmConfigPatches:
  - |
    kind: InitConfiguration
    nodeRegistration:
      kubeletExtraArgs:
        node-labels: "ingress-ready=true"
  extraPortMappings:
  - containerPort: 80
    hostPort: 8080
    protocol: TCP
  - containerPort: 443
    hostPort: 8443
    protocol: TCP
- role: worker
  image: kindest/node:v1.30.2
- role: worker
  image: kindest/node:v1.30.2
