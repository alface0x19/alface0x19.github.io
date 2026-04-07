#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  scripts/run_news_autopilot.sh [--model model-name]
    [--writer-model model-name] [--editor-model model-name] [--angle-model model-name]
    [--image-model model-name] [--gate-model model-name]

Description:
  Recolhe noticias, faz curadoria, gera artigo, valida e publica automaticamente
  se o fluxo considerar o artigo pronto.
EOF
}

repo_root="$(git rev-parse --show-toplevel 2>/dev/null || true)"
if [[ -z "$repo_root" ]]; then
  echo "Este script tem de correr dentro de um repositorio git."
  exit 1
fi

cd "$repo_root"

source "$repo_root/scripts/lib/codex_cli.sh"
ensure_codex_cli || exit 1

model=""
writer_model=""
editor_model=""
angle_model=""
image_model=""
gate_model=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --model)
      model="$2"
      shift 2
      ;;
    --writer-model)
      writer_model="$2"
      shift 2
      ;;
    --editor-model)
      editor_model="$2"
      shift 2
      ;;
    --angle-model)
      angle_model="$2"
      shift 2
      ;;
    --image-model)
      image_model="$2"
      shift 2
      ;;
    --gate-model)
      gate_model="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Opcao desconhecida: $1"
      usage
      exit 1
      ;;
  esac
done

ensure_clean_start() {
  local status
  status="$(git status --short)"
  if [[ -n "$status" ]]; then
    echo "Repositorio com alteracoes pendentes. A automacao autonoma vai abortar para nao misturar trabalho manual com publicacao automatica."
    printf '%s\n' "$status"
    exit 0
  fi
}

selected_from_shortlist() {
  python3 - "$repo_root/news_queue/SHORTLIST.md" "$1" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
key = sys.argv[2]
if not path.exists():
    print("")
    raise SystemExit(0)

lines = path.read_text(encoding="utf-8", errors="ignore").splitlines()
for line in lines:
    line = line.strip()
    if not line.startswith(f"{key}:"):
        continue
    selected = line.split(":", 1)[1].strip()
    print("" if selected == "none" else selected)
    raise SystemExit(0)

print("")
PY
}

clear_dynamic_queue() {
  local queue_dir="$repo_root/news_queue"
  local removed_any="false"
  local queue_file

  shopt -s nullglob
  for queue_file in "$queue_dir"/*; do
    case "$(basename "$queue_file")" in
      README.md)
        continue
        ;;
    esac
    rm -f "$queue_file"
    removed_any="true"
  done
  shopt -u nullglob

  if [[ "$removed_any" == "true" ]]; then
    echo "Fila local limpa: removidos os ficheiros dinamicos de news_queue/."
  else
    echo "Fila local ja estava limpa."
  fi
}

clear_dynamic_drafts() {
  local drafts_dir="$repo_root/_drafts"
  local removed_any="false"
  local draft_file

  shopt -s nullglob
  for draft_file in "$drafts_dir"/*.md; do
    rm -f "$draft_file"
    removed_any="true"
  done
  shopt -u nullglob

  if [[ "$removed_any" == "true" ]]; then
    echo "Drafts temporarios removidos de _drafts/."
  else
    echo "Nao havia drafts temporarios para remover."
  fi
}

clear_python_cache() {
  local removed_any="false"
  local cache_dir

  while IFS= read -r cache_dir; do
    [[ -z "$cache_dir" ]] && continue
    rm -rf "$cache_dir"
    removed_any="true"
  done < <(find "$repo_root/scripts" -type d -name __pycache__ -print 2>/dev/null || true)

  if [[ "$removed_any" == "true" ]]; then
    echo "Caches Python temporarias removidas."
  else
    echo "Nao havia caches Python temporarias para remover."
  fi
}

clear_temporary_artifacts() {
  clear_dynamic_queue
  clear_dynamic_drafts
  clear_python_cache
}

validate_clean_finish() {
  local status
  local branch_status
  local queue_file

  status="$(git status --short)"
  if [[ -n "$status" ]]; then
    echo "Worktree nao ficou limpa no fim do autopilot:"
    printf '%s\n' "$status"
    return 1
  fi

  branch_status="$(git status --short --branch | head -n 1)"
  if [[ "$branch_status" == *"[ahead "* || "$branch_status" == *"[behind "* || "$branch_status" == *"[diverged "* ]]; then
    echo "A branch nao ficou sincronizada com origin/main no fim do autopilot: $branch_status"
    return 1
  fi

  shopt -s nullglob
  for queue_file in "$repo_root"/news_queue/*; do
    case "$(basename "$queue_file")" in
      README.md)
        continue
        ;;
      *)
        echo "A fila local nao foi totalmente limpa: ${queue_file#$repo_root/}"
        shopt -u nullglob
        return 1
        ;;
    esac
  done
  shopt -u nullglob

  shopt -s nullglob
  for queue_file in "$repo_root"/_drafts/*.md; do
    echo "Ainda existem drafts temporarios em _drafts/: ${queue_file#$repo_root/}"
    shopt -u nullglob
    return 1
  done
  shopt -u nullglob

  echo "Validacao final OK: worktree limpa, branch sincronizada, news_queue limpa e _drafts sem temporarios."
}

published_any="false"

cleanup_after_run() {
  local exit_code=$?
  local final_code=$exit_code

  trap - EXIT

  if [[ $exit_code -eq 0 && "$published_any" == "true" ]]; then
    echo "[4/5] Limpar temporarios locais"
  else
    echo "[cleanup] Limpar temporarios"
  fi
  if ! clear_temporary_artifacts; then
    final_code=1
  fi

  if [[ $exit_code -eq 0 && "$published_any" == "true" ]]; then
    echo "[5/5] Validar worktree final"
    if ! validate_clean_finish; then
      final_code=1
    fi
  fi

  exit "$final_code"
}

trap cleanup_after_run EXIT

ensure_clean_start

echo "Preparar temporarios locais"
clear_temporary_artifacts

echo "[1/4] Recolher noticias"
bash scripts/collect_news_queue.sh

echo "[2/4] Curar fila"
bash scripts/curate_news_queue.sh

selected_file="$(selected_from_shortlist selected)"
secondary_file="$(selected_from_shortlist selected_secondary)"
if [[ -z "$selected_file" ]]; then
  echo "Nenhuma noticia foi aprovada para artigo nesta ronda."
  exit 0
fi

if [[ ! -f "$repo_root/$selected_file" ]]; then
  echo "A shortlist aponta para um ficheiro inexistente: $selected_file"
  exit 1
fi

if [[ -n "$secondary_file" && ! -f "$repo_root/$secondary_file" ]]; then
  echo "A shortlist aponta para uma segunda noticia inexistente: $secondary_file"
  exit 1
fi

if [[ -n "$secondary_file" && "$secondary_file" == "$selected_file" ]]; then
  secondary_file=""
fi

publish_one() {
  local queue_file="$1"
  local label="$2"
  local pipeline_args=("$queue_file" --publish)

  echo "$label"
  if [[ -n "$model" ]]; then
    pipeline_args+=(--model "$model")
  fi
  if [[ -n "$writer_model" ]]; then
    pipeline_args+=(--writer-model "$writer_model")
  fi
  if [[ -n "$editor_model" ]]; then
    pipeline_args+=(--editor-model "$editor_model")
  fi
  if [[ -n "$angle_model" ]]; then
    pipeline_args+=(--angle-model "$angle_model")
  fi
  if [[ -n "$image_model" ]]; then
    pipeline_args+=(--image-model "$image_model")
  fi
  if [[ -n "$gate_model" ]]; then
    pipeline_args+=(--gate-model "$gate_model")
  fi
  bash scripts/run_codex_news_pipeline.sh "${pipeline_args[@]}"
  published_any="true"
}

echo "[3/4] Gerar, validar e publicar"
publish_one "$selected_file" "Publicar tema principal"
if [[ -n "$secondary_file" ]]; then
  publish_one "$secondary_file" "Publicar tema secundario"
fi

echo "Fluxo autonomo concluido."
