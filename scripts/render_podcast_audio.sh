#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 2 || $# -gt 3 ]]; then
  echo "Usage: scripts/render_podcast_audio.sh <draft-markdown> <output-audio> [title]" >&2
  exit 1
fi

draft_path="$1"
output_audio="$2"
title="${3:-}"

if [[ ! -f "$draft_path" ]]; then
  echo "Draft inexistente: $draft_path" >&2
  exit 1
fi

if [[ -z "${PODCAST_TTS_COMMAND:-}" ]]; then
  echo "PODCAST_TTS_COMMAND nao definido; salto a geracao de audio." >&2
  exit 2
fi

output_dir="$(dirname "$output_audio")"
mkdir -p "$output_dir"

plain_text_path="${output_audio%.*}.txt"

python3 - "$draft_path" "$plain_text_path" <<'PY'
from pathlib import Path
import re
import sys

draft_path = Path(sys.argv[1])
plain_text_path = Path(sys.argv[2])
text = draft_path.read_text(encoding="utf-8", errors="ignore")
text = re.sub(r"^---\n.*?\n---\n", "", text, flags=re.S)
text = re.sub(r"^##\s*Timestamps.*?(?=^##\s|\Z)", "", text, flags=re.S | re.M)
text = re.sub(r"^##\s*Links.*?(?=^##\s|\Z)", "", text, flags=re.S | re.M)
text = re.sub(r"\[(.*?)\]\(.*?\)", r"\1", text)
text = re.sub(r"`([^`]+)`", r"\1", text)
text = re.sub(r"^#+\s*", "", text, flags=re.M)
text = re.sub(r"^\s*-\s+", "", text, flags=re.M)
text = re.sub(r"\n{3,}", "\n\n", text).strip() + "\n"
plain_text_path.write_text(text, encoding="utf-8")
PY

export PODCAST_TTS_INPUT="$plain_text_path"
export PODCAST_TTS_OUTPUT="$output_audio"
export PODCAST_TTS_TITLE="$title"

sh -lc "$PODCAST_TTS_COMMAND"

if [[ ! -s "$output_audio" ]]; then
  echo "O comando TTS terminou sem gerar audio utilizavel: $output_audio" >&2
  exit 1
fi

echo "AUDIO_RENDERED: $output_audio"
