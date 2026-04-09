#!/usr/bin/env python3
from __future__ import annotations

import argparse
import re
from pathlib import Path


FRONT_MATTER_RE = re.compile(r"^---\n(.*?)\n---\n", re.DOTALL)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Render a simple weekly podcast draft from a generated brief."
    )
    parser.add_argument("--brief", required=True)
    parser.add_argument("--draft", required=True)
    return parser.parse_args()


def read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8", errors="ignore")


def parse_meta(text: str) -> dict[str, str]:
    match = FRONT_MATTER_RE.match(text)
    if not match:
        return {}
    data: dict[str, str] = {}
    for line in match.group(1).splitlines():
        if ":" not in line:
            continue
        key, value = line.split(":", 1)
        data[key.strip()] = value.strip().strip('"')
    return data


def parse_topics(text: str) -> list[dict[str, str]]:
    topics: list[dict[str, str]] = []
    current: dict[str, str] | None = None
    for raw_line in text.splitlines():
        line = raw_line.strip()
        if line.startswith("### "):
            if current:
                topics.append(current)
            current = {"heading": line[4:].strip()}
            continue
        if current and line.startswith("- ") and ":" in line:
            key, value = line[2:].split(":", 1)
            current[key.strip().lower().replace(" ", "_")] = value.strip()
    if current:
        topics.append(current)
    return topics


def update_front_matter_summary(text: str, summary: str) -> str:
    return re.sub(r'^podcast_summary:\s*.*$', f'podcast_summary: "{summary}"', text, flags=re.M)


def teaser_from_excerpt(excerpt: str) -> str:
    cleaned = " ".join(excerpt.split()).strip()
    if not cleaned:
        return "Sem resumo curto disponível."
    sentence_match = re.match(r"(.+?[.!?])(?:\s|$)", cleaned)
    if sentence_match:
        return sentence_match.group(1).strip()
    return cleaned.rstrip(".…") + "."


def render_body(topics: list[dict[str, str]]) -> str:
    links = []
    bullets = []
    opening = (
        "Nesta semana, o fio condutor passa menos pela novidade em si e mais por quem quer "
        "controlar a stack, a operação e a narrativa à volta da IA."
    )

    for topic in topics[:4]:
        title = topic.get("título") or topic.get("titulo") or topic.get("title") or "Tema"
        excerpt = topic.get("excerto") or topic.get("excerpt") or "Sem excerto."
        post_url = topic.get("url") or "#"
        bullets.append(f"- **{title}**: {teaser_from_excerpt(excerpt)}")
        links.append(f"- [{title}]({post_url})")

    return "\n".join(
        [
            opening,
            "",
            "## Neste episódio",
            "",
            *bullets,
            "",
            "## Links",
            "",
            *links,
        ]
    )


def main() -> int:
    args = parse_args()
    brief_path = Path(args.brief)
    draft_path = Path(args.draft)

    brief_text = read_text(brief_path)
    draft_text = read_text(draft_path)
    meta = parse_meta(brief_text)
    topics = parse_topics(brief_text)

    if not topics:
        raise SystemExit("No topics found in brief.")

    summary = "Conversa entre o Autor e o Amigo sobre os temas mais relevantes da semana em IA, segurança e operação tecnológica."
    body = render_body(topics)
    draft_text = update_front_matter_summary(draft_text, summary)
    draft_text = re.sub(r"## Neste episódio.*", body, draft_text, flags=re.S)
    draft_path.write_text(draft_text, encoding="utf-8")
    print(f"PODCAST_DRAFT_WRITTEN: {draft_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
