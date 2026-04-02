# News Automation

Este repositório agora tem um fluxo simples e dividido por responsabilidades:

- RSS/feeds para recolher notícias;
- agentes do Copilot CLI para curar, escrever, rever, validar e publicar;
- cron local para meter novas notícias na fila do repo.
- Só entram notícias da semana corrente; a fila limpa automaticamente itens antigos.

## Estrutura

- `config/news_sources.json`: lista de feeds e keywords.
- `scripts/fetch_news.py`: recolhe notícias e cria ficheiros em `news_queue/`.
- `scripts/collect_news_queue.sh`: wrapper para recolha local, pensado para cron.
- `scripts/install_news_cron.sh`: instala ou atualiza a entrada de cron local.
- `scripts/curate_news_queue.sh`: usa o agente curador para priorizar a fila.
- `scripts/run_copilot_news_pipeline.sh`: pega numa notícia da fila e chama os agentes.
- `_drafts/`: rascunhos em trabalho antes de irem para `_posts/`.

## Fluxo recomendado

1. O cron local corre a recolha em horários definidos.
2. Novas notícias aparecem em `news_queue/`.
3. Opcionalmente corres:

```bash
scripts/curate_news_queue.sh
```

4. Escolhes uma notícia da fila, ou segues a recomendação criada pelo curador.
5. Corres:

```bash
scripts/run_copilot_news_pipeline.sh news_queue/<ficheiro>.md
```

Ou, se quiseres usar diretamente a notícia escolhida em `SHORTLIST.md`:

```bash
scripts/run_copilot_news_pipeline.sh --selected
```

6. O script chama:
- `tech-news-opinion-writer`
- `blog-editor`
- `post-quality-gate`
  O resultado fica em `_drafts/`.

7. Se estiver tudo bem, publicas com:

```bash
scripts/run_copilot_news_pipeline.sh news_queue/<ficheiro>.md --publish
```

Ou:

```bash
scripts/run_copilot_news_pipeline.sh --selected --publish
```

8. Nesse modo, o script chama também o `main-publisher`.
   Antes disso, move o artigo terminado de `_drafts/` para `_posts/`.

## Notas

- O coletor não escreve artigos. Só prepara matéria-prima.
- A fila é limitada a notícias da semana corrente para evitar temas já frios.
- O `news-curator` ajuda a separar o que parece promissor do que parece só ruído ou hype.
- O `post-quality-gate` faz a última revisão para evitar PT-BR, casing técnico errado e texto com cheiro a geração automática.
- Um artigo só entra em `_posts/` quando já estiver terminado e pronto a publicar.
- O writer/editor continuam a ser usados apenas onde faz sentido.
- Se usares Copilot Free, este desenho ajuda a poupar requests porque a recolha não depende da IA.
- O cron local não faz push. Apenas atualiza o repositório na tua máquina.
