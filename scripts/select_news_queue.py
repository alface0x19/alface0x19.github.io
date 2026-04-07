#!/usr/bin/env python3
"""Seleciona os melhores items da news_queue sem usar IA.

Ordena por score (campo front matter), filtra os que já estão cobertos
em _posts/ usando a mesma lógica do check_topic_uniqueness.py, e escreve
news_queue/SHORTLIST.md com os campos selected: e selected_secondary:.
"""
from __future__ import annotations

import argparse
import re
import sys
from difflib import SequenceMatcher
from pathlib import Path

CVE_RE = re.compile(r"\bCVE-\d{4}-\d{4,}\b", re.IGNORECASE)
FRONT_MATTER_RE = re.compile(r"^---\n(.*?)\n---\n", re.DOTALL)
KEY_RE = re.compile(r"^(?P<key>[A-Za-z0-9_-]+):\s*\"?(?P<value>.*?)\"?\s*$", re.MULTILINE)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Seleciona os melhores items da news_queue sem IA."
    )
    parser.add_argument("--queue-dir", default="news_queue")
    parser.add_argument("--posts-dir", default="_posts")
    parser.add_argument("--output", default="news_queue/SHORTLIST.md")
    return parser.parse_args()


def read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8", errors="ignore")


def parse_front_matter(text: str) -> dict[str, str]:
    match = FRONT_MATTER_RE.match(text)
    if not match:
        return {}
    data: dict[str, str] = {}
    for item in KEY_RE.finditer(match.group(1)):
        data[item.group("key")] = item.group("value").strip()
    return data


def slugify(value: str) -> str:
    import unicodedata
    normalized = unicodedata.normalize("NFKD", value).encode("ascii", "ignore").decode("ascii")
    return re.sub(r"[^a-z0-9]+", "-", normalized.lower()).strip("-")


def normalized_title(value: str) -> str:
    return slugify(value).replace("-", " ")


def extract_cves(*values: str) -> set[str]:
    found: set[str] = set()
    for value in values:
        for match in CVE_RE.findall(value or ""):
            found.add(match.upper())
    return found


def post_title(path: Path, text: str) -> str:
    front_matter = parse_front_matter(text)
    if "title" in front_matter and front_matter["title"]:
        return front_matter["title"]
    stem = path.stem
    if len(stem) > 11 and stem[4] == "-" and stem[7] == "-":
        stem = stem[11:]
    return stem.replace("-", " ")


def is_already_covered(queue_path: Path, posts_dir: Path) -> tuple[bool, str]:
    queue_text = read_text(queue_path)
    queue_meta = parse_front_matter(queue_text)
    queue_title = queue_meta.get("title", queue_path.stem)
    article_url = queue_meta.get("article_url", "")
    queue_cves = extract_cves(queue_title, queue_text, article_url)
    queue_title_norm = normalized_title(queue_title)

    for post_path in sorted(posts_dir.glob("*.md")):
        post_text = read_text(post_path)
        title = post_title(post_path, post_text)
        title_norm = normalized_title(title)

        if article_url and article_url in post_text:
            return True, f"mesma fonte ja referenciada em {post_path.name}"

        post_cves = extract_cves(title, post_text)
        shared_cves = sorted(queue_cves & post_cves)
        if shared_cves:
            return True, f"mesmo CVE ja coberto em {post_path.name}: {', '.join(shared_cves)}"

        similarity = SequenceMatcher(None, queue_title_norm, title_norm).ratio()
        if similarity >= 0.92:
            return True, f"titulo demasiado proximo de {post_path.name}"

    return False, "tema ainda nao coberto"


def are_too_similar(path_a: Path, meta_a: dict[str, str], path_b: Path, meta_b: dict[str, str]) -> bool:
    """Impede que primary e secondary sejam o mesmo tema disfarçado."""
    title_a = normalized_title(meta_a.get("title", path_a.stem))
    title_b = normalized_title(meta_b.get("title", path_b.stem))
    if SequenceMatcher(None, title_a, title_b).ratio() >= 0.80:
        return True

    text_a = read_text(path_a)
    text_b = read_text(path_b)
    cves_a = extract_cves(meta_a.get("title", ""), text_a)
    cves_b = extract_cves(meta_b.get("title", ""), text_b)
    if cves_a and cves_a & cves_b:
        return True

    url_a = meta_a.get("article_url", "")
    url_b = meta_b.get("article_url", "")
    if url_a and url_a == url_b:
        return True

    source_a = meta_a.get("source_name", "")
    source_b = meta_b.get("source_name", "")
    cat_a = meta_a.get("category", "")
    cat_b = meta_b.get("category", "")
    if source_a and source_a == source_b and cat_a == cat_b:
        if SequenceMatcher(None, title_a, title_b).ratio() >= 0.60:
            return True

    return False


def main() -> int:
    args = parse_args()
    queue_dir = Path(args.queue_dir)
    posts_dir = Path(args.posts_dir)
    output_path = Path(args.output)

    skip_names = {"README.md", "SHORTLIST.md"}
    candidates = [
        p for p in sorted(queue_dir.glob("*.md"))
        if p.name not in skip_names
    ]

    if not candidates:
        print("Nao ha noticias na fila para curadoria.")
        return 0

    scored: list[tuple[int, Path, dict[str, str]]] = []
    for path in candidates:
        text = read_text(path)
        meta = parse_front_matter(text)
        try:
            score = int(meta.get("score", "0"))
        except ValueError:
            score = 0
        scored.append((score, path, meta))

    scored.sort(key=lambda x: x[0], reverse=True)

    primary: Path | None = None
    secondary: Path | None = None
    primary_meta: dict[str, str] = {}
    covered_log: list[str] = []

    for score, path, meta in scored:
        covered, reason = is_already_covered(path, posts_dir)
        if covered:
            covered_log.append(f"  - {path.name}: {reason}")
            continue

        rel = f"news_queue/{path.name}"
        if primary is None:
            primary = path
            primary_meta = meta
            print(f"Principal: {path.name} (score={score})")
            continue

        if secondary is None:
            if not are_too_similar(primary, primary_meta, path, meta):
                secondary = path
                print(f"Secundaria: {path.name} (score={score})")
                break
            else:
                print(f"Ignorada (demasiado proxima da principal): {path.name}")

    if covered_log:
        print("Ignoradas por ja estarem cobertas:")
        for line in covered_log:
            print(line)

    primary_rel = f"news_queue/{primary.name}" if primary else "none"
    secondary_rel = f"news_queue/{secondary.name}" if secondary else "none"

    lines = [
        f"selected: {primary_rel}",
        f"selected_secondary: {secondary_rel}",
        "",
    ]
    if primary:
        lines.append(f"## Principal")
        lines.append(f"- Ficheiro: {primary_rel}")
        lines.append(f"- Titulo: {primary_meta.get('title', '')}")
        lines.append(f"- Score: {primary_meta.get('score', '?')}")
        lines.append(f"- Categoria: {primary_meta.get('category', '?')}")
        lines.append("")
    if secondary:
        sec_meta = parse_front_matter(read_text(secondary))
        lines.append(f"## Secundaria")
        lines.append(f"- Ficheiro: {secondary_rel}")
        lines.append(f"- Titulo: {sec_meta.get('title', '')}")
        lines.append(f"- Score: {sec_meta.get('score', '?')}")
        lines.append(f"- Categoria: {sec_meta.get('category', '?')}")
        lines.append("")

    output_path.write_text("\n".join(lines), encoding="utf-8")
    print(f"SHORTLIST.md atualizado: {output_path}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
