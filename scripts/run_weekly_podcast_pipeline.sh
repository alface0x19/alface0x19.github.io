#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  scripts/run_weekly_podcast_pipeline.sh [--date YYYY-MM-DD] [--model model-name]
    [--writer-model model-name] [--dry-run] [--local-writer]

Description:
  Gera o brief semanal do podcast a partir dos posts recentes e cria um draft
  para posterior producao manual de audio no NotebookLM.
EOF
}

repo_root="$(git rev-parse --show-toplevel 2>/dev/null || true)"
if [[ -z "$repo_root" ]]; then
  echo "Este script tem de correr dentro de um repositorio git."
  exit 1
fi

cd "$repo_root"

source "$repo_root/scripts/lib/codex_cli.sh"

reference_date="$(date +%F)"
model=""
writer_model=""
dry_run="false"
local_writer="false"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --date)
      reference_date="$2"
      shift 2
      ;;
    --model)
      model="$2"
      shift 2
      ;;
    --writer-model)
      writer_model="$2"
      shift 2
      ;;
    --dry-run)
      dry_run="true"
      shift
      ;;
    --local-writer)
      local_writer="true"
      shift
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

ensure_codex_cli || exit 1

brief_path="$repo_root/_drafts/podcast-${reference_date}-brief.md"

python3 "$repo_root/scripts/build_weekly_podcast_brief.py" \
  --posts-dir "$repo_root/_posts" \
  --date "$reference_date" \
  --output "$brief_path"

read_meta() {
  python3 - "$brief_path" "$1" <<'PY'
from pathlib import Path
import re
import sys

path = Path(sys.argv[1])
key = sys.argv[2]
text = path.read_text(encoding="utf-8", errors="ignore")
match = re.search(r"^---\n(.*?)\n---\n", text, re.S)
data = {}
if match:
    for line in match.group(1).splitlines():
        if ":" not in line:
            continue
        left, right = line.split(":", 1)
        data[left.strip()] = right.strip().strip('"')
print(data.get(key, ""))
PY
}

episode_number="$(read_meta episode_number)"
episode_title="$(read_meta episode_title)"
episode_slug="$(read_meta episode_slug)"

if [[ -z "$episode_number" || -z "$episode_slug" ]]; then
  echo "Metadados insuficientes no brief: $brief_path" >&2
  exit 1
fi

draft_path="$repo_root/_drafts/${episode_slug}.md"
post_path="$repo_root/_posts/${episode_slug}.md"
audio_rel="/assets/audio/podcast/$(date -d "$reference_date" +%Y 2>/dev/null || date +%Y)/${episode_slug}.mp3"
audio_txt_path="$repo_root/assets/audio/podcast/$(date -d "$reference_date" +%Y 2>/dev/null || date +%Y)/${episode_slug}.txt"

cat > "$draft_path" <<EOF
---
layout: post
title: "${episode_title}"
date: ${reference_date}
categories:
  - podcast
podcast: true
episode_number: ${episode_number}
episode_title: "${episode_title}"
podcast_summary: ""
audio_url: ""
audio_type: audio/mpeg
audio_size: 0
audio_duration: ""
episode_type: full
explicit: "no"
---

## Neste episódio

- Placeholder

## Links

- Placeholder
EOF

if [[ "$dry_run" == "true" ]]; then
  echo "DRY_RUN: brief em $brief_path"
  echo "DRY_RUN: draft base em $draft_path"
  echo "DRY_RUN: txt NotebookLM em $audio_txt_path"
  exit 0
fi

selected_model="${writer_model:-${model:-gpt-5.4}}"
agent_prompt="$(cat <<EOF
Le o brief em $brief_path e edita apenas o draft em $draft_path.

Objetivo:
- transformar os temas da semana num episodio compacto e natural;
- escrever em formato de conversa entre dois amigos informados, com naturalidade e sem teatro;
- o Autor tem de soar como a persona que escreve os artigos deste blog;
- o Amigo tem de ser o contraponto que goza com hype, buzzwords e exageros do ecossistema sem faltar ao respeito e sem humor negro;
- preencher podcast_summary no front matter;
- substituir placeholders por conteudo real;
- deixar o draft pronto para publicacao no site, sem timestamps inventados e sem transcricao publica;
- usar os artigos indicados no brief como base principal.

A ultima linha nao vazia tem de ser exatamente:
PODCAST_DRAFT_WRITTEN: $draft_path
EOF
)"

if [[ "$local_writer" == "true" || "${PODCAST_WRITER_MODE:-}" == "local" ]]; then
  python3 "$repo_root/scripts/render_weekly_podcast_draft.py" --brief "$brief_path" --draft "$draft_path"
else
  run_codex_agent --repo-root "$repo_root" --agent "podcast-script-writer" --model "$selected_model" --prompt "$agent_prompt"
fi

python3 "$repo_root/scripts/export_notebooklm_podcast_txt.py" --draft "$draft_path" --output "$audio_txt_path"

echo "PODCAST_DRAFT_READY: $draft_path"
echo "NOTEBOOKLM_TXT_READY: $audio_txt_path"
echo "Proximo passo manual: importar o TXT no NotebookLM, gerar audio externo e preencher audio_url/audio_size/audio_duration antes de publicar."
