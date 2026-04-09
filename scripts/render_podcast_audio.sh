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
transcript_match = re.search(r"^##\s*Transcri[cç][aã]o\s*(.*)$", text, flags=re.S | re.M)
if transcript_match:
    text = transcript_match.group(1)
else:
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

render_with_openai_tts() {
  local workdir=""
  workdir="$(mktemp -d /tmp/podcast-openai-XXXXXX)"
  export PODCAST_OPENAI_WORKDIR="$workdir"

  python3 - "$PODCAST_TTS_INPUT" <<'PY'
from pathlib import Path
import json
import os
import re
import sys

input_path = Path(sys.argv[1])
workdir = Path(os.environ["PODCAST_OPENAI_WORKDIR"])
workdir.mkdir(parents=True, exist_ok=True)
text = input_path.read_text(encoding="utf-8", errors="ignore")

chunks = []
current_speaker = None
buffer = []

def flush():
    global current_speaker, buffer
    if not buffer:
        return
    chunks.append((current_speaker or "Narrador", " ".join(buffer).strip()))
    buffer = []

for raw_line in text.splitlines():
    line = raw_line.strip()
    if not line:
        flush()
        current_speaker = None
        continue
    match = re.match(r"^(Autor|Amigo):\s*(.+)$", line)
    if match:
        speaker = match.group(1)
        content = match.group(2).strip()
        if current_speaker and speaker != current_speaker:
            flush()
        current_speaker = speaker
        buffer.append(content)
        continue
    buffer.append(line)

flush()

if not chunks:
    chunks = [("Narrador", text.strip())]

(workdir / "chunks.json").write_text(
    json.dumps([{"speaker": speaker, "text": chunk} for speaker, chunk in chunks], ensure_ascii=False, indent=2),
    encoding="utf-8",
)
PY

  local model="${OPENAI_TTS_MODEL:-gpt-4o-mini-tts}"
  local author_voice="${OPENAI_TTS_VOICE_AUTHOR:-marin}"
  local friend_voice="${OPENAI_TTS_VOICE_FRIEND:-cedar}"
  local api_base="${OPENAI_API_BASE:-https://api.openai.com/v1}"

  if command -v ffmpeg >/dev/null 2>&1; then
    python3 - "$workdir/chunks.json" "$workdir" "$model" "$author_voice" "$friend_voice" "$api_base" <<'PY'
from pathlib import Path
import json
import os
import subprocess
import sys

chunks_path = Path(sys.argv[1])
workdir = Path(sys.argv[2])
model = sys.argv[3]
author_voice = sys.argv[4]
friend_voice = sys.argv[5]
api_base = sys.argv[6]

chunks = json.loads(chunks_path.read_text(encoding="utf-8"))
concat_entries = []

for index, chunk in enumerate(chunks, start=1):
    speaker = chunk["speaker"]
    text = chunk["text"].strip()
    if not text:
        continue
    voice = friend_voice if speaker == "Amigo" else author_voice
    instructions = (
        "European Portuguese. Warm, conversational, technical podcast host. Calm pace, natural pauses."
        if speaker != "Amigo"
        else "European Portuguese. Friendly sidekick voice, lightly amused, playful but respectful, no dark humor."
    )
    payload = {
        "model": model,
        "voice": voice,
        "input": text,
        "instructions": instructions,
        "format": "wav",
    }
    payload_path = workdir / f"payload-{index:03d}.json"
    audio_path = workdir / f"chunk-{index:03d}.wav"
    payload_path.write_text(json.dumps(payload, ensure_ascii=False), encoding="utf-8")
    cmd = [
        "curl",
        "-sS",
        f"{api_base}/audio/speech",
        "-H", f"Authorization: Bearer {os.environ['OPENAI_API_KEY']}",
        "-H", "Content-Type: application/json",
        "--data-binary", f"@{payload_path}",
        "--output", str(audio_path),
    ]
    subprocess.run(cmd, check=True)
    if audio_path.stat().st_size == 0:
        raise SystemExit(f"OpenAI TTS produced empty audio for chunk {index}")
    concat_entries.append(f"file '{audio_path}'")

concat_path = workdir / "concat.txt"
concat_path.write_text("\n".join(concat_entries) + "\n", encoding="utf-8")
PY

    ffmpeg -y -f concat -safe 0 -i "$workdir/concat.txt" -codec:a libmp3lame -q:a 2 "$PODCAST_TTS_OUTPUT" >/dev/null 2>&1
    rm -rf "$workdir"
    return 0
  fi

  python3 - "$PODCAST_TTS_INPUT" "$workdir/payload.json" "$model" "$author_voice" <<'PY'
from pathlib import Path
import json
import sys

input_path = Path(sys.argv[1])
payload_path = Path(sys.argv[2])
model = sys.argv[3]
voice = sys.argv[4]

payload = {
    "model": model,
    "voice": voice,
    "input": input_path.read_text(encoding="utf-8", errors="ignore"),
    "instructions": "European Portuguese. Natural spoken delivery for a technical podcast. Friendly and clear.",
}
payload_path.write_text(json.dumps(payload, ensure_ascii=False), encoding="utf-8")
PY

  curl -sS "${api_base}/audio/speech" \
    -H "Authorization: Bearer ${OPENAI_API_KEY}" \
    -H "Content-Type: application/json" \
    --data-binary "@${workdir}/payload.json" \
    --output "$PODCAST_TTS_OUTPUT"
  rm -rf "$workdir"
}

if [[ -n "${OPENAI_API_KEY:-}" ]]; then
  if ! command -v curl >/dev/null 2>&1; then
    echo "OPENAI_API_KEY definida mas curl nao esta disponivel para chamar a API." >&2
    exit 1
  fi
  render_with_openai_tts
elif [[ -n "${PODCAST_TTS_COMMAND:-}" ]]; then
  sh -lc "$PODCAST_TTS_COMMAND"
else
  echo "Nem OPENAI_API_KEY nem PODCAST_TTS_COMMAND definidos; salto a geracao de audio." >&2
  exit 2
fi

if [[ ! -s "$output_audio" ]]; then
  echo "O comando TTS terminou sem gerar audio utilizavel: $output_audio" >&2
  exit 1
fi

echo "AUDIO_RENDERED: $output_audio"
