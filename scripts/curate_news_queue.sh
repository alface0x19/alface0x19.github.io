#!/usr/bin/env bash
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel 2>/dev/null || true)"
if [[ -z "$repo_root" ]]; then
  echo "Este script tem de correr dentro de um repositorio git."
  exit 1
fi

cd "$repo_root"

source "$repo_root/scripts/lib/codex_cli.sh"
ensure_codex_cli || exit 1

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
- antes de fechar a selecao, verifica em _posts/ se o blog ja tem um artigo sobre exatamente o mesmo tema, evento central ou CVE;
- se a noticia principal ja estiver coberta no blog, escolhe a melhor alternativa ainda nao coberta;
- sempre que houver material suficiente, escolhe tambem uma segunda noticia publicavel e claramente diferente da principal;
- a segunda escolha nao deve ser o mesmo CVE, o mesmo incidente, o mesmo vendor launch disfarçado, nem um tema quase igual;
- em noticias de IA, nao assumes que OpenAI representa a area inteira; tenta manter diversidade de vendors e subtemas quando houver opcoes boas;
- se todas as candidatas fortes ja estiverem cobertas, escreve selected: none e explica por que motivo;
- sugere 2 ou 3 alternativas, se existirem;
- justifica cada escolha em poucas linhas;
- se vires hype, ruido, falta de fontes ou pouca relevancia, diz isso;
- na primeira linha do ficheiro escreve exatamente: selected: news_queue/<ficheiro>.md
- na segunda linha do ficheiro escreve exatamente: selected_secondary: news_queue/<ficheiro>.md ou selected_secondary: none
- se nenhuma noticia servir, escreve: selected: none
No fim, grava mesmo o ficheiro news_queue/SHORTLIST.md.
EOF
)

run_codex_agent \
  --repo-root "$repo_root" \
  --agent news-curator \
  --prompt "$prompt"

echo "Curadoria atualizada em news_queue/SHORTLIST.md"
