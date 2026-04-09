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


def render_body(topics: list[dict[str, str]]) -> str:
    links = []
    bullets = []
    transcript = []
    timestamps = ["- `00:00` Abertura e leitura rápida da semana"]

    for index, topic in enumerate(topics[:4], start=1):
        title = topic.get("título") or topic.get("titulo") or topic.get("title") or "Tema"
        excerpt = topic.get("excerto") or topic.get("excerpt") or "Sem excerto."
        post_url = topic.get("url") or "#"
        bullets.append(f"- {title}")
        links.append(f"- [{title}]({post_url})")
        timestamps.append(f"- `0{index}:3{index}` {title}")

        transcript.extend(
            [
                f"Autor: Vamos pegar em {title.lower()} porque isto ajuda a perceber para onde o ecossistema está a descair esta semana.",
                f"Amigo: Traduzindo: mais um anúncio a jurar que agora é que o foguete vai mesmo levantar, mas ao menos desta vez há detalhes concretos no meio do fumo.",
                f"Autor: O ponto útil aqui é este: {excerpt}",
                "Amigo: E isso é a parte que separa tecnologia real de teatro com buzzwords e uma dashboard a piscar luzinhas.",
                "Autor: Exato. O que interessa não é o slogan; é perceber quem ganha controlo, quem ganha dependência e quem fica a segurar a conta quando a demo acaba.",
                "",
            ]
        )

    timestamps.append("- `12:30` Fecho")

    return "\n".join(
        [
            "## Neste episódio",
            "",
            *bullets,
            "",
            "## Timestamps",
            "",
            *timestamps,
            "",
            "## Links",
            "",
            *links,
            "",
            "## Transcrição",
            "",
            "Autor: Esta semana foi daquelas em que a IA, a infraestrutura e a segurança pareceram entrar todas na mesma faixa ao mesmo tempo.",
            "Amigo: Sim, foi uma semana muito rica em promessas de futuro e em pequenos lembretes de que o futuro também avaria.",
            "",
            *transcript,
            "Autor: No fim, a fotografia da semana é bastante simples. Já ninguém está só a vender modelos; estão a vender controlo, operação e posição dentro da stack.",
            "Amigo: E quando toda a gente quer ser a garagem, a estrada e o stand ao mesmo tempo, convém confirmar quem fica com as chaves.",
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

    summary = f"Conversa entre o Autor e o Amigo sobre os temas mais relevantes da semana em IA, segurança e operação tecnológica."
    body = render_body(topics)
    draft_text = update_front_matter_summary(draft_text, summary)
    draft_text = re.sub(r"## Neste episódio.*", body, draft_text, flags=re.S)
    draft_path.write_text(draft_text, encoding="utf-8")
    print(f"PODCAST_DRAFT_WRITTEN: {draft_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
