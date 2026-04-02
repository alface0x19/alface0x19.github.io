# News Queue

Esta pasta guarda notícias recolhidas automaticamente via RSS/feeds.
Só devem permanecer aqui notícias da semana corrente.

Cada ficheiro Markdown aqui dentro serve como matéria-prima para o fluxo editorial:

1. O coletor cria um ficheiro por notícia.
2. O `news-curator` pode fazer a triagem e escolher as mais relevantes.
3. O `tech-news-opinion-writer` cria um rascunho em `_drafts/`.
4. O `blog-editor` faz o polimento final.
5. O `post-quality-gate` faz a última revisão de qualidade.
6. O artigo terminado é movido para `_posts/`.
7. O `main-publisher` pode fazer o commit e push para `main`.

Comandos úteis:

```bash
python3 scripts/fetch_news.py
scripts/curate_news_queue.sh
scripts/run_copilot_news_pipeline.sh news_queue/<ficheiro>.md
scripts/run_copilot_news_pipeline.sh --selected
scripts/run_copilot_news_pipeline.sh news_queue/<ficheiro>.md --publish
```
