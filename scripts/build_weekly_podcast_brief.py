#!/usr/bin/env python3
from __future__ import annotations

import argparse
import re
import unicodedata
from dataclasses import dataclass
from datetime import date, datetime, timedelta
from pathlib import Path


FRONT_MATTER_RE = re.compile(r"^---\n(.*?)\n---\n", re.DOTALL)
KEY_RE = re.compile(r"^(?P<key>[A-Za-z0-9_-]+):\s*(?P<value>.+?)\s*$", re.MULTILINE)
LIST_RE = re.compile(r"\[(.*?)\]")


@dataclass
class PostItem:
    path: Path
    title: str
    published_at: date
    categories: list[str]
    topic: str
    excerpt: str
    post_url: str


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Build a weekly podcast brief from recently published posts."
    )
    parser.add_argument("--posts-dir", default="_posts")
    parser.add_argument("--output", required=True)
    parser.add_argument("--date", default=None, help="Reference date in YYYY-MM-DD format.")
    parser.add_argument("--days", type=int, default=7)
    parser.add_argument("--limit", type=int, default=6)
    return parser.parse_args()


def parse_date(value: str | None) -> date:
    if not value:
        return datetime.now().date()
    return datetime.strptime(value, "%Y-%m-%d").date()


def parse_front_matter(text: str) -> tuple[dict[str, str], str]:
    match = FRONT_MATTER_RE.match(text)
    if not match:
        return {}, text
    data: dict[str, str] = {}
    for item in KEY_RE.finditer(match.group(1)):
        data[item.group("key")] = item.group("value").strip().strip('"')
    body = text[match.end():]
    return data, body


def parse_inline_list(raw: str) -> list[str]:
    match = LIST_RE.search(raw or "")
    if not match:
        return []
    return [item.strip().strip('"').strip("'") for item in match.group(1).split(",") if item.strip()]


def slugify(value: str) -> str:
    normalized = unicodedata.normalize("NFKD", value).encode("ascii", "ignore").decode("ascii")
    normalized = normalized.lower()
    normalized = re.sub(r"[^a-z0-9]+", "-", normalized)
    return normalized.strip("-")


def canonical_topic(title: str, categories: list[str], body: str) -> str:
    title_and_body = " ".join([title, body]).lower()
    category_text = " ".join(categories).lower()

    has_ai = any(token in category_text for token in ("ia", "ai"))
    has_cyber = any(token in category_text for token in ("segurança", "seguranca", "vulnerab", "devsecops", "cyber"))
    has_general_tech = any(
        token in category_text
        for token in ("cloud", "infraestrutura", "devops", "operações", "operacoes", "empresas", "tecnologia")
    )

    strong_cyber_signal = any(
        token in title_and_body
        for token in ("cve-", "ransomware", "malware", "exploit", "zero-day", "zeroday", "patch", "vulnerab")
    )

    if has_cyber and strong_cyber_signal:
        return "cybersecurity"

    if has_general_tech and not has_cyber:
        return "technology"

    if has_ai:
        return "ai"

    if has_cyber:
        return "cybersecurity"

    return "technology"


def extract_excerpt(body: str, max_length: int = 280) -> str:
    paragraphs = []
    for raw_line in body.splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#") or line.startswith("!["):
            continue
        paragraphs.append(line)
    if not paragraphs:
        return "Sem excerto disponível."
    excerpt = paragraphs[0]
    excerpt = re.sub(r"`([^`]+)`", r"\1", excerpt)
    excerpt = re.sub(r"\[(.*?)\]\(.*?\)", r"\1", excerpt)
    if len(excerpt) <= max_length:
        return excerpt
    return excerpt[: max_length - 1].rsplit(" ", 1)[0] + "…"


def load_posts(posts_dir: Path) -> list[PostItem]:
    items: list[PostItem] = []
    for path in sorted(posts_dir.glob("*.md")):
        text = path.read_text(encoding="utf-8", errors="ignore")
        meta, body = parse_front_matter(text)
        raw_date = meta.get("date")
        raw_title = meta.get("title", path.stem)
        if not raw_date:
            continue
        try:
            published_at = datetime.strptime(raw_date[:10], "%Y-%m-%d").date()
        except ValueError:
            continue
        categories = parse_inline_list(meta.get("categories", ""))
        stem = path.stem
        post_slug = stem[11:] if len(stem) > 11 and stem[4] == "-" and stem[7] == "-" else stem
        category_path = "/".join(slugify(category) for category in categories)
        post_url = f"/{category_path}/{post_slug}/" if category_path else f"/{post_slug}/"
        items.append(
            PostItem(
                path=path,
                title=raw_title,
                published_at=published_at,
                categories=categories,
                topic=canonical_topic(raw_title, categories, body),
                excerpt=extract_excerpt(body),
                post_url=post_url,
            )
        )
    return items


def select_posts(items: list[PostItem], start_date: date, end_date: date, limit: int) -> list[PostItem]:
    recent = [item for item in items if start_date <= item.published_at <= end_date]
    recent.sort(key=lambda item: (item.published_at, item.path.name), reverse=True)

    selected: list[PostItem] = []
    used_paths: set[Path] = set()
    for topic in ("cybersecurity", "technology", "ai"):
        for item in recent:
            if item.path in used_paths or item.topic != topic:
                continue
            selected.append(item)
            used_paths.add(item.path)
            break

    for item in recent:
        if len(selected) >= limit:
            break
        if item.path in used_paths:
            continue
        selected.append(item)
        used_paths.add(item.path)

    selected.sort(key=lambda item: (item.published_at, item.path.name), reverse=True)
    return selected


def next_episode_number(posts_dir: Path) -> int:
    highest = 0
    for path in posts_dir.glob("*.md"):
        text = path.read_text(encoding="utf-8", errors="ignore")
        meta, _body = parse_front_matter(text)
        raw_value = meta.get("episode_number", "").strip()
        if not raw_value.isdigit():
            continue
        highest = max(highest, int(raw_value))
    return highest + 1


def render_brief(output_path: Path, reference_date: date, start_date: date, selected: list[PostItem], episode_number: int) -> None:
    iso_year, iso_week, _iso_weekday = reference_date.isocalendar()
    episode_title = f"Resumo semanal #{episode_number}"
    episode_slug = f"{reference_date.isoformat()}-podcast-semana-{iso_year}-w{iso_week:02d}"

    lines = [
        "---",
        f"episode_number: {episode_number}",
        f"episode_date: {reference_date.isoformat()}",
        f"episode_title: \"{episode_title}\"",
        f"episode_slug: \"{slugify(episode_slug)}\"",
        f"window_start: {start_date.isoformat()}",
        f"window_end: {reference_date.isoformat()}",
        "---",
        "",
        "# Brief semanal do podcast",
        "",
        f"- Episódio: {episode_number}",
        f"- Janela editorial: {start_date.isoformat()} a {reference_date.isoformat()}",
        f"- Número de peças escolhidas: {len(selected)}",
        "- Objetivo: abrir curto, ligar os temas e fechar com leitura prática da semana.",
        "",
        "## Temas escolhidos",
        "",
    ]

    for index, item in enumerate(selected, start=1):
        categories = ", ".join(item.categories) if item.categories else item.topic
        lines.extend(
            [
                f"### Tema {index}",
                f"- Título: {item.title}",
                f"- Data: {item.published_at.isoformat()}",
                f"- Tópico: {item.topic}",
                f"- Categorias: {categories}",
                f"- Ficheiro: {item.path}",
                f"- URL: {item.post_url}",
                f"- Excerto: {item.excerpt}",
                "",
            ]
        )

    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text("\n".join(lines), encoding="utf-8")


def main() -> int:
    args = parse_args()
    posts_dir = Path(args.posts_dir)
    output_path = Path(args.output)
    reference_date = parse_date(args.date)
    start_date = reference_date - timedelta(days=max(args.days - 1, 0))

    posts = load_posts(posts_dir)
    selected = select_posts(posts, start_date, reference_date, args.limit)
    if not selected:
        print("No posts found in the requested window.")
        return 1

    episode_number = next_episode_number(posts_dir)
    render_brief(output_path, reference_date, start_date, selected, episode_number)
    print(f"BRIEF_WRITTEN: {output_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
