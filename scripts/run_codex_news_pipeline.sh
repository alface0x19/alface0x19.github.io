#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  scripts/run_codex_news_pipeline.sh <queue-file> [--publish] [--date YYYY-MM-DD] [--slug custom-slug] [--model model-name]
    [--writer-model model-name] [--editor-model model-name] [--angle-model model-name]
    [--image-model model-name] [--gate-model model-name]
  scripts/run_codex_news_pipeline.sh --selected [--publish] [--date YYYY-MM-DD] [--slug custom-slug] [--model model-name]
    [--writer-model model-name] [--editor-model model-name] [--angle-model model-name]
    [--image-model model-name] [--gate-model model-name]
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
angle_brief_path=""
declare -a tracked_draft_baseline=()

cleanup_failed_run() {
  local exit_code=$?
  local candidate
  local known

  trap - EXIT

  if [[ $exit_code -eq 0 ]]; then
    if [[ -n "$angle_brief_path" && -f "$angle_brief_path" ]]; then
      rm -f "$angle_brief_path"
    fi
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

  if [[ -n "$angle_brief_path" && -f "$angle_brief_path" ]]; then
    rm -f "$angle_brief_path"
    echo "Cleanup: removido brief temporario ${angle_brief_path}"
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
writer_model=""
editor_model=""
angle_model=""
image_model=""
gate_model=""

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
  for candidate in "$article_image_dir"/cover.svg "$article_image_dir"/cover.png "$article_image_dir"/cover.jpg "$article_image_dir"/cover.jpeg "$article_image_dir"/cover.webp; do
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

generate_article_caricature() {
  local queue_rel="$1"
  local draft_rel="$2"
  local target_rel="$3"
  local cover_prompt=""

  article_image_abs=""
  article_image_rel=""
  article_image_url=""

  mkdir -p "$article_image_dir"

  cover_prompt=$(cat <<EOF
Lê o ficheiro $queue_rel e lê também o draft final em $draft_rel.
Cria uma caricatura editorial em SVG para esta notícia com base no artigo já escrito.
Grava exatamente o ficheiro em $target_rel.
Usa a persona já definida neste repositório: tom humano, ligeiro humor seco e uma referência reconhecível a música, carros ou mitologia quando isso encaixar.
Objetivo visual:
- interpretar a notícia de forma editorial, não fotográfica;
- ser fiel ao ângulo e à tese que ficaram no draft final, não apenas ao headline bruto;
- a imagem deve parecer uma caricatura conceptual da notícia, não um logo colado nem um screenshot;
- privilegiar composição simples, legível e expressiva;
- se houver texto dentro do SVG, ele tem de ser curto, ter contraste alto com o fundo e continuar legivel em ecrãs pequenos;
- manter compatibilidade web: SVG puro, sem JavaScript, sem assets externos, sem fontes remotas;
- incluir título e subtítulo curtos dentro do SVG apenas se isso ajudar a leitura;
- evitar excesso de texto e evitar copiar o headline completo.
Restrições:
- usa apenas um único ficheiro SVG;
- não cries PNG, JPG, WebP nem ficheiros auxiliares;
- não mudes o nome nem o diretório de saída;
- se houver menção a vendors, produtos ou CVEs, preserva casing correto;
- o SVG tem de ser válido e pronto a servir como cover local do post.
Contexto:
- draft alvo do artigo: $draft_rel
- path final obrigatório da caricatura: $target_rel
Quando terminares, a última linha não vazia tem de ser exatamente:
CARICATURE_CREATED: $target_rel
Se houver bloqueio real, a última linha não vazia tem de ser exatamente:
BLOCKED: <motivo>
EOF
)

  echo "A gerar caricatura editorial em ${target_rel}"
  run_agent_expect_status news-caricaturist "$cover_prompt" "CARICATURE_CREATED: $target_rel" "image"

  article_image_abs="$repo_root/$target_rel"
  article_image_rel="$target_rel"
  article_image_url="{{ site.baseurl }}/${article_image_rel}"
}

generate_angle_brief() {
  local queue_rel="$1"
  local target_abs="$2"
  local target_rel="$3"
  local angle_prompt=""

  angle_prompt=$(cat <<EOF
Lê o ficheiro $queue_rel e cria um brief editorial curto para orientar o artigo.
Grava exatamente esse brief em $target_abs.
Objetivo:
- identificar a tese principal;
- fixar um ângulo claro e publicável;
- resumir o que importa de facto;
- dizer o que deve ficar de fora;
- preservar explicitamente a persona do autor como parte obrigatória do artigo final.
O brief deve ser curto, direto e útil para um writer.
Estrutura recomendada:
- headline da notícia em 1 linha;
- tese editorial;
- 3 a 5 factos-chave;
- impacto prático;
- ruído ou hype a cortar;
- toque de persona obrigatório: como a voz do autor deve aparecer sem parecer forçada.
Regras:
- não escrevas o artigo completo;
- não cries ficheiros paralelos;
- não mudes o caminho de saída;
- o brief tem de dizer explicitamente que a persona do autor é obrigatória e deve aparecer cedo no texto.
Quando terminares, a última linha não vazia tem de ser exatamente:
ANGLE_READY: $target_rel
Se houver bloqueio real, a última linha não vazia tem de ser exatamente:
BLOCKED: <motivo>
EOF
)

  echo "A gerar brief editorial em ${target_rel}"
  run_agent_expect_status angle-setter "$angle_prompt" "ANGLE_READY: $target_rel" "angle"
}

quality_gate_article_caricature() {
  local queue_rel="$1"
  local draft_rel="$2"
  local target_rel="$3"
  local gate_prompt=""

  gate_prompt=$(cat <<EOF
Lê o ficheiro $queue_rel, lê o draft final em $draft_rel e faz o quality gate final da caricatura em $target_rel.
Revê o SVG com exigência editorial e corrige diretamente o próprio ficheiro se precisares.
Valida especialmente:
- se a imagem representa o conflito central da notícia;
- se a imagem está alinhada com a tese e o ângulo do draft final;
- se a composição está legível e não demasiado confusa;
- se qualquer texto, label ou callout dentro do SVG tem contraste suficiente e se lê sem esforço;
- se a persona do blog está presente com moderação e de forma reconhecível;
- se o resultado parece caricatura editorial e não stock art, meme ou slide genérico;
- se o SVG está limpo, válido e sem dependências externas.
Regras:
- edita apenas o ficheiro SVG indicado;
- não cries ficheiros alternativos;
- não mudes o nome nem o diretório;
- não mexas no artigo Markdown;
- se a imagem estiver fraca mas recuperável, melhora-a diretamente;
- se existir um bloqueio real que impeça uma capa minimamente publicável, trava o fluxo.
Quando terminares com sucesso, a última linha não vazia tem de ser exatamente:
CARICATURE_READY: $target_rel
Se houver bloqueio real, a última linha não vazia tem de ser exatamente:
BLOCKED: <motivo>
EOF
)

  echo "A passar caricatura no quality gate: ${target_rel}"
  run_agent_expect_status caricature-quality-gate "$gate_prompt" "CARICATURE_READY: $target_rel" "image"
}

run_publication_readiness_gate() {
  local draft_rel="$1"
  local image_rel="$2"
  local angle_rel="$3"
  local readiness_prompt=""

  readiness_prompt=$(cat <<EOF
Faz o gate final de prontidão editorial desta publicação.
Lê o ficheiro $draft_rel.
Lê também o brief editorial em $angle_rel.
EOF
)

  if [[ -n "$image_rel" ]]; then
    readiness_prompt+=$'\n'
    readiness_prompt+="Lê também a imagem local em $image_rel e valida se ela está coerente com o artigo e com o ângulo."$'\n'
  fi

  readiness_prompt+=$(cat <<EOF
Missão:
- garantir que artigo, ângulo e imagem contam a mesma história;
- preservar e reforçar a persona do autor se ela estiver tímida;
- confirmar que título, abertura e fecho têm pulso autoral;
- corrigir diretamente o draft se houver desvio de foco, falta de clareza ou desalinhamento com o brief;
- se existir imagem local, confirmar que ela encaixa no tema, no tom e na promessa do artigo.
Regras:
- a persona do autor nunca pode desaparecer; se o texto estiver limpo mas genérico, ainda não está pronto;
- a voz do autor deve aparecer cedo e de forma reconhecível, com moderação;
- não cries ficheiros novos;
- edita no máximo o draft e, se necessário mesmo, a imagem local;
- não mexas em slugs, datas nem caminhos;
- se houver um bloqueio real de coerência editorial que não consigas corrigir numa passagem séria, trava o fluxo.
Quando terminares com sucesso, a última linha não vazia tem de ser exatamente:
PACKAGE_READY: $draft_rel
Se houver bloqueio real, a última linha não vazia tem de ser exatamente:
BLOCKED: <motivo>
EOF
)

  echo "A passar no gate final de prontidao editorial"
  run_agent_expect_status publication-readiness-gate "$readiness_prompt" "PACKAGE_READY: $draft_rel" "gate"
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

  echo "A publicar para main"
  publish_to_git "$post_rel"
  created_post_path=""
  restorable_draft_source=""
  restorable_draft_target=""
}

resolve_stage_model() {
  local stage="$1"

  case "$stage" in
    writer)
      printf '%s\n' "${writer_model:-$model}"
      ;;
    editor)
      printf '%s\n' "${editor_model:-$model}"
      ;;
    angle)
      printf '%s\n' "${angle_model:-$model}"
      ;;
    image)
      printf '%s\n' "${image_model:-$model}"
      ;;
    gate)
      printf '%s\n' "${gate_model:-$model}"
      ;;
    *)
      printf '%s\n' "$model"
      ;;
  esac
}

run_agent() {
  local agent_name="$1"
  local agent_prompt="$2"
  local stage="${3:-}"
  local selected_model=""

  selected_model="$(resolve_stage_model "$stage")"

  if [[ -n "$selected_model" ]]; then
    run_codex_agent --repo-root "$repo_root" --agent "$agent_name" --model "$selected_model" --prompt "$agent_prompt"
  else
    run_codex_agent --repo-root "$repo_root" --agent "$agent_name" --prompt "$agent_prompt"
  fi
}

publish_to_git() {
  local post_rel="$1"
  local image_dir_rel="${2:-}"
  local commit_msg

  git -C "$repo_root" add "$repo_root/$post_rel"
  if [[ -n "$image_dir_rel" && -d "$repo_root/$image_dir_rel" ]]; then
    git -C "$repo_root" add "$repo_root/$image_dir_rel/"
  fi
  commit_msg="post: $(basename "$post_rel" .md)"
  git -C "$repo_root" commit -m "$commit_msg"
  git -C "$repo_root" push origin main
  echo "PUBLISHED: $post_rel"
}

run_agent_expect_status() {
  local agent_name="$1"
  local agent_prompt="$2"
  local expected_status="$3"
  local stage="${4:-}"
  local output=""
  local last_nonempty=""

  output="$(run_agent "$agent_name" "$agent_prompt" "$stage")"
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
angle_brief_path="/tmp/${post_date}-${slug}-angle-$$.md"
angle_brief_rel="$angle_brief_path"

mkdir -p "$draft_dir"
track_existing_drafts "$post_date"
prepare_article_cover_image "$article_url"

if [[ -f "$post_path" ]]; then
  echo "O post ja existe: $post_path"
  exit 1
fi

generate_angle_brief "$queue_file" "$angle_brief_path" "$angle_brief_rel"

writer_prompt=$(cat <<EOF
Lê o ficheiro $queue_file e o brief editorial em $angle_brief_rel.
Cria um artigo novo em _drafts/${post_date}-${slug}.md.
Usa o agente writer deste repositorio para transformar a noticia num artigo de opiniao em Markdown, com front matter Jekyll.
Regras importantes:
- corres em modo de automacao, por isso faz o trabalho e termina sem diagnosticos, sem sugestoes e sem pedir confirmacoes;
- tens de gravar exatamente no caminho _drafts/${post_date}-${slug}.md;
- nao podes inventar outro nome de ficheiro, nao podes renomear, nao podes traduzir o slug e nao podes introduzir Unicode no nome;
- o texto tem de soar humano e natural;
- privilegia leitura compacta: por defeito, aponta para 600 a 900 palavras;
- chega a tese principal ate ao terceiro paragrafo;
- segue o brief editorial sem soar mecanico;
- a persona do autor e obrigatoria e deve aparecer cedo no artigo;
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
Faz a revisao editorial final do ficheiro _drafts/${post_date}-${slug}.md e deixa-o pronto a publicar.
Polir o texto para ficar humano, natural e alinhado com a voz do blog.
Corrige diretamente portugues de Portugal, casing tecnico, titulo artificial, jargao mal explicado, repeticao e frases com cheiro a traducao.
Se o artigo estiver comprido para o valor que entrega, encurta sem perder voz.
Regras importantes:
- corres em modo de automacao: nao dês diagnostico, nao deixes sugestoes e nao abras novas rondas de revisao;
- faz uma unica passagem editorial forte e, no maximo, uma passagem curta de compactacao;
- usa a heuristica de compactacao apenas uma vez; se o texto ja estiver suficientemente denso, para;
- so considera o artigo pronto se estiver mesmo publicavel sem remendos humanos depois;
- grava as alteracoes no mesmo ficheiro e termina logo de seguida;
- a ultima linha da tua resposta tem de ser exatamente: READY_TO_PUBLISH: _drafts/${post_date}-${slug}.md
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

echo "A criar draft em _drafts/${post_date}-${slug}.md"
run_agent_expect_status tech-news-opinion-writer "$writer_prompt" "DRAFT_WRITTEN: _drafts/${post_date}-${slug}.md" "writer"
normalize_generated_draft "$draft_path"

echo "A fazer revisao editorial final"
run_agent_expect_status blog-editor "$editor_prompt" "READY_TO_PUBLISH: _drafts/${post_date}-${slug}.md" "editor"
normalize_generated_draft "$draft_path"

if [[ -z "$article_image_rel" ]]; then
  generate_article_caricature "$queue_file" "_drafts/${post_date}-${slug}.md" "assets/images/posts/${post_date}-${slug}/cover.svg"
fi

if [[ "$article_image_rel" == assets/images/posts/${post_date}-${slug}/cover.svg ]]; then
  quality_gate_article_caricature "$queue_file" "_drafts/${post_date}-${slug}.md" "$article_image_rel"
fi

run_publication_readiness_gate "_drafts/${post_date}-${slug}.md" "$article_image_rel" "$angle_brief_rel"
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
  publish_to_git "_posts/${post_date}-${slug}.md" "assets/images/posts/${post_date}-${slug}"
  created_post_path=""
else
  echo "Draft criado em _drafts/${post_date}-${slug}.md"
  echo "Se quiseres publicar de seguida, corre este comando com --publish."
fi
