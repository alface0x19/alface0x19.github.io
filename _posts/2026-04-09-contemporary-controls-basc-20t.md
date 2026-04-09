---
title: "A falha crítica no BASC 20T é só metade da história"
date: 2026-04-09
categories: [Segurança, OT, Vulnerabilidades]
tags: [CISA, Contemporary Controls, BASC 20T, BASControl20, CVE-2025-13926, PLC, ICS, OT]
---

Há avisos de segurança que fazem mais barulho do que estrago. Este não é um deles. O caso do `Contemporary Controls BASC 20T` parece menos um alarme histérico e mais aquele carro velho que ainda pega à segunda e, mesmo assim, insiste em sair para a autoestrada. Traz `CVSS` 9.8, uma `CVE` com mau aspeto e potencial para mexer a sério num `PLC` (`Programmable Logic Controller`, controlador lógico programável). Mas a parte mais interessante não está no número da pontuação. Está no estado do equipamento.

A tese é simples: isto pesa menos por ser "mais uma vulnerabilidade crítica" e mais por mostrar o custo acumulado de manter equipamento `OT` (`Operational Technology`, tecnologia operacional) velho, obsoleto e ainda em serviço. Quando a nota de mitigação diz, sem rodeios, que o produto já é obsoleto, a conversa deixa de ser só sobre patching. Passa a ser sobre fim de vida, exposição de rede e disciplina operacional.

Isso muda a conversa. Um aviso destes não pede apenas que alguém abra um ticket. Pede que alguém descubra onde é que o equipamento ainda existe, quem depende dele, como comunica e quão exposto está. Em `ICS` (`Industrial Control Systems`, sistemas de controlo industrial), esse trabalho é menos glamoroso do que ler `CVEs`, mas é o que separa um susto teórico de um problema real.

Segundo a `CISA`, a falha afeta o `BASControl20` versão `3.1`, associado à linha `BASC 20T`, e pode permitir a um atacante enumerar funções do `PLC`, reconfigurar componentes, renomear, apagar, transferir ficheiros e fazer `RPCs` remotas. `RPC` significa `Remote Procedure Call`, isto é, chamadas remotas para executar ações no sistema como se viessem de um componente legítimo. O problema nasce de confiar em entradas não fiáveis para tomar decisões de segurança, classificado como `CWE-807`.

Traduzido para português normal: se alguém conseguir observar tráfego de rede e forjar pacotes, pode falar com o equipamento de forma convincente demais. Não é preciso transformar isto num filme de catástrofe industrial para perceber o incómodo. Num ambiente mal segmentado, com ativos antigos e confiança herdada de anos mais ingénuos, isto já chega para manipulação indevida de processo ou perda de controlo operacional.

Convém cortar a espuma. A advisory não diz que exista exploração pública conhecida desta falha. Isso interessa, porque evita o erro habitual de tratar qualquer `CVSS` alto como se fosse sinónimo de ataque em curso. Também não convém cair no erro oposto e encolher os ombros. Em `OT`, a ausência de exploração pública conhecida não reduz magicamente o risco de um ativo vulnerável, sobretudo quando o equipamento já deveria ter saído de circulação.

É aqui que a notícia deixa de ser sobre uma falha isolada e passa a ser sobre o estado da casa. Um produto obsoleto num ambiente industrial é como um carro antigo sem `ABS`: pode continuar a andar anos, mas ninguém deve fingir que trava como um modelo moderno. Se além disso anda numa estrada molhada, que aqui é uma rede mal segmentada ou excessivamente exposta, a surpresa não é derrapar. A surpresa é ainda haver quem trate isso como gestão normal.

A recomendação da `CISA` vai na mesma direção. Em vez de prometer uma correção simples, insiste no básico que continua a faltar em demasiados ambientes: minimizar exposição à internet, isolar redes de controlo atrás de firewalls, separar `OT` da rede de negócio e usar acesso remoto mais controlado, como `VPN` (`Virtual Private Network`). Nada disto é novo. E talvez seja precisamente isso que torna o aviso menos confortável: o problema não está só na falha, está na repetição das mesmas medidas defensivas que continuam a aparecer como recomendação de emergência.

Para equipas técnicas, o ponto útil não é "correr a atualizar", porque nem sempre existe esse caminho limpo em produto antigo. O primeiro passo é inventário real. Onde está este equipamento? Está acessível a partir de que segmentos? Há sniffing plausível naquele tráfego? Existe autenticação, filtragem ou segmentação suficiente para impedir que alguém dentro da rede faça estragos? Sem essas respostas, o `9.8` serve mais para decoração do que para decisão.

Também há uma lição para gestão de risco. Muitas organizações continuam a tratar obsolescência em `OT` como tema de orçamento futuro, não como risco presente. Só que um ativo fora de ciclo de vida não envelhece em silêncio. Vai acumulando dependências, exceções, acessos especiais e conhecimento tribal. Quando sai uma advisory destas, o susto não vem apenas do que a falha permite. Vem do facto de ninguém querer descobrir, em cima da hora, que aquele controlador ainda suporta um processo crítico que "um dia destes" ia ser substituído.

No fim, é isso que esta notícia realmente diz. A `CVE-2025-13926` merece atenção, sim. Mas o sinal mais valioso é outro: em segurança industrial, o risco sério começa muitas vezes antes do exploit, quando um equipamento obsoleto continua operacional, visível e demasiado confiante na boa vontade da rede. Se usas este tipo de stack, a pergunta certa não é se o título "falha crítica" gera cliques. É mais seca: quantos `PLCs` velhos ainda tens a fazer de conta que são contemporâneos?

## Fontes

- https://www.cisa.gov/news-events/ics-advisories/icsa-26-099-01
- https://www.ccontrols.com/support/contacttech.htm
