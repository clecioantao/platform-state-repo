#!/usr/bin/env bash
set -euo pipefail

mkdir -p docs/decisions

touch docs/README.md
touch docs/00-overview.md
touch docs/01-architecture.md
touch docs/02-gitops-flow.md
touch docs/03-repository-structure.md
touch docs/04-bootstrap-argo.md
touch docs/05-bootstrap-gitops.md
touch docs/06-crossplane-contract.md

touch docs/decisions/0001-why-app-of-apps.md
touch docs/decisions/0002-why-crossplane.md
touch docs/decisions/0003-prod-strategy.md

echo "Documentation skeleton created."
