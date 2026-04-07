#!/usr/bin/env bash
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel 2>/dev/null || true)"
if [[ -z "$repo_root" ]]; then
  echo "Este script tem de correr dentro de um repositorio git."
  exit 1
fi

cd "$repo_root"

shopt -s nullglob
queue_files=(news_queue/*.md)
shopt -u nullglob

filtered_files=()
for file in "${queue_files[@]}"; do
  if [[ "$(basename "$file")" == "README.md" || "$(basename "$file")" == "SHORTLIST.md" ]]; then
    continue
  fi
  filtered_files+=("$file")
done

if [[ ${#filtered_files[@]} -eq 0 ]]; then
  echo "Nao ha noticias na fila para curadoria."
  exit 0
fi

python3 "$repo_root/scripts/select_news_queue.py" \
  --queue-dir "$repo_root/news_queue" \
  --posts-dir "$repo_root/_posts" \
  --output "$repo_root/news_queue/SHORTLIST.md"

echo "Curadoria atualizada em news_queue/SHORTLIST.md"

