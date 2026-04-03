# News Automation

Este repositório agora tem um fluxo simples e dividido por responsabilidades:

- RSS/feeds para recolher notícias;
- agentes do Copilot CLI para curar, escrever, rever, validar e publicar;
- cron local para meter novas notícias na fila do repo.
- Só entram notícias da semana corrente; a fila limpa automaticamente itens antigos.

## Estrutura

- `scripts/config/news_sources.json`: lista de feeds e keywords.
- `scripts/fetch_news.py`: recolhe notícias e cria ficheiros em `news_queue/`.
- `scripts/collect_news_queue.sh`: wrapper para recolha local, pensado para cron.
- `scripts/install_news_cron.sh`: instala ou atualiza a entrada de cron local.
- `scripts/curate_news_queue.sh`: usa o agente curador para priorizar a fila.
- `scripts/ensure_github_identity.sh`: força a conta GitHub/autoria local antes de qualquer uso do Copilot CLI.
- `scripts/run_copilot_news_pipeline.sh`: pega numa notícia da fila e chama os agentes.
- `scripts/run_news_autopilot.sh`: encadeia recolha, curadoria, escrita, revisão, quality gate e publicação.
- `_drafts/`: rascunhos em trabalho antes de irem para `_posts/`.
- `news_queue/`: fila local de trabalho; o `README.md` fica no repo, os ficheiros dinâmicos da fila ficam ignorados no git.
- Qualquer script que use `copilot` força primeiro a conta GitHub `alface0x19` e normaliza a autoria Git local para essa conta.

## Fluxo recomendado

1. O cron local corre `bash scripts/run_news_autopilot.sh` em horários definidos.
2. O autopilot recolhe notícias, atualiza `news_queue/`, faz curadoria, escreve, revê e tenta publicar sozinho.
3. Sempre que houver material suficiente, tenta publicar até 2 artigos por ronda, desde que sejam temas claramente diferentes.
4. Só publica se cada artigo passar writer, editor, quality gate e publisher.
5. No fim de uma ronda com publicação bem-sucedida, limpa o conteúdo dinâmico de `news_queue/` e valida que a worktree ficou limpa e sincronizada com `origin/main`.

## Fluxo manual

1. Novas notícias aparecem em `news_queue/`.
2. Opcionalmente corres:

```bash
bash scripts/curate_news_queue.sh
```

3. Escolhes uma notícia da fila, ou segues a recomendação criada pelo curador.
4. Corres:

```bash
bash scripts/run_copilot_news_pipeline.sh news_queue/<ficheiro>.md
```

Ou, se quiseres usar diretamente a notícia escolhida em `SHORTLIST.md`:

```bash
bash scripts/run_copilot_news_pipeline.sh --selected
```

5. O script chama:
- `tech-news-opinion-writer`
- `blog-editor`
- `post-quality-gate`
  O resultado fica em `_drafts/`.

6. Se estiver tudo bem, publicas com:

```bash
bash scripts/run_copilot_news_pipeline.sh news_queue/<ficheiro>.md --publish
```

Ou:

```bash
bash scripts/run_copilot_news_pipeline.sh --selected --publish
```

7. Nesse modo, o script chama também o `main-publisher`.
   Antes disso, move o artigo terminado de `_drafts/` para `_posts/`.

8. Se quiseres rever primeiro e publicar só depois, sem fazer o `mv` à mão, usa:

```bash
bash scripts/run_copilot_news_pipeline.sh --publish-draft _drafts/YYYY-MM-DD-slug.md
```

Nesse modo, o próprio script promove o draft para `_posts/` e chama o `main-publisher`.

## Notas

- O coletor não escreve artigos. Só prepara matéria-prima.
- A fila é limitada a notícias da semana corrente para evitar temas já frios.
- O `news-curator` ajuda a separar o que parece promissor do que parece só ruído ou hype.
- A curadoria e o pipeline travam temas já cobertos no blog; se a notícia bater num CVE ou tema já publicado, a automação procura alternativa ou aborta.
- A curadoria tenta evitar viés para um único vendor de IA e procura diversidade real de ecossistema quando há boas opções.
- Depois de publicar, a automação limpa a `news_queue/` dinâmica; fica apenas o `README.md`.
- O `post-quality-gate` faz a última revisão para evitar PT-BR, casing técnico errado e texto com cheiro a geração automática.
- Um artigo só entra em `_posts/` quando já estiver terminado e pronto a publicar.
- O writer/editor continuam a ser usados apenas onde faz sentido.
- Se usares Copilot Free, este desenho ajuda a poupar requests porque a recolha não depende da IA.
- O cron local agora pode publicar sozinho, por isso o autopilot aborta se o repo já arrancar com alterações pendentes.
- Antes de qualquer uso do `copilot`, o fluxo corre `bash scripts/ensure_github_identity.sh`, que força `gh auth switch --hostname github.com --user alface0x19` e ajusta `git config --local user.name/user.email` para essa identidade.
