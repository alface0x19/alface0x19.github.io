#!/usr/bin/env python3
from __future__ import annotations

import argparse
import re
import sys
import unicodedata
from difflib import SequenceMatcher
from pathlib import Path


CVE_RE = re.compile(r"\bCVE-\d{4}-\d{4,}\b", re.IGNORECASE)
FRONT_MATTER_RE = re.compile(r"^---\n(.*?)\n---\n", re.DOTALL)
KEY_RE = re.compile(r"^(?P<key>[A-Za-z0-9_-]+):\s*\"?(?P<value>.*?)\"?\s*$", re.MULTILINE)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Check whether a queued news item is already covered by an existing post."
    )
    parser.add_argument("--queue-file", required=True, help="Path to the queued news markdown file.")
    parser.add_argument("--posts-dir", default="_posts", help="Directory containing published posts.")
    return parser.parse_args()


def read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8", errors="ignore")


def parse_front_matter(text: str) -> dict[str, str]:
    match = FRONT_MATTER_RE.match(text)
    if not match:
        return {}
    block = match.group(1)
    data: dict[str, str] = {}
    for item in KEY_RE.finditer(block):
        data[item.group("key")] = item.group("value").strip()
    return data


def slugify(value: str) -> str:
    normalized = unicodedata.normalize("NFKD", value).encode("ascii", "ignore").decode("ascii")
    normalized = normalized.lower()
    normalized = re.sub(r"[^a-z0-9]+", "-", normalized).strip("-")
    return normalized


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


def check_duplicate(queue_path: Path, posts_dir: Path) -> tuple[bool, str]:
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


def main() -> int:
    args = parse_args()
    queue_path = Path(args.queue_file)
    posts_dir = Path(args.posts_dir)

    if not queue_path.exists():
      print(f"Queue file not found: {queue_path}", file=sys.stderr)
      return 1

    if not posts_dir.exists():
        print("OK: diretorio de posts inexistente, nada a comparar.")
        return 0

    duplicate, reason = check_duplicate(queue_path, posts_dir)
    if duplicate:
        print(f"ALREADY_COVERED: {reason}")
        return 2

    print(f"OK: {reason}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
