---
title: "A AWS quer registar os teus agentes"
date: 2026-04-09
categories: [IA, Cloud, Empresas]
tags: [AWS, AWS Agent Registry, AgentCore, agentes, governação, MCP, A2A]
---

Há anúncios de IA que entram como um solo de guitarra fora de tempo: fazem barulho, ocupam espaço e fingem profundidade. O `AWS Agent Registry` podia ter sido um desses momentos. Mais um nome pomposo, mais uma consola, mais uma promessa de "scale".

Só que aqui há uma mudança real. A AWS não está só a lançar uma feature para equipas brincarem aos agentes. Está a tentar transformar agentes de IA em ativos registáveis, reutilizáveis e governáveis dentro da empresa. Traduzido: menos demo, mais controlo.

![Imagem de capa do artigo]({{ site.baseurl }}/assets/images/posts/2026-04-09-aws-wants-to-register-your-ai-agents/cover.jpg)

A tese útil desta notícia é simples. Quando um hyperscaler decide que o próximo passo é criar um catálogo para agentes, tools, skills e até `MCP servers`, não está a vender magia. Está a admitir que o problema já não é construir um agente. É saber quantos existem, quem os aprovou, quem os pode usar e quando um deles devia ter sido desativado há três sprints.

Segundo a peça da *The New Stack*, a AWS lançou o `AWS Agent Registry` na quinta-feira, 9 de abril de 2026, como parte do `AWS AgentCore`, a sua oferta para construir e pôr agentes em produção. O mais interessante é que o registo não foi apresentado como algo fechado à AWS. A empresa diz que quer indexar agentes criados em `AWS`, noutras clouds e até em ambientes on-premises.

Isto importa porque o mundo real não vive num slide bonito. Numa empresa minimamente grande, os agentes vão nascer em todo o lado: numa equipa de plataforma, num produto interno, num SaaS com demasiada autonomia ou naquela experiência paralela que alguém montou sem avisar ninguém. O fenómeno já tem nome oficioso, mesmo que nem sempre se admita: `agent sprawl`.

`Sprawl`, aqui, é simples: proliferação descontrolada. Tal como aconteceu com `VMs`, containers, dashboards e APIs, agora começa a acontecer com agentes. E o problema não é só custo ou duplicação de trabalho. É visibilidade.

Sem visibilidade, não sabes o que já existe. Duplica-se capacidade, reaproveita-se mal, dão-se acessos a coisas que ninguém auditou e cria-se um ambiente onde "autonomia" passa facilmente a significar "ninguém sabe muito bem quem fez isto". Em linguagem menos polida: um parque automóvel cheio de carros sem matrícula, estacionados em segunda fila.

É por isso que o registo interessa mais do que parece. A AWS descreve-o como um catálogo de metadados para agentes, tools, `MCP servers`, skills e respetivas capacidades, protocolos e formas de invocação. Também diz que o sistema consegue recolher essa informação a partir de endpoints `MCP` e `Agent-to-Agent`, ou `A2A`, o protocolo pensado para comunicação entre agentes. Isso reduz atrito técnico e aproxima o registo de uma função muito menos glamorosa e muito mais valiosa: inventário.

E inventário, no enterprise, vale quase sempre mais do que brilho. É a base da governação.

`Governance` é uma dessas palavras que costuma chegar com cheiro a PowerPoint. Aqui, porém, significa coisas bem concretas: definir quem pode publicar agentes, quem os pode descobrir, quais estão aprovados para uso e quando deixam de o estar. A AWS fala em permissões, workflows de aprovação e remoção de agentes no fim de vida.

Isto não resolve tudo. Não impede maus agentes. Não elimina `shadow AI`, isto é, sistemas e usos de IA que aparecem fora dos canais formais de controlo. E também não garante qualidade só porque algo está registado. Um diretório mau continua a ser um diretório mau. Mas muda uma coisa estrutural: torna a existência desses ativos explícita.

Esse detalhe tem peso. Durante o último ano, o mercado falou de agentes quase sempre como se o desafio principal fosse capacidade: mais autonomia, mais raciocínio, mais tool use, mais orchestration. A conversa adulta começa noutro lado. Começa quando alguém pergunta quem é dono do agente, que permissões tem, que protocolo usa, em que contexto pode ser reutilizado e como entra na auditoria.

É também por isso que esta jogada da AWS me parece menos sobre inovação visível e mais sobre a camada de controlo. Se a cloud conseguir ser o sítio onde os agentes são registados, descobertos, aprovados e observados, então ganha muito mais do que consumo de `compute`. Ganha centralidade operacional.

A concorrência já percebeu isso. A própria *The New Stack* nota que a Microsoft já tinha avançado com uma abordagem de controlo e governação para agentes, e que a Google também tem camadas de governação neste espaço. No open source, há projetos mais neutros a tentar ocupar o mesmo terreno. Ou seja, ninguém está a discutir se esta camada vai existir. A discussão é quem fica com as chaves.

Para developers e equipas de plataforma, a lição não é "a AWS inventou o futuro". Não inventou. A lição mais útil é outra: o mercado está a aceitar que agentes vão deixar de ser experiências isoladas e passar a ser objetos formais da infraestrutura empresarial.

Quando isso acontece, muda a conversa. A pergunta deixa de ser "que agente é mais esperto?" e passa a ser "que stack me deixa gerir isto sem perder o controlo?". E essa é, francamente, a primeira pergunta adulta que este segmento fez em bastante tempo.

Se o `AWS Agent Registry` pegar, não será por parecer futurista. Será porque responde ao problema velho e aborrecido que toda a tecnologia séria acaba por encontrar: catálogo, aprovação, ownership e fim de vida. Nada disto fica bonito numa keynote. Mas é exatamente aqui que a brincadeira começa a parecer produção.

Resta a pergunta honesta: queremos mesmo um ecossistema de agentes sem matrícula, ou estamos finalmente a admitir que autonomia sem registo é só caos com branding melhor?

## Fontes

- [The New Stack: AWS wants to register your AI agents](https://thenewstack.io/aws-wants-to-register-your-ai-agents/)
- [AWS Weekly Roundup: AWS DevOps Agent & Security Agent GA, Product Lifecycle updates, and more (April 6, 2026)](https://aws.amazon.com/blogs/aws/aws-weekly-roundup-aws-devops-agent-security-agent-ga-product-lifecycle-updates-and-more-april-6-2026/)
