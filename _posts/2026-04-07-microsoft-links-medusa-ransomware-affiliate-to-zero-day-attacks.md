---
title: "Medusa, zero-days e o problema que começa antes do ransomware"
date: 2026-04-07
categories: [Segurança, Ransomware, Vulnerabilidades]
tags: [Microsoft, Medusa, Storm-1175, zero-day, n-day, patching, ataque-perimetro]
---

Há notícias de ransomware que parecem novas, mas no fundo só mudam a decoração do palco. A análise da Microsoft sobre o grupo `Storm-1175`, associado ao ecossistema `Medusa`, não impressiona por ligar um afiliado de ransomware a `zero-days`. Impressiona porque volta a mostrar a mesma velha falha de origem: a distância entre uma vulnerabilidade conhecida e a sua exploração real continua curta demais.

O ponto principal não é "os atacantes ficaram subitamente brilhantes", embora também haja evolução. O ponto principal é mais chato e mais útil: demasiadas organizações ainda tratam sistemas expostos à internet como se o patch pudesse esperar pela próxima janela, pela próxima reunião ou pelo ritual normal de mudança. E, entretanto, o relógio já arrancou.

Segundo a Microsoft, o `Storm-1175` explorou ativos web expostos em várias operações e, em alguns casos, passou de acesso inicial a exfiltração de dados e execução de ransomware em 24 horas. A empresa diz também que o grupo usou mais de 16 vulnerabilidades desde 2023, sobretudo `n-days`, ou seja, falhas já conhecidas publicamente e para as quais já existe correção ou mitigação. Ainda assim, houve pelo menos três `zero-days`, incluindo casos em `SmarterMail` e `GoAnywhere MFT` antes da divulgação pública.

É aqui que a conversa fica mais interessante. O `zero-day` chama sempre mais atenção, como um solo de guitarra metido no meio do refrão. Mas o motor da campanha continua a ser outra coisa: exploração rápida de vulnerabilidades conhecidas em serviços expostos. De `Exchange` a `ScreenConnect`, de `TeamCity` a `SimpleHelp`, o padrão é menos glamoroso e muito mais repetível.

Quando isto resulta, raramente é por magia técnica. Normalmente havia um servidor acessível, um patch atrasado, visibilidade fraca sobre o perímetro e, depois da entrada, permissões suficientes para acelerar. A própria Microsoft descreve esse caminho: criação de contas novas, abuso de ferramentas legítimas de administração remota, movimento lateral via `RDP` (Remote Desktop Protocol), `PsExec` ou software `RMM` (Remote Monitoring and Management), roubo de credenciais a partir de `LSASS` com ajuda de ferramentas como `Mimikatz`, desativação de defesas e só depois o golpe final com `Medusa`.

Posto de forma simples, o ransomware não é o início do incidente. É o encore. Quando aparece no palco, a banda já montou meia infraestrutura dentro da rede.

Por isso, a leitura útil desta notícia não é "um grupo de ransomware agora também usa zero-days". Isso é verdade, mas é só a superfície. O mais relevante é o padrão industrializado de ataque ao perímetro. Serviços web vulneráveis continuam a ser uma porta demasiado fácil, e isso diz mais sobre fragilidade operacional do que sobre génio ofensivo.

Também convém limpar algum vocabulário, porque estas siglas aparecem sempre como se toda a gente tivesse recebido a nota interna. Um `zero-day` é uma falha explorada antes de existir patch ou divulgação pública. Um `n-day` é a versão menos cinematográfica do problema: a falha já é conhecida, mas continua por corrigir no alvo. `RMM` é software legítimo usado por equipas de IT para gerir máquinas remotamente, mas nas mãos erradas serve para persistência e movimento lateral. E `RaaS`, ransomware as a service, é o modelo de franchising do costume: alguém mantém a operação, os afiliados fazem o ataque.

Se há uma crítica que esta peça da Microsoft merece puxar para a frente, é esta: fala-se demasiado de atacantes e pouco da lentidão estrutural das organizações. O relatório é útil precisamente porque mostra a cadência do ataque. Um dia para explorar. Poucos dias para exfiltrar. Às vezes menos de uma semana até ao impacto total. Isso devia pesar mais nas conversas sobre patching, segmentação, administração remota e proteção de credenciais do que qualquer título sobre atacantes quase mitológicos. Não é Ragnarök. É pior pela banalidade.

Na prática, as perguntas importantes continuam a ser muito básicas. Que serviços estão expostos? Que versão está em produção? Que `CVEs` (Common Vulnerabilities and Exposures, o identificador público de falhas conhecidas) afetam aquela plataforma? Quanto tempo demora a isolar uma máquina comprometida? Que credenciais ficam acessíveis se alguém aterrar num servidor de borda? Se a resposta a isto demora dias, o problema já não é o atacante ter encontrado uma lança de Aquiles. É a porta continuar encostada.

Isto não significa instalar tudo à pressa e rezar para não partir produção. Significa ter disciplina para não deixar aplicações críticas expostas sem controlos compensatórios, como uma `WAF` (Web Application Firewall), um reverse proxy, uma `VPN` para acesso administrativo ou uma `DMZ` minimamente decente. E significa aceitar uma coisa pouco sexy: backup, `EDR` (Endpoint Detection and Response) e `MFA` (autenticação multifator) ajudam, mas não compensam um perímetro abandonado.

No fim, a novidade aqui nem é o `Medusa` tocar em falhas novas. A novidade, se quisermos chamar-lhe isso, é confirmar que muita defesa continua a reagir devagar a falhas velhas. Hoje o nome é `Medusa`. Amanhã muda a marca, muda o leak site, muda o press release oficioso. O padrão fica. E é esse padrão que devia tirar o sono, não o refrão da semana.

## Fontes

- https://www.microsoft.com/en-us/security/blog/2026/04/06/storm-1175-focuses-gaze-on-vulnerable-web-facing-assets-in-high-tempo-medusa-ransomware-operations/
- https://www.bleepingcomputer.com/news/security/microsoft-links-medusa-ransomware-affiliate-to-zero-day-attacks/
