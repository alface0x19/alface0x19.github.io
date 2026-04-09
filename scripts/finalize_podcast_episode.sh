#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  scripts/finalize_podcast_episode.sh --draft path/to/draft.md --source path/to/audio.m4a [--publish]

Description:
  Converte o audio descarregado manualmente para MP3, calcula tamanho e duracao,
  atualiza o front matter do draft e, opcionalmente, move o episodio para _posts/.
EOF
}

draft_path=""
source_audio=""
publish="false"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --draft)
      draft_path="$2"
      shift 2
      ;;
    --source)
      source_audio="$2"
      shift 2
      ;;
    --publish)
      publish="true"
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Opcao desconhecida: $1" >&2
      usage
      exit 1
      ;;
  esac
done

if [[ -z "$draft_path" || -z "$source_audio" ]]; then
  usage
  exit 1
fi

if [[ ! -f "$draft_path" ]]; then
  echo "Draft inexistente: $draft_path" >&2
  exit 1
fi

if [[ ! -f "$source_audio" ]]; then
  echo "Audio de origem inexistente: $source_audio" >&2
  exit 1
fi

if ! command -v ffmpeg >/dev/null 2>&1; then
  echo "ffmpeg nao encontrado no PATH." >&2
  exit 1
fi

if ! command -v ffprobe >/dev/null 2>&1; then
  echo "ffprobe nao encontrado no PATH." >&2
  exit 1
fi

draft_abs="$(realpath "$draft_path")"
source_abs="$(realpath "$source_audio")"
repo_root="$(git rev-parse --show-toplevel 2>/dev/null || true)"
if [[ -z "$repo_root" ]]; then
  echo "Este script tem de correr dentro de um repositorio git." >&2
  exit 1
fi

draft_dir="$(dirname "$draft_abs")"
draft_file="$(basename "$draft_abs")"
target_base="${draft_file%.md}"
target_rel="assets/audio/podcast/$(date +%Y)/${target_base}.mp3"
target_abs="$repo_root/$target_rel"

mkdir -p "$(dirname "$target_abs")"

ffmpeg -y -i "$source_abs" -codec:a libmp3lame -q:a 2 "$target_abs" >/dev/null 2>&1

audio_size="$(stat -c %s "$target_abs")"
audio_duration_seconds="$(ffprobe -i "$target_abs" -show_entries format=duration -v quiet -of csv=p=0)"
audio_duration="$(python3 - "$audio_duration_seconds" <<'PY'
import math
import sys

seconds = float(sys.argv[1])
total = max(0, int(round(seconds)))
hours = total // 3600
minutes = (total % 3600) // 60
secs = total % 60
print(f"{hours:02d}:{minutes:02d}:{secs:02d}")
PY
)"

python3 - "$draft_abs" "/$target_rel" "$audio_size" "$audio_duration" <<'PY'
from pathlib import Path
import re
import sys

path = Path(sys.argv[1])
audio_url = sys.argv[2]
audio_size = sys.argv[3]
audio_duration = sys.argv[4]

text = path.read_text(encoding="utf-8", errors="ignore")

def replace_or_fail(pattern: str, replacement: str, content: str) -> str:
    updated, count = re.subn(pattern, replacement, content, flags=re.M)
    if count == 0:
        raise SystemExit(f"Campo nao encontrado no draft para atualizar: {pattern}")
    return updated

text = replace_or_fail(r'^audio_url:\s*.*$', f'audio_url: {audio_url}', text)
text = replace_or_fail(r'^audio_type:\s*.*$', 'audio_type: audio/mpeg', text)
text = replace_or_fail(r'^audio_size:\s*.*$', f'audio_size: {audio_size}', text)
text = replace_or_fail(r'^audio_duration:\s*.*$', f'audio_duration: "{audio_duration}"', text)

path.write_text(text, encoding="utf-8")
PY

echo "AUDIO_CONVERTED: $target_abs"
echo "DRAFT_UPDATED: $draft_abs"

if [[ "$publish" == "true" ]]; then
  if [[ "$draft_dir" != "$repo_root/_drafts" ]]; then
    echo "O draft nao esta em _drafts/, por isso nao foi promovido automaticamente." >&2
    exit 1
  fi
  post_abs="$repo_root/_posts/$draft_file"
  mv "$draft_abs" "$post_abs"
  echo "PODCAST_PUBLISHED: $post_abs"
fi
