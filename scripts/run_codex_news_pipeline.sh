#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  scripts/run_codex_news_pipeline.sh <queue-file> [--publish] [--date YYYY-MM-DD] [--slug custom-slug] [--model model-name]
  scripts/run_codex_news_pipeline.sh --selected [--publish] [--date YYYY-MM-DD] [--slug custom-slug] [--model model-name]
  scripts/run_codex_news_pipeline.sh --publish-draft _drafts/YYYY-MM-DD-slug.md [--model model-name]

Examples:
  scripts/run_codex_news_pipeline.sh news_queue/2026-04-02-sample.md
  scripts/run_codex_news_pipeline.sh news_queue/2026-04-02-sample.md --publish
  scripts/run_codex_news_pipeline.sh --selected
  scripts/run_codex_news_pipeline.sh --publish-draft _drafts/2026-04-02-sample.md
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

repo_root="$(git rev-parse --show-toplevel 2>/dev/null || true)"
if [[ -z "$repo_root" ]]; then
  echo "Este script tem de correr dentro de um repositorio git."
  exit 1
fi

source "$repo_root/scripts/lib/codex_cli.sh"
ensure_codex_cli || exit 1

created_post_path=""
restorable_draft_source=""
restorable_draft_target=""
tracked_draft_prefix=""
declare -a tracked_draft_baseline=()

cleanup_failed_run() {
  local exit_code=$?
  local candidate
  local known

  trap - EXIT

  if [[ $exit_code -eq 0 ]]; then
    exit 0
  fi

  if [[ -n "$created_post_path" && -f "$created_post_path" ]]; then
    rm -f "$created_post_path"
    echo "Cleanup: removido post temporario ${created_post_path#$repo_root/}"
  fi

  if [[ -n "$restorable_draft_source" && -n "$restorable_draft_target" && -f "$restorable_draft_target" && ! -f "$restorable_draft_source" ]]; then
    mv "$restorable_draft_target" "$restorable_draft_source"
    echo "Cleanup: draft restaurado em ${restorable_draft_source#$repo_root/}"
  fi

  if [[ -n "$tracked_draft_prefix" ]]; then
    shopt -s nullglob
    for candidate in "$draft_dir"/"${tracked_draft_prefix}"*.md; do
      known="false"
      for baseline in "${tracked_draft_baseline[@]}"; do
        if [[ "$candidate" == "$baseline" ]]; then
          known="true"
          break
        fi
      done
      if [[ "$known" == "false" ]]; then
        rm -f "$candidate"
        echo "Cleanup: removido draft temporario ${candidate#$repo_root/}"
      fi
    done
    shopt -u nullglob
  fi

  exit "$exit_code"
}

trap cleanup_failed_run EXIT

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

find_existing_cover_image_abs() {
  local candidate
  shopt -s nullglob
  for candidate in "$article_image_dir"/cover.png "$article_image_dir"/cover.jpg "$article_image_dir"/cover.jpeg "$article_image_dir"/cover.webp; do
    if [[ -f "$candidate" ]]; then
      printf '%s\n' "$candidate"
      shopt -u nullglob
      return 0
    fi
  done
  shopt -u nullglob
  return 1
}

prepare_article_cover_image() {
  local source_url="$1"
  local og_image_url=""
  local extension=""
  local target_abs=""
  local tmp_abs=""

  article_image_abs=""
  article_image_rel=""
  article_image_url=""

  if article_image_abs="$(find_existing_cover_image_abs)"; then
    article_image_rel="${article_image_abs#$repo_root/}"
    article_image_url="{{ site.baseurl }}/${article_image_rel}"
    echo "Imagem de capa existente encontrada: $article_image_rel"
    return 0
  fi

  if [[ -z "$source_url" ]]; then
    return 0
  fi

  if ! command -v curl >/dev/null 2>&1; then
    return 0
  fi

  og_image_url="$(python3 - "$source_url" <<'PY'
import re
import sys
import urllib.request

url = sys.argv[1]
try:
    req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
    with urllib.request.urlopen(req, timeout=20) as resp:
        html = resp.read().decode("utf-8", errors="ignore")
except Exception:
    print("")
    raise SystemExit(0)

patterns = [
    r'<meta[^>]+property=["\\\']og:image["\\\'][^>]+content=["\\\']([^"\\\']+)["\\\']',
    r'<meta[^>]+content=["\\\']([^"\\\']+)["\\\'][^>]+property=["\\\']og:image["\\\']',
]
for p in patterns:
    m = re.search(p, html, flags=re.IGNORECASE)
    if m:
        print(m.group(1).strip())
        raise SystemExit(0)
print("")
PY
)"

  if [[ -z "$og_image_url" ]]; then
    return 0
  fi

  case "${og_image_url%%\?*}" in
    *.png|*.PNG) extension="png" ;;
    *.jpg|*.JPG) extension="jpg" ;;
    *.jpeg|*.JPEG) extension="jpeg" ;;
    *.webp|*.WEBP) extension="webp" ;;
    *) return 0 ;;
  esac

  mkdir -p "$article_image_dir"
  target_abs="$article_image_dir/cover.$extension"
  tmp_abs="$target_abs.tmp"

  if curl -LfsS --max-time 30 "$og_image_url" -o "$tmp_abs" 2>/dev/null; then
    mv "$tmp_abs" "$target_abs"
    article_image_abs="$target_abs"
    article_image_rel="${article_image_abs#$repo_root/}"
    article_image_url="{{ site.baseurl }}/${article_image_rel}"
    echo "Imagem de capa obtida automaticamente: $article_image_rel"
    return 0
  fi

  rm -f "$tmp_abs"
  return 0
}

track_existing_drafts() {
  local prefix="$1"
  local candidate

  tracked_draft_prefix="$prefix"
  tracked_draft_baseline=()

  shopt -s nullglob
  for candidate in "$draft_dir"/"${tracked_draft_prefix}"*.md; do
    tracked_draft_baseline+=("$candidate")
  done
  shopt -u nullglob
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

  restorable_draft_source="$draft_abs"
  restorable_draft_target="$post_abs"
  mv "$draft_abs" "$post_abs"
  created_post_path="$post_abs"
  echo "Draft movido para $post_rel"

  publisher_prompt=$(cat <<EOF
Publica o artigo ja validado em $post_rel.
Analisa o git status, inclui apenas os ficheiros relevantes desta publicacao e faz commit e push para main.
Se houver alteracoes nao relacionadas, deixa-as de fora.
Regras importantes:
- corres em modo de automacao: nao pecas confirmacao humana, nao dês relatorio longo e nao deixes texto depois do estado final;
- usa a identidade Git ja configurada no ambiente;
- nao incluas news_queue, SHORTLIST, _drafts ou alteracoes nao relacionadas;
- faz git add apenas do post alvo, depois git commit com pathspec desse post e por fim git push origin main;
- quando acabares, termina imediatamente;
- a ultima linha da tua resposta tem de ser exatamente: PUBLISHED: $post_rel
- se ficares genuinamente bloqueado, a ultima linha tem de ser exatamente: BLOCKED: <motivo>
EOF
)

  echo "A publicar para main"
  run_agent_expect_status main-publisher "$publisher_prompt" "PUBLISHED: $post_rel"
  created_post_path=""
  restorable_draft_source=""
  restorable_draft_target=""
}

run_agent() {
  local agent_name="$1"
  local agent_prompt="$2"

  if [[ -n "$model" ]]; then
    run_codex_agent --repo-root "$repo_root" --agent "$agent_name" --model "$model" --prompt "$agent_prompt"
  else
    run_codex_agent --repo-root "$repo_root" --agent "$agent_name" --prompt "$agent_prompt"
  fi
}

run_agent_expect_status() {
  local agent_name="$1"
  local agent_prompt="$2"
  local expected_status="$3"
  local output=""
  local last_nonempty=""

  output="$(run_agent "$agent_name" "$agent_prompt")"
  printf '%s\n' "$output"

  last_nonempty="$(printf '%s\n' "$output" | awk 'NF { line=$0 } END { print line }')"

  if [[ "$last_nonempty" == BLOCKED:* ]] || printf '%s\n' "$output" | grep -Eq '^BLOCKED: '; then
    echo "O agente $agent_name devolveu BLOCKED e o fluxo foi interrompido."
    exit 1
  fi

  if [[ "$last_nonempty" != "$expected_status" ]]; then
    echo "O agente $agent_name nao devolveu o estado esperado."
    echo "Esperado: $expected_status"
    if [[ -n "$last_nonempty" ]]; then
      echo "Ultima linha nao vazia recebida: $last_nonempty"
    else
      echo "Nao foi recebida nenhuma linha final de estado."
    fi
    exit 1
  fi
}

if [[ -n "$publish_draft_input" ]]; then
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
article_url="$(extract_front_matter_value "article_url")"

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
article_image_dir="$repo_root/assets/images/posts/${post_date}-${slug}"
article_image_abs=""
article_image_rel=""
article_image_url=""

mkdir -p "$draft_dir"
track_existing_drafts "$post_date"
prepare_article_cover_image "$article_url"

if [[ -f "$post_path" ]]; then
  echo "O post ja existe: $post_path"
  exit 1
fi

writer_prompt=$(cat <<EOF
Lê o ficheiro $queue_file e cria um artigo novo em _drafts/${post_date}-${slug}.md.
Usa o agente writer deste repositorio para transformar a noticia num artigo de opiniao em Markdown, com front matter Jekyll.
Regras importantes:
- corres em modo de automacao, por isso faz o trabalho e termina sem diagnosticos, sem sugestoes e sem pedir confirmacoes;
- tens de gravar exatamente no caminho _drafts/${post_date}-${slug}.md;
- nao podes inventar outro nome de ficheiro, nao podes renomear, nao podes traduzir o slug e nao podes introduzir Unicode no nome;
- o texto tem de soar humano e natural;
- privilegia leitura compacta: por defeito, aponta para 600 a 900 palavras;
- chega a tese principal ate ao terceiro paragrafo;
- usa paragrafos curtos, em regra com 1 a 3 frases;
- evita repetir a mesma ideia em abertura, desenvolvimento e fecho;
- nao inventar factos;
- explicar acronimos e chavoes no proprio texto;
- pode usar humor, musica, carros ou mitologia com moderacao, so quando fizer sentido;
- manter um angulo claro e um tom alinhado com este blog.
- faz no maximo uma passagem de escrita e uma passagem curta de compactacao;
- quando o ficheiro estiver gravado e fechado, termina imediatamente;
- a ultima linha da tua resposta tem de ser exatamente: DRAFT_WRITTEN: _drafts/${post_date}-${slug}.md
- se ficares genuinamente bloqueado, a ultima linha tem de ser exatamente: BLOCKED: <motivo>
EOF
)

editor_prompt=$(cat <<EOF
Revê e melhora o ficheiro _drafts/${post_date}-${slug}.md.
Polir o texto para ficar mais humano, natural e alinhado com a voz do blog.
Explicar acronimos e chavoes quando aparecerem, cortar frases demasiado artificiais, remover gordura e redundancia e manter o texto pronto a publicar.
Se o artigo estiver comprido para o valor que entrega, encurta sem perder voz.
Regras importantes:
- corres em modo de automacao: nao dês diagnostico, nao deixes sugestoes e nao abras novas rondas de revisao;
- faz uma unica passagem editorial forte e, no maximo, uma passagem curta de compactacao;
- usa a heuristica de compactacao apenas uma vez; se o texto ja estiver suficientemente denso, para;
- grava as alteracoes no mesmo ficheiro e termina logo de seguida;
- a ultima linha da tua resposta tem de ser exatamente: EDIT_COMPLETE: _drafts/${post_date}-${slug}.md
- se ficares genuinamente bloqueado, a ultima linha tem de ser exatamente: BLOCKED: <motivo>
EOF
)

if [[ -n "$article_image_rel" ]]; then
  editor_prompt+=$'\n'
  editor_prompt+="Imagem opcional disponivel: ${article_image_rel}"$'\n'
  editor_prompt+="Se essa imagem ajudar a leitura, insere exatamente uma imagem no artigo (na abertura ou no primeiro terco), usando este caminho e sem inventar outro:"$'\n'
  editor_prompt+="![Imagem de capa do artigo](${article_image_url})"$'\n'
  editor_prompt+="Nao dupliques a imagem e nao uses HTML."
fi

quality_gate_prompt=$(cat <<EOF
Faz a ultima revisao de qualidade ao ficheiro _drafts/${post_date}-${slug}.md.
Corrige diretamente qualquer problema residual de portugues de Portugal, casing de nomes tecnicos, titulo artificial, frases com cheiro a traducao ou jargao mal explicado.
Se ainda houver repeticao, paragrafo inchado ou contexto a mais, corta.
So considera o artigo pronto se estiver mesmo publicavel sem remendos humanos depois.
Regras importantes:
- corres em modo de automacao: nao dês relatorio longo, nao proposes nova ronda e nao reescrevas por perfeccionismo;
- faz uma unica passagem de quality gate e, se ficar publicavel, para;
- usa a regra de compactacao apenas como heuristica numa unica passagem, nao como motivo para iteracao infinita;
- grava as alteracoes no mesmo ficheiro e termina logo de seguida;
- se o artigo ficar pronto, a ultima linha da tua resposta tem de ser exatamente: READY_TO_PUBLISH: _drafts/${post_date}-${slug}.md
- se encontrares um bloqueio real que impeça publicacao automatica, a ultima linha tem de ser exatamente: BLOCKED: <motivo>
EOF
)

publisher_prompt=$(cat <<EOF
Publica o artigo acabado de criar em modo totalmente automatico.
Analisa o git status, inclui apenas os ficheiros relevantes desta publicacao e faz commit e push para main.
O ficheiro principal a publicar e _posts/${post_date}-${slug}.md.
Regras importantes:
- usa a identidade Git ja configurada no ambiente; nao pares para pedir confirmacao nem para validar manualmente o utilizador;
- nao incluas ficheiros de news_queue, SHORTLIST, _drafts ou quaisquer alteracoes nao relacionadas;
- se houver alteracoes nao relacionadas, deixa-as fora do commit e continua com a publicacao do post;
- se o artigo referenciar um asset de imagem em assets/images/posts/${post_date}-${slug}/, inclui esse asset no mesmo commit;
- a mensagem de commit deve ser curta, especifica e focada no post;
- faz git add e git commit por pathspec apenas do post e dos assets de imagem usados pelo post, para nao arrastar outras alteracoes staged;
- quando acabares, termina imediatamente;
- a ultima linha da tua resposta tem de ser exatamente: PUBLISHED: _posts/${post_date}-${slug}.md
- se ficares genuinamente bloqueado, a ultima linha tem de ser exatamente: BLOCKED: <motivo>
EOF
)

echo "A criar draft em _drafts/${post_date}-${slug}.md"
run_agent_expect_status tech-news-opinion-writer "$writer_prompt" "DRAFT_WRITTEN: _drafts/${post_date}-${slug}.md"
normalize_generated_draft "$draft_path"

echo "A rever draft com o editor"
run_agent_expect_status blog-editor "$editor_prompt" "EDIT_COMPLETE: _drafts/${post_date}-${slug}.md"
normalize_generated_draft "$draft_path"

echo "A passar no quality gate"
run_agent_expect_status post-quality-gate "$quality_gate_prompt" "READY_TO_PUBLISH: _drafts/${post_date}-${slug}.md"
normalize_generated_draft "$draft_path"

if [[ "$publish" == "true" ]]; then
  if [[ ! -f "$draft_path" ]]; then
    echo "Draft nao encontrado para publicar: $draft_path"
    exit 1
  fi
  mv "$draft_path" "$post_path"
  created_post_path="$post_path"
  echo "Draft movido para _posts/${post_date}-${slug}.md"
  echo "A publicar para main"
  run_agent_expect_status main-publisher "$publisher_prompt" "PUBLISHED: _posts/${post_date}-${slug}.md"
  created_post_path=""
else
  echo "Draft criado em _drafts/${post_date}-${slug}.md"
  echo "Se quiseres publicar de seguida, corre este comando com --publish."
fi
