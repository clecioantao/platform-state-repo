#!/usr/bin/env bash
set -euo pipefail

# ==========================================================
# fix-state-repo-apps.sh
#
# Limpa arquivos NÃO-Kubernetes do path monitorado pelo ArgoCD:
# - remove catalog-info.yaml (Backstage Catalog)
# - remove kustomization.yaml (kustomize file, não CRD)
# - "achata" pastas out/ geradas por templates antigos
#
# Uso:
#   ./fix-state-repo-apps.sh
#
# Para commitar automaticamente:
#   COMMIT=1 ./fix-state-repo-apps.sh
# ==========================================================

ROOT_DIR="${1:-.}"
APPS_DIRS=("apps/dev" "apps/prod")

cd "$ROOT_DIR"

if [[ ! -d ".git" ]]; then
  echo "ERRO: rode esse script dentro do repo git (platform-state-repo)."
  exit 1
fi

echo "==> Repo: $(git rev-parse --show-toplevel)"
echo "==> Branch atual: $(git rev-parse --abbrev-ref HEAD)"
echo

removed_files=()
moved_out_dirs=()
fixed_empty_env=()

# ---------- Funções ----------
remove_if_exists() {
  local f="$1"
  if [[ -f "$f" ]]; then
    rm -f "$f"
    removed_files+=("$f")
  fi
}

flatten_out_dir() {
  local appdir="$1"
  local outdir="$appdir/out"
  if [[ -d "$outdir" ]]; then
    # move conteúdo do out/ para raiz do app
    shopt -s dotglob nullglob
    local items=("$outdir"/*)
    shopt -u dotglob

    if (( ${#items[@]} > 0 )); then
      mkdir -p "$appdir"
      for it in "${items[@]}"; do
        # se já existir destino, não sobrescreve; adiciona sufixo
        base="$(basename "$it")"
        dest="$appdir/$base"
        if [[ -e "$dest" ]]; then
          dest="$appdir/${base}.from_out"
        fi
        mv "$it" "$dest"
      done
    fi

    rm -rf "$outdir"
    moved_out_dirs+=("$outdir")
  fi
}

fix_empty_env_annotations() {
  # Corrige linhas "idp.platform.io/env:" sem valor em YAMLs de apps/dev|prod
  # (isso quebra rastreamento/annotations em algumas integrações)
  local file="$1"
  if grep -qE 'idp\.platform\.io/env:\s*$' "$file"; then
    # tenta inferir dev/prod pelo caminho
    local env=""
    if [[ "$file" == apps/dev/* ]]; then
      env="dev"
    elif [[ "$file" == apps/prod/* ]]; then
      env="prod"
    fi

    if [[ -n "$env" ]]; then
      # substitui apenas a linha vazia
      # mantém identação
      sed -i -E "s@(idp\.platform\.io/env:)\s*\$@\1 ${env}@g" "$file"
      fixed_empty_env+=("$file")
    fi
  fi
}

# ---------- Execução ----------
echo "==> 1) Limpando catalog-info.yaml e kustomization.yaml dentro de apps/dev e apps/prod"
for dir in "${APPS_DIRS[@]}"; do
  if [[ -d "$dir" ]]; then
    while IFS= read -r -d '' f; do
      remove_if_exists "$f"
    done < <(find "$dir" -type f -name 'catalog-info.yaml' -print0)

    while IFS= read -r -d '' f; do
      remove_if_exists "$f"
    done < <(find "$dir" -type f -name 'kustomization.yaml' -print0)
  fi
done

echo "==> 2) Achatando pastas out/ (move conteúdo pra raiz do app e remove out/)"
for dir in "${APPS_DIRS[@]}"; do
  if [[ -d "$dir" ]]; then
    # considera "apps/dev/<app>" e "apps/prod/<app>"
    while IFS= read -r -d '' app; do
      flatten_out_dir "$app"
    done < <(find "$dir" -mindepth 1 -maxdepth 1 -type d -print0)
  fi
done

echo "==> 3) Corrigindo annotations idp.platform.io/env vazias (se existirem)"
for dir in "${APPS_DIRS[@]}"; do
  if [[ -d "$dir" ]]; then
    while IFS= read -r -d '' f; do
      fix_empty_env_annotations "$f"
    done < <(find "$dir" -type f \( -name '*.yaml' -o -name '*.yml' \) -print0)
  fi
done

echo
echo "==> Resumo:"
echo " - Removidos: ${#removed_files[@]}"
for f in "${removed_files[@]}"; do echo "   - $f"; done

echo " - out/ removidos: ${#moved_out_dirs[@]}"
for d in "${moved_out_dirs[@]}"; do echo "   - $d"; done

echo " - env vazios corrigidos: ${#fixed_empty_env[@]}"
for f in "${fixed_empty_env[@]}"; do echo "   - $f"; done

echo
echo "==> Status do git:"
git status --porcelain || true

# Commit opcional
if [[ "${COMMIT:-0}" == "1" ]]; then
  if [[ -n "$(git status --porcelain)" ]]; then
    git add -A
    git commit -m "fix(gitops): remove non-k8s files from apps/* and flatten out/"
    echo
    echo "==> Commit criado."
  else
    echo "==> Nada para commitar."
  fi
else
  echo
  echo "Dica: para commitar automaticamente, rode:"
  echo "  COMMIT=1 ./fix-state-repo-apps.sh"
fi

echo
echo "==> Próximo passo: no ArgoCD, clique SYNC em apps-dev/apps-prod e verifique se SyncError desaparece."
