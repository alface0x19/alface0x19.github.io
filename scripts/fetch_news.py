#!/usr/bin/env python3
from __future__ import annotations

import argparse
import hashlib
import html
import json
import re
import sys
import unicodedata
import urllib.error
import urllib.request
import xml.etree.ElementTree as ET
from dataclasses import dataclass
from datetime import datetime, timedelta, timezone
from email.utils import parsedate_to_datetime
from pathlib import Path
from typing import Iterable


USER_AGENT = (
    "alface0x19-news-bot/1.0 "
    "(https://github.com/alface0x19/alface0x19.github.io)"
)
HTML_TAG_RE = re.compile(r"<[^>]+>")
WHITESPACE_RE = re.compile(r"\s+")
URL_RE = re.compile(r"https?://[^\s)>\]]+")
INVALID_XML_RE = re.compile(r"[\x00-\x08\x0B\x0C\x0E-\x1F]")
BARE_AMP_RE = re.compile(r"&(?!#\d+;|#x[0-9A-Fa-f]+;|[A-Za-z][A-Za-z0-9]+;)")


@dataclass
class FeedSource:
    name: str
    category: str
    url: str
    kind: str = "auto"


@dataclass
class NewsItem:
    source: FeedSource
    title: str
    link: str
    summary: str
    published_at: datetime | None
    matched_keywords: list[str]
    score: int


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Fetch RSS/Atom/JSON feed items and queue them as Markdown."
    )
    parser.add_argument(
        "--config",
        default="scripts/config/news_sources.json",
        help="Path to the sources config file.",
    )
    parser.add_argument(
        "--output-dir",
        default="news_queue",
        help="Directory where queue Markdown files are created.",
    )
    parser.add_argument(
        "--posts-dir",
        default="_posts",
        help="Directory with already published posts for URL dedupe.",
    )
    parser.add_argument(
        "--days",
        type=int,
        default=None,
        help="Only keep items newer than this many days when the feed has a date.",
    )
    parser.add_argument(
        "--limit-per-feed",
        type=int,
        default=None,
        help="Maximum items kept from each feed before global ranking.",
    )
    parser.add_argument(
        "--limit-total",
        type=int,
        default=None,
        help="Maximum number of queued items per run.",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Print queued files without writing them.",
    )
    return parser.parse_args()


def load_config(path: Path) -> dict:
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except FileNotFoundError:
        raise SystemExit(f"Config not found: {path}")
    except json.JSONDecodeError as exc:
        raise SystemExit(f"Invalid JSON in {path}: {exc}") from exc


def fetch_text(url: str) -> str:
    request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    with urllib.request.urlopen(request, timeout=20) as response:
        charset = response.headers.get_content_charset() or "utf-8"
        return response.read().decode(charset, errors="replace")


def local_name(tag: str) -> str:
    return tag.split("}", 1)[-1]


def find_children(element: ET.Element, name: str) -> list[ET.Element]:
    return [child for child in element if local_name(child.tag) == name]


def find_first_text(element: ET.Element, *names: str) -> str:
    for name in names:
        for child in element.iter():
            if local_name(child.tag) == name and child.text:
                return child.text.strip()
    return ""


def find_link(element: ET.Element) -> str:
    for child in element.iter():
        if local_name(child.tag) != "link":
            continue
        href = child.attrib.get("href")
        rel = child.attrib.get("rel", "alternate")
        if href and rel in {"alternate", ""}:
            return href.strip()
        if child.text and child.text.strip():
            return child.text.strip()
    return ""


def parse_datetime(value: str) -> datetime | None:
    text = (value or "").strip()
    if not text:
        return None

    try:
        parsed = parsedate_to_datetime(text)
        if parsed.tzinfo is None:
            parsed = parsed.replace(tzinfo=timezone.utc)
        return parsed.astimezone(timezone.utc)
    except (TypeError, ValueError, IndexError):
        pass

    candidates = [text]
    if text.endswith("Z"):
        candidates.append(text[:-1] + "+00:00")

    for candidate in candidates:
        try:
            parsed = datetime.fromisoformat(candidate)
            if parsed.tzinfo is None:
                parsed = parsed.replace(tzinfo=timezone.utc)
            return parsed.astimezone(timezone.utc)
        except ValueError:
            continue

    return None


def strip_html(value: str) -> str:
    text = html.unescape(value or "")
    text = HTML_TAG_RE.sub(" ", text)
    text = WHITESPACE_RE.sub(" ", text)
    return text.strip()


def sanitize_xml(raw_text: str) -> str:
    cleaned = raw_text.lstrip("\ufeff")
    cleaned = INVALID_XML_RE.sub("", cleaned)
    cleaned = BARE_AMP_RE.sub("&amp;", cleaned)
    return cleaned


def parse_rss_or_atom(raw_text: str) -> list[tuple[str, str, str, datetime | None]]:
    root = ET.fromstring(sanitize_xml(raw_text))
    root_name = local_name(root.tag)

    items: list[tuple[str, str, str, datetime | None]] = []
    if root_name == "rss":
        channel = next((child for child in root if local_name(child.tag) == "channel"), None)
        if channel is None:
            return items
        for item in find_children(channel, "item"):
            title = find_first_text(item, "title")
            link = find_first_text(item, "link") or find_link(item)
            summary = (
                find_first_text(item, "description")
                or find_first_text(item, "encoded")
                or find_first_text(item, "summary")
            )
            published = parse_datetime(
                find_first_text(item, "pubDate", "published", "updated")
            )
            items.append((title, link, summary, published))
        return items

    if root_name == "feed":
        for entry in find_children(root, "entry"):
            title = find_first_text(entry, "title")
            link = find_link(entry)
            summary = (
                find_first_text(entry, "summary")
                or find_first_text(entry, "content")
                or find_first_text(entry, "subtitle")
            )
            published = parse_datetime(
                find_first_text(entry, "published", "updated", "created")
            )
            items.append((title, link, summary, published))
        return items

    raise ValueError(f"Unsupported XML root element: {root_name}")


def parse_json_feed(raw_text: str) -> list[tuple[str, str, str, datetime | None]]:
    data = json.loads(raw_text)
    items: list[tuple[str, str, str, datetime | None]] = []
    for item in data.get("items", []):
        title = (item.get("title") or "").strip()
        link = (item.get("url") or item.get("external_url") or "").strip()
        summary = item.get("summary") or item.get("content_text") or item.get("content_html") or ""
        published = parse_datetime(item.get("date_published") or item.get("date_modified") or "")
        items.append((title, link, summary, published))
    return items


def parse_feed(raw_text: str, kind: str) -> list[tuple[str, str, str, datetime | None]]:
    stripped = raw_text.lstrip()
    if kind == "json" or stripped.startswith("{"):
        return parse_json_feed(raw_text)
    return parse_rss_or_atom(raw_text)


def slugify(value: str, max_length: int = 70) -> str:
    normalized = unicodedata.normalize("NFKD", value).encode("ascii", "ignore").decode("ascii")
    normalized = normalized.lower()
    normalized = re.sub(r"[^a-z0-9]+", "-", normalized).strip("-")
    return normalized[:max_length].strip("-") or "news-item"


def dedupe_urls(paths: Iterable[Path]) -> set[str]:
    known_urls: set[str] = set()
    for path in paths:
        if not path.exists():
            continue
        for markdown_file in path.rglob("*.md"):
            text = markdown_file.read_text(encoding="utf-8", errors="ignore")
            for match in URL_RE.findall(text):
                known_urls.add(match.rstrip('",'))
    return known_urls


def rank_item(
    source: FeedSource,
    title: str,
    link: str,
    summary: str,
    published_at: datetime | None,
    include_keywords: list[str],
    priority_keywords: list[str],
    block_keywords: list[str],
    cutoff: datetime,
) -> NewsItem | None:
    clean_title = strip_html(title)
    clean_summary = strip_html(summary)
    if not clean_title or not link:
        return None

    haystack = f"{clean_title} {clean_summary}".lower()
    if any(keyword.lower() in haystack for keyword in block_keywords):
        return None

    if published_at and published_at < cutoff:
        return None

    matched_keywords = [
        keyword for keyword in include_keywords if keyword.lower() in haystack
    ]
    priority_matches = [
        keyword for keyword in priority_keywords if keyword.lower() in haystack
    ]

    score = len(matched_keywords) * 4 + len(priority_matches) * 10
    if published_at:
        age_hours = max((datetime.now(timezone.utc) - published_at).total_seconds() / 3600, 0)
        if age_hours <= 24:
            score += 10
        elif age_hours <= 72:
            score += 5
    if source.category == "cybersecurity":
        score += 2

    return NewsItem(
        source=source,
        title=clean_title,
        link=link,
        summary=clean_summary,
        published_at=published_at,
        matched_keywords=matched_keywords,
        score=score,
    )


def queue_filename(item: NewsItem) -> str:
    published_date = (
        item.published_at.astimezone(timezone.utc).date().isoformat()
        if item.published_at
        else datetime.now(timezone.utc).date().isoformat()
    )
    source_slug = slugify(item.source.name, max_length=24)
    title_slug = slugify(item.title, max_length=70)
    digest = hashlib.sha1(item.link.encode("utf-8")).hexdigest()[:8]
    return f"{published_date}-{source_slug}-{title_slug}-{digest}.md"


def quote_yaml(value: str) -> str:
    escaped = value.replace("\\", "\\\\").replace('"', '\\"')
    return f'"{escaped}"'


def bullets(values: Iterable[str]) -> str:
    lines = []
    for value in values:
        lines.append(f"- {value}")
    return "\n".join(lines)


def build_why_it_matters(item: NewsItem) -> list[str]:
    if item.source.category == "cybersecurity":
        return [
            "Traduzir o impacto real para equipas tecnicas, operacao e gestao de risco.",
            "Separar o que e vulnerabilidade material do que e apenas ruido noticioso.",
            "Identificar se isto pede patching, hardening, visibilidade ou processo.",
        ]

    return [
        "Perceber se ha impacto real no trabalho diario ou apenas mais uma vaga de hype.",
        "Ligar a noticia a developers, DevOps, seguranca ou utilizadores finais.",
        "Avaliar se a mudanca e estrutural ou so mais uma feature de ciclo curto.",
    ]


def build_angles(item: NewsItem) -> list[str]:
    if item.source.category == "cybersecurity":
        return [
            "Que licao pratica fica para equipas tecnicas depois desta noticia.",
            "Onde termina a urgencia real e onde comeca o exagero do ciclo de seguranca.",
            "Se o problema exposto e tecnico, operacional ou sobretudo de processo.",
        ]

    return [
        "Separar o que mudou de verdade do que ainda parece marketing.",
        "Explicar o impacto concreto para quem trabalha em engenharia, operacao ou seguranca.",
        "Dar uma leitura critica: tendencia real ou apenas mais uma iteracao barulhenta.",
    ]


def build_notes(item: NewsItem) -> list[str]:
    notes = [
        "Validar datas, nomes proprios e claims antes de fechar o artigo.",
        "Explicar acronimos e chavoes no proprio texto sempre que aparecerem.",
        "Se usares humor, musica, carros ou mitologia, manter subtil e contextual.",
    ]
    if item.matched_keywords:
        notes.append(
            "Palavras-chave apanhadas na recolha: " + ", ".join(sorted(set(item.matched_keywords)))
        )
    return notes


def build_markdown(item: NewsItem) -> str:
    queue_date = datetime.now(timezone.utc).date().isoformat()
    published_at = item.published_at.isoformat() if item.published_at else ""
    slug_hint = slugify(item.title)

    matched_keywords = sorted(set(item.matched_keywords))
    keyword_block = "\n".join(f'  - {quote_yaml(keyword)}' for keyword in matched_keywords)
    if not keyword_block:
        keyword_block = "  - \"news\""

    lines = [
        "---",
        f"title: {quote_yaml(item.title)}",
        f"date: {quote_yaml(queue_date)}",
        f"category: {quote_yaml(item.source.category)}",
        "status: \"pending\"",
        f"source_name: {quote_yaml(item.source.name)}",
        f"source_url: {quote_yaml(item.source.url)}",
        f"article_url: {quote_yaml(item.link)}",
        f"published_at: {quote_yaml(published_at)}",
        f"slug_hint: {quote_yaml(slug_hint)}",
        f"score: {item.score}",
        "matched_keywords:",
        keyword_block,
        "---",
        "",
        "## Resumo factual",
        item.summary or "Sem resumo no feed. Ler a fonte antes de escrever o artigo.",
        "",
        "## Porque importa",
        bullets(build_why_it_matters(item)),
        "",
        "## Angulos possiveis",
        bullets(build_angles(item)),
        "",
        "## Notas para o writer",
        bullets(build_notes(item)),
        "",
    ]
    return "\n".join(lines)


def parse_front_matter_value(text: str, key: str) -> str:
    pattern = re.compile(rf"^{re.escape(key)}:\s*\"?(.*?)\"?\s*$", re.MULTILINE)
    match = pattern.search(text)
    return match.group(1).strip() if match else ""


def published_date_from_queue_file(path: Path) -> datetime | None:
    try:
        text = path.read_text(encoding="utf-8", errors="ignore")
    except OSError:
        return None

    for key in ("published_at", "date"):
        value = parse_front_matter_value(text, key)
        parsed = parse_datetime(value)
        if parsed is not None:
            return parsed

    date_match = re.match(r"(\d{4}-\d{2}-\d{2})-", path.name)
    if date_match:
        try:
            parsed = datetime.fromisoformat(date_match.group(1))
            return parsed.replace(tzinfo=timezone.utc)
        except ValueError:
            return None

    return None


def prune_stale_queue_files(output_dir: Path, cutoff: datetime) -> list[Path]:
    removed: list[Path] = []
    if not output_dir.exists():
        return removed

    for path in output_dir.glob("*.md"):
        if path.name in {"README.md", "SHORTLIST.md"}:
            continue
        published_date = published_date_from_queue_file(path)
        if published_date is None:
            continue
        if published_date < cutoff:
            path.unlink(missing_ok=True)
            removed.append(path)
    return removed


def compute_cutoff(config: dict, days: int) -> datetime:
    recency_mode = config.get("recency_mode", "rolling_days")
    now = datetime.now(timezone.utc)
    if recency_mode == "current_week":
        start_of_week = now - timedelta(days=now.weekday())
        return start_of_week.replace(hour=0, minute=0, second=0, microsecond=0)
    return now - timedelta(days=days)


def collect_items(
    config: dict,
    output_dir: Path,
    posts_dir: Path,
    days: int,
    limit_per_feed: int,
    limit_total: int,
) -> list[tuple[Path, str]]:
    output_dir.mkdir(parents=True, exist_ok=True)
    known_urls = dedupe_urls([output_dir, posts_dir])

    include_keywords = config.get("include_keywords", [])
    priority_keywords = config.get("priority_keywords", [])
    block_keywords = config.get("block_keywords", [])
    cutoff = compute_cutoff(config, days)
    prune_stale_queue_files(output_dir, cutoff)

    ranked_items: list[NewsItem] = []
    for source_data in config.get("sources", []):
        source = FeedSource(
            name=source_data["name"],
            category=source_data["category"],
            url=source_data["url"],
            kind=source_data.get("kind", "auto"),
        )

        try:
            raw_text = fetch_text(source.url)
            raw_items = parse_feed(raw_text, source.kind)
        except (urllib.error.URLError, TimeoutError, ValueError, ET.ParseError, json.JSONDecodeError) as exc:
            print(f"[warn] failed to fetch {source.name}: {exc}", file=sys.stderr)
            continue

        source_ranked: list[NewsItem] = []
        for title, link, summary, published_at in raw_items:
            if link in known_urls:
                continue
            item = rank_item(
                source=source,
                title=title,
                link=link,
                summary=summary,
                published_at=published_at,
                include_keywords=include_keywords,
                priority_keywords=priority_keywords,
                block_keywords=block_keywords,
                cutoff=cutoff,
            )
            if item is None:
                continue
            source_ranked.append(item)

        source_ranked.sort(
            key=lambda item: (
                item.score,
                item.published_at or datetime.min.replace(tzinfo=timezone.utc),
            ),
            reverse=True,
        )
        ranked_items.extend(source_ranked[:limit_per_feed])

    ranked_items.sort(
        key=lambda item: (
            item.score,
            item.published_at or datetime.min.replace(tzinfo=timezone.utc),
        ),
        reverse=True,
    )

    queued: list[tuple[Path, str]] = []
    for item in ranked_items[:limit_total]:
        path = output_dir / queue_filename(item)
        if path.exists():
            continue
        queued.append((path, build_markdown(item)))
    return queued


def main() -> int:
    args = parse_args()
    config_path = Path(args.config)
    output_dir = Path(args.output_dir)
    posts_dir = Path(args.posts_dir)
    config = load_config(config_path)

    days = args.days or config.get("default_days", 3)
    limit_per_feed = args.limit_per_feed or config.get("default_limit_per_feed", 4)
    limit_total = args.limit_total or config.get("default_total_limit", 10)

    queued = collect_items(
        config=config,
        output_dir=output_dir,
        posts_dir=posts_dir,
        days=days,
        limit_per_feed=limit_per_feed,
        limit_total=limit_total,
    )

    if not queued:
        print("No new items queued.")
        return 0

    for path, markdown in queued:
        if args.dry_run:
            print(f"[dry-run] would create {path}")
        else:
            path.write_text(markdown, encoding="utf-8")
            print(f"Created {path}")

    print(f"Queued {len(queued)} item(s).")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
