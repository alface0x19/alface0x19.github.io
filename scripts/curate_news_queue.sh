#!/usr/bin/env bash
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel 2>/dev/null || true)"
if [[ -z "$repo_root" ]]; then
  echo "Este script tem de correr dentro de um repositorio git."
  exit 1
fi

cd "$repo_root"

if ! command -v copilot >/dev/null 2>&1; then
  echo "copilot CLI nao encontrado no PATH."
  exit 1
fi

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

prompt=$(
  cat <<EOF
Lê os ficheiros Markdown em news_queue/ e faz triagem editorial usando o agente curador deste repositorio.
Cria ou atualiza o ficheiro news_queue/SHORTLIST.md.
Regras:
- escolhe a noticia mais relevante para virar artigo;
- sugere 2 ou 3 alternativas, se existirem;
- justifica cada escolha em poucas linhas;
- se vires hype, ruido, falta de fontes ou pouca relevancia, diz isso;
- na primeira linha do ficheiro escreve exatamente: selected: news_queue/<ficheiro>.md
- se nenhuma noticia servir, escreve: selected: none
No fim, grava mesmo o ficheiro news_queue/SHORTLIST.md.
EOF
)

copilot \
  -s \
  --allow-all-tools \
  --add-dir "$repo_root" \
  --no-ask-user \
  --agent=news-curator \
  --prompt "$prompt"

echo "Curadoria atualizada em news_queue/SHORTLIST.md"
