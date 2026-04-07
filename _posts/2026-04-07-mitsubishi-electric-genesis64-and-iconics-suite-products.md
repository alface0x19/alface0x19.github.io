---
title: "Mitsubishi Electric, credenciais SQL em claro e a velha chave debaixo do tapete em OT"
date: 2026-04-07
categories: [Segurança, OT, Vulnerabilidades]
tags: [Mitsubishi Electric, ICONICS Suite, GENESIS64, GENESIS, Hyper Historian, CVE-2025-14815, CVE-2025-14816]
---

Há falhas que assustam pela sofisticação. E depois há as outras, que assustam por serem básicas demais para ainda existirem. O novo aviso da CISA sobre vários produtos da Mitsubishi Electric e da ICONICS entra sem cerimónia nessa segunda gaveta: em certos cenários, credenciais do SQL Server podem ficar guardadas em claro na cache local.

![Imagem de capa do artigo]({{ site.baseurl }}/assets/images/posts/2026-04-07-mitsubishi-electric-genesis64-and-iconics-suite-products/cover.svg)

Isto não tem nada de especialmente cinematográfico. Não é Loki a trocar de forma dentro da rede nem um thriller de intrusão remota. É mais o equivalente industrial a deixar a chave do templo debaixo do tapete e chamar-lhe controlo de acesso. Em `OT` (tecnologia operacional) e `ICS` (sistemas de controlo industrial), um descuido destes chega para criar sabotagem, perda de dados ou paragem operacional sem grande esforço dramático.

Segundo a CISA, com base na informação do fabricante, há duas falhas principais. A `CVE-2025-14815` expõe credenciais do SQL Server em ficheiros locais quando a cache local com SQLite está ativa e a ligação à base de dados usa `SQL authentication`, ou seja, autenticação com utilizador e palavra-passe do próprio SQL Server. A `CVE-2025-14816` faz algo semelhante no `Hyper Historian Splitter`, mostrando essas credenciais em claro na interface gráfica.

Traduzido para português normal: alguém com acesso local, ou que consiga acesso indevido a uma estação afetada, pode ler credenciais, entrar no SQL Server e, a partir daí, consultar, alterar ou apagar dados. A Mitsubishi Electric refere ainda risco de `DoS` (`Denial of Service`, negação de serviço), o que neste contexto significa empurrar o sistema para indisponibilidade ou paragem.

O vetor conhecido é local, não remoto. Vale a pena sublinhar isso para não transformar o caso numa história maior do que ele é. Mas também não convém cair no erro oposto. Em redes industriais, muita coisa corre com privilégios altos, segmentação imperfeita e confiança herdada de tempos mais ingénuos. Nesses ambientes, uma falha local pode valer bem mais do que parece no papel.

Também não chega olhar para isto e dizer "há patch, siga". Há correções para várias linhas de produto, incluindo as versões `10.98` ou superiores de `GENESIS64`, `ICONICS Suite`, `MobileHMI`, `Hyper Historian` e `AnalytiX`, e a versão `11.03` ou superior de `GENESIS`. Para `MC Works64`, no entanto, não há correção planeada. Aí, a conversa deixa de ser remediação total e passa a mitigação disciplinada, com compensações operacionais bem concretas.

E a mitigação, aqui, não vem embrulhada em prosa vaga. O fabricante recomenda confirmar se a cache local está ativa, desligá-la quando fizer sentido, remover os ficheiros de cache identificados no aviso e, quando possível, trocar `SQL authentication` por `Windows authentication`, que usa autenticação integrada do Windows em vez de credenciais mantidas pela aplicação. Parece um detalhe de configuração. Muitas vezes é exatamente nesses detalhes que se decide se uma falha fica no PDF ou entra na operação.

É por isso que este caso interessa a quem gere `HMI` (interfaces homem-máquina), historians e plataformas `SCADA` (`Supervisory Control and Data Acquisition`, supervisão e controlo industrial). Antes de olhar para a pontuação `CVSS`, vale mais confirmar o básico: que produtos estão instalados, que versões correm, se a cache local está ligada, onde ficam os ficheiros locais, que contas autenticam no SQL Server e quem pode iniciar sessão nessas máquinas. Sem essa visibilidade, o problema não é só a vulnerabilidade, é o painel inteiro.

Há ainda uma lição menos glamorosa, mas mais útil. Durante anos, parte da segurança industrial foi vendida com conversa de perímetro, isolamento e muralhas. Depois aparece um caso destes e lembra uma verdade antiga: às vezes o problema não entra de aríete. Entra porque um segredo foi guardado onde nunca devia estar. Não é épico. É só básico, e talvez por isso mesmo mais perigoso.

No fim, a leitura útil desta notícia é simples. O aviso da CISA não descreve um Ragnarök digital. Descreve algo bem mais plausível e por isso mais incómodo: software industrial com escolhas de implementação e configuração que deixam credenciais expostas onde não deviam. Se usas esta stack, a pergunta certa não é quão barulhento é o `CVE`. É outra, bem mais seca: já confirmaste onde ainda dependes de `SQL authentication`, de cache local e de máquinas com privilégios a mais, e o que vais fazer nos produtos que nem correção têm? Em segurança industrial, é muitas vezes aí que o motor começa a gripar, muito antes de soar o alarme.

## Fontes

- [CISA ICS Advisory ICSA-26-097-01](https://www.cisa.gov/news-events/ics-advisories/icsa-26-097-01)
- [Mitsubishi Electric PSIRT Advisory 2025-023](https://www.mitsubishielectric.co.jp/psirt/vulnerability/pdf/2025-023.pdf)
- [ICONICS CERT Security Advisories](https://iconics.com/about/security/cert)
