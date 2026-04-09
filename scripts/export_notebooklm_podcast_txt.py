#!/usr/bin/env python3
from __future__ import annotations

import argparse
import re
from pathlib import Path


FRONT_MATTER_RE = re.compile(r"^---\n(.*?)\n---\n", re.DOTALL)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Export a podcast draft to a NotebookLM-friendly plain text file."
    )
    parser.add_argument("--draft", required=True)
    parser.add_argument("--output", required=True)
    return parser.parse_args()


def read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8", errors="ignore")


def parse_front_matter(text: str) -> tuple[dict[str, str], str]:
    match = FRONT_MATTER_RE.match(text)
    if not match:
        return {}, text
    data: dict[str, str] = {}
    for line in match.group(1).splitlines():
        if ":" not in line:
            continue
        key, value = line.split(":", 1)
        data[key.strip()] = value.strip().strip('"')
    return data, text[match.end():]


def extract_section(body: str, heading: str) -> str:
    pattern = rf"^##\s*{re.escape(heading)}\s*(.*?)(?=^##\s|\Z)"
    match = re.search(pattern, body, flags=re.S | re.M)
    return match.group(1).strip() if match else ""


def bullet_lines(section_text: str) -> list[str]:
    items: list[str] = []
    for raw_line in section_text.splitlines():
        line = raw_line.strip()
        if line.startswith("- "):
            items.append(line[2:].strip())
    return items


def normalize_dialogue(text: str) -> str:
    lines: list[str] = []
    for raw_line in text.splitlines():
        line = raw_line.strip()
        if not line:
            if lines and lines[-1] != "":
                lines.append("")
            continue
        line = re.sub(r"\[(.*?)\]\(.*?\)", r"\1", line)
        line = re.sub(r"`([^`]+)`", r"\1", line)
        lines.append(line)
    while lines and lines[-1] == "":
        lines.pop()
    return "\n".join(lines) + "\n"


def render_output(meta: dict[str, str], body: str) -> str:
    title = meta.get("title", "Podcast semanal")
    summary = meta.get("podcast_summary", "").strip()
    topics = bullet_lines(extract_section(body, "Neste episódio"))
    transcript = normalize_dialogue(extract_section(body, "Transcrição"))

    header = [
        title,
        "",
        "Documento preparado para importação no NotebookLM.",
        "Objetivo: gerar um podcast em português de Portugal, em formato de conversa entre dois amigos.",
        "A persona 'Autor' é a voz técnica e opinativa do blog.",
        "A persona 'Amigo' goza com o hype e os exageros da indústria sem faltar ao respeito e sem humor negro.",
    ]

    if summary:
        header.extend(["", f"Resumo editorial: {summary}"])

    if topics:
        header.extend(["", "Temas da semana:"])
        header.extend(f"- {topic}" for topic in topics)

    header.extend(
        [
            "",
            "Guião base / transcrição:",
            "",
            transcript.strip(),
            "",
        ]
    )
    return "\n".join(header).strip() + "\n"


def main() -> int:
    args = parse_args()
    draft_path = Path(args.draft)
    output_path = Path(args.output)

    meta, body = parse_front_matter(read_text(draft_path))
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(render_output(meta, body), encoding="utf-8")
    print(f"NOTEBOOKLM_TXT_WRITTEN: {output_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
