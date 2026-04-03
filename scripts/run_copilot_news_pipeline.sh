#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  scripts/run_copilot_news_pipeline.sh <queue-file> [--publish] [--date YYYY-MM-DD] [--slug custom-slug] [--model model-name]
  scripts/run_copilot_news_pipeline.sh --selected [--publish] [--date YYYY-MM-DD] [--slug custom-slug] [--model model-name]
  scripts/run_copilot_news_pipeline.sh --publish-draft _drafts/YYYY-MM-DD-slug.md [--model model-name]

Examples:
  scripts/run_copilot_news_pipeline.sh news_queue/2026-04-02-sample.md
  scripts/run_copilot_news_pipeline.sh news_queue/2026-04-02-sample.md --publish
  scripts/run_copilot_news_pipeline.sh --selected
  scripts/run_copilot_news_pipeline.sh --publish-draft _drafts/2026-04-02-sample.md
EOF
}

if [[ $# -eq 0 ]]; then
  usage
  exit 1
fi

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

if ! command -v copilot >/dev/null 2>&1; then
  echo "copilot CLI nao encontrado no PATH."
  exit 1
fi

repo_root="$(git rev-parse --show-toplevel 2>/dev/null || true)"
if [[ -z "$repo_root" ]]; then
  echo "Este script tem de correr dentro de um repositorio git."
  exit 1
fi

queue_file=""
use_selected="false"
publish_draft_input=""

if [[ "${1:-}" == "--publish-draft" ]]; then
  shift
  if [[ $# -eq 0 ]]; then
    echo "Falta indicar o draft a publicar."
    usage
    exit 1
  fi
  publish_draft_input="$1"
  shift
elif [[ "${1:-}" == "--selected" ]]; then
  use_selected="true"
  shift
else
  queue_file="$1"
  shift
fi

publish="false"
post_date="$(date +%F)"
custom_slug=""
model=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --publish)
      publish="true"
      shift
      ;;
    --date)
      post_date="$2"
      shift 2
      ;;
    --slug)
      custom_slug="$2"
      shift 2
      ;;
    --model)
      model="$2"
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

resolve_repo_path() {
  local input_path="$1"
  if [[ "$input_path" = /* ]]; then
    printf '%s\n' "$input_path"
  else
    printf '%s\n' "$repo_root/$input_path"
  fi
}

normalize_generated_draft() {
  local expected_abs="$1"
  local expected_name
  local date_prefix
  local found_abs=""
  local found_count=0
  local candidate

  if [[ -f "$expected_abs" ]]; then
    return 0
  fi

  expected_name="$(basename "$expected_abs")"
  date_prefix="${expected_name%%-*}"
  date_prefix="${expected_name%%.md}"
  date_prefix="${expected_name:0:10}"

  shopt -s nullglob
  for candidate in "$draft_dir"/"${date_prefix}"*.md; do
    [[ "$candidate" == "$expected_abs" ]] && continue
    found_abs="$candidate"
    found_count=$((found_count + 1))
  done
  shopt -u nullglob

  if [[ $found_count -eq 1 && -n "$found_abs" ]]; then
    mv "$found_abs" "$expected_abs"
    echo "Draft renomeado automaticamente para $(basename "$expected_abs")"
    return 0
  fi

  echo "Draft nao encontrado no caminho esperado: $expected_abs"
  if [[ $found_count -gt 1 ]]; then
    echo "Tambem encontrei varios drafts alternativos em _drafts/ para esta data; abortar para evitar escolher o ficheiro errado."
  elif [[ $found_count -eq 1 ]]; then
    echo "Encontrei um draft alternativo em _drafts/, mas nao o consegui normalizar automaticamente."
  fi
  exit 1
}

publish_existing_draft() {
  local draft_input="$1"
  local draft_abs
  local draft_rel
  local draft_name
  local post_abs
  local post_rel
  local publisher_prompt

  draft_abs="$(resolve_repo_path "$draft_input")"
  if [[ ! -f "$draft_abs" ]]; then
    echo "Draft nao encontrado: $draft_input"
    exit 1
  fi

  draft_rel="${draft_abs#$repo_root/}"
  if [[ "$draft_rel" == "$draft_abs" ]]; then
    echo "O draft tem de estar dentro deste repositorio."
    exit 1
  fi

  if [[ "$draft_rel" != _drafts/* ]]; then
    echo "O draft a publicar tem de estar dentro de _drafts/."
    exit 1
  fi

  draft_name="$(basename "$draft_abs")"
  post_abs="$repo_root/_posts/$draft_name"
  post_rel="_posts/$draft_name"

  if [[ -f "$post_abs" ]]; then
    echo "O post ja existe: $post_abs"
    exit 1
  fi

  mv "$draft_abs" "$post_abs"
  echo "Draft movido para $post_rel"

  publisher_prompt=$(cat <<EOF
Publica o artigo ja validado em $post_rel.
Analisa o git status, inclui apenas os ficheiros relevantes desta publicacao e faz commit e push para main.
Se houver alteracoes nao relacionadas, deixa-as de fora.
EOF
)

  echo "A publicar para main"
  copilot -s "${copilot_args[@]}" --agent=main-publisher --prompt "$publisher_prompt"
}

copilot_args=(
  --allow-all-tools
  --add-dir "$repo_root"
  --no-ask-user
)

if [[ -n "$model" ]]; then
  copilot_args+=(--model "$model")
fi

if [[ -n "$publish_draft_input" ]]; then
  bash scripts/ensure_github_identity.sh
  publish_existing_draft "$publish_draft_input"
  exit 0
fi

if [[ "$use_selected" == "true" ]]; then
  shortlist_path="$repo_root/news_queue/SHORTLIST.md"
  if [[ ! -f "$shortlist_path" ]]; then
    echo "SHORTLIST.md nao encontrado em news_queue/. Corre primeiro scripts/curate_news_queue.sh."
    exit 1
  fi
  queue_file="$(python3 - "$shortlist_path" <<'PY'
from pathlib import Path
import sys

text = Path(sys.argv[1]).read_text(encoding="utf-8", errors="ignore").splitlines()
first = text[0].strip() if text else ""
if ":" not in first:
    print("")
    raise SystemExit(0)
selected = first.split(":", 1)[1].strip()
print("" if selected == "none" else selected)
PY
)"
  if [[ -z "$queue_file" ]]; then
    echo "O SHORTLIST.md nao tem uma noticia selecionada."
    exit 1
  fi
fi

queue_path="$repo_root/$queue_file"
if [[ ! -f "$queue_path" ]]; then
  echo "Queue file nao encontrado: $queue_file"
  exit 1
fi

if python3 scripts/check_topic_uniqueness.py --queue-file "$queue_path" --posts-dir "$repo_root/_posts"; then
  :
else
  status=$?
  if [[ $status -eq 2 ]]; then
    echo "A noticia selecionada ja esta coberta no blog. Abortar antes de escrever novo artigo."
    exit 0
  fi
  exit "$status"
fi

extract_front_matter_value() {
  local key="$1"
  python3 - "$queue_path" "$key" <<'PY'
from pathlib import Path
import re
import sys

path = Path(sys.argv[1])
key = sys.argv[2]
text = path.read_text(encoding="utf-8", errors="ignore")
match = re.search(rf"^{re.escape(key)}:\s*\"?(.*?)\"?\s*$", text, re.MULTILINE)
if match:
    print(match.group(1).strip())
PY
}

slugify() {
  python3 - "$1" <<'PY'
import re
import sys
import unicodedata

value = unicodedata.normalize("NFKD", sys.argv[1]).encode("ascii", "ignore").decode("ascii")
value = re.sub(r"[^a-zA-Z0-9]+", "-", value.lower()).strip("-")
print(value[:70] or "news-post")
PY
}

title="$(extract_front_matter_value "title")"
slug_hint="$(extract_front_matter_value "slug_hint")"

if [[ -n "$custom_slug" ]]; then
  slug="$custom_slug"
elif [[ -n "$slug_hint" ]]; then
  slug="$slug_hint"
else
  slug="$(slugify "$title")"
fi

draft_dir="$repo_root/_drafts"
draft_path="$draft_dir/${post_date}-${slug}.md"
post_path="$repo_root/_posts/${post_date}-${slug}.md"

mkdir -p "$draft_dir"

if [[ -f "$post_path" ]]; then
  echo "O post ja existe: $post_path"
  exit 1
fi

writer_prompt=$(cat <<EOF
Lê o ficheiro $queue_file e cria um artigo novo em _drafts/${post_date}-${slug}.md.
Usa o agente writer deste repositorio para transformar a noticia num artigo de opiniao em Markdown, com front matter Jekyll.
Regras importantes:
- tens de gravar exatamente no caminho _drafts/${post_date}-${slug}.md;
- nao podes inventar outro nome de ficheiro, nao podes renomear, nao podes traduzir o slug e nao podes introduzir Unicode no nome;
- o texto tem de soar humano e natural;
- nao inventar factos;
- explicar acronimos e chavoes no proprio texto;
- pode usar humor, musica, carros ou mitologia com moderacao, so quando fizer sentido;
- manter um angulo claro e um tom alinhado com este blog.
No fim, grava mesmo o ficheiro no caminho indicado.
EOF
)

editor_prompt=$(cat <<EOF
Revê e melhora o ficheiro _drafts/${post_date}-${slug}.md.
Polir o texto para ficar mais humano, natural e alinhado com a voz do blog.
Explicar acronimos e chavoes quando aparecerem, cortar frases demasiado artificiais e manter o texto pronto a publicar.
Grava as alteracoes no mesmo ficheiro.
EOF
)

quality_gate_prompt=$(cat <<EOF
Faz a ultima revisao de qualidade ao ficheiro _drafts/${post_date}-${slug}.md.
Corrige diretamente qualquer problema residual de portugues de Portugal, casing de nomes tecnicos, titulo artificial, frases com cheiro a traducao ou jargao mal explicado.
So considera o artigo pronto se estiver mesmo publicavel sem remendos humanos depois.
Grava as alteracoes no mesmo ficheiro.
EOF
)

publisher_prompt=$(cat <<EOF
Publica o artigo acabado de criar.
Analisa o git status, inclui apenas os ficheiros relevantes deste fluxo e faz commit e push para main.
O ficheiro principal a publicar e _posts/${post_date}-${slug}.md.
Se houver alteracoes nao relacionadas, deixa-as de fora.
EOF
)

bash scripts/ensure_github_identity.sh

echo "A criar draft em _drafts/${post_date}-${slug}.md"
copilot -s "${copilot_args[@]}" --agent=tech-news-opinion-writer --prompt "$writer_prompt"
normalize_generated_draft "$draft_path"

echo "A rever draft com o editor"
copilot -s "${copilot_args[@]}" --agent=blog-editor --prompt "$editor_prompt"
normalize_generated_draft "$draft_path"

echo "A passar no quality gate"
copilot -s "${copilot_args[@]}" --agent=post-quality-gate --prompt "$quality_gate_prompt"
normalize_generated_draft "$draft_path"

if [[ "$publish" == "true" ]]; then
  if [[ ! -f "$draft_path" ]]; then
    echo "Draft nao encontrado para publicar: $draft_path"
    exit 1
  fi
  mv "$draft_path" "$post_path"
  echo "Draft movido para _posts/${post_date}-${slug}.md"
  echo "A publicar para main"
  copilot -s "${copilot_args[@]}" --agent=main-publisher --prompt "$publisher_prompt"
else
  echo "Draft criado em _drafts/${post_date}-${slug}.md"
  echo "Se quiseres publicar de seguida, corre este comando com --publish."
fi
