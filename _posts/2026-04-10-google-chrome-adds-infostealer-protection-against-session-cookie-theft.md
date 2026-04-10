---
title: "O Chrome está a dificultar a vida aos infostealers com `DBSC`"
date: 2026-04-10
categories: [Segurança, Navegadores, Identidade]
tags: [Google Chrome, DBSC, infostealer, session cookies, malware, TPM]
---

Há notícias de segurança que entram em cena com pose de blockbuster. Esta não é uma delas. É um daqueles ajustes de oficina que parecem pequenos até lhes sentires a utilidade. O Chrome 146 para Windows passa a suportar `Device Bound Session Credentials` (`DBSC`), uma proteção pensada para travar um truque muito rentável dos `infostealers`: roubar `session cookies` e reutilizar sessões já autenticadas.

Isto interessa porque ataca uma dor muito concreta. Um `session cookie` é, na prática, a prova de que já fizeste login. Se esse identificador for copiado por malware, o atacante pode entrar sem voltar a pedir palavra-passe nem MFA, `multifactor authentication`. É o equivalente digital a roubar a chave depois de o motor já estar a trabalhar.

A tese, para mim, é esta: a notícia não é "o Chrome ficou mais seguro" em abstrato. A notícia é que o browser está finalmente a meter atrito numa das rotas mais práticas para tomar contas corporativas e sessões persistentes. Isto mexe mais com identidade, acesso e resposta a incidente do que com o velho reflexo de "há patch, instala e segue".

O mecanismo é simples e merece atenção. Com `DBSC`, o Chrome cria um par de chaves criptográficas durante o login e guarda a chave privada em hardware seguro, como o `Trusted Platform Module` (`TPM`) no Windows. Depois, em vez de depender de um cookie de longa duração e portátil, a sessão passa a usar cookies curtos que só são renovados quando o browser prova ao servidor que continua a ter aquela chave no mesmo dispositivo.

Traduzindo: roubar o cookie deixa de bastar. Sem a prova de posse da chave privada, o material exfiltrado envelhece depressa e morre fora da máquina original. E aqui está o detalhe importante: o problema não é um `zero-day` com fogo de artifício. É abuso de credenciais já válidas, uma das formas mais eficazes de contornar controlos que, no papel, parecem robustos.

Há, no entanto, um detalhe que convém dizer sem perfume de marketing: `DBSC` não protege a web inteira só porque chegou ao Chrome 146. A documentação da Google mostra que isto exige integração do lado dos serviços. Os sites têm de ajustar o fluxo de autenticação, registar a sessão e aceitar o modelo de cookies curtos com prova criptográfica. O browser ganhou a peça, mas o jogo só muda onde os serviços a usarem.

Mesmo com essa nuance, a mudança é relevante. Primeiro, porque empurra a conversa para o sítio certo. Durante demasiado tempo, o mercado tratou roubo de cookies como nota de rodapé entre phishing, `EDR` e MFA. Na prática, para muita operação atacante, o atalho mais barato nem é partir a porta: é apanhar a sessão aberta. Quando isso corre bem, a organização vê atividade aparentemente legítima, a conta já está autenticada e a investigação começa tarde.

Segundo, porque sobe o custo do ataque sem pedir uma revolução ao utilizador final. Não obriga a reaprender a web, nem a inventar mais um ritual de login. Se o serviço suportar `DBSC`, a fricção principal cai do lado do atacante, que passa a precisar de mais do que uma cópia dos artefactos locais do browser. Em segurança, elevar custo e ruído já é muito. Nem sempre é preciso matar o dragão; às vezes basta obrigá-lo a fazer barulho suficiente para alguém reparar.

Mas não vale a pena transformar isto em cura milagrosa. A documentação da Google também deixa claro que, se o malware já estiver presente no momento do registo da sessão, ou se conseguir mexer em camadas mais profundas do sistema, o cenário complica-se. E isso encaixa no que já sabíamos: defesa de sessão não substitui higiene de endpoint, nem segmentação, nem telemetria decente, nem revisão séria da duração das sessões em contas sensíveis.

Também não substitui MFA. Ajuda, isso sim, a tapar uma das maneiras mais práticas de a contornar depois do login feito. MFA protege a entrada. `DBSC` tenta evitar que alguém entre pela janela com o crachá ainda preso à camisola.

Para equipas técnicas, o takeaway não é "atualizem o browser e esqueçam o assunto". Vale atualizar, sobretudo em Windows, mas vale também rever que serviços críticos dependem de sessões longas, que controlos existem para detetar reutilização de sessão e que aplicações internas ou `SaaS` podem adotar mecanismos deste género. Se a tua estratégia de identidade ainda assume que palavra-passe forte e MFA resolvem quase tudo, estás a conduzir em autoestrada a olhar só para o retrovisor.

No fundo, esta notícia interessa porque é específica. Não promete acabar com malware. Não resolve sozinha o problema dos `infostealers`. Faz algo melhor: fecha uma porta concreta que estava aberta tempo demais. Num ecossistema que adora slogans vagos sobre "mais segurança", sabe bem ver uma melhoria que aponta para um abuso real, operacional e banal.

Agora falta a parte menos glamorosa, como quase sempre. Falta adoção pelos serviços. Falta disciplina nas máquinas. Falta tratar sessão roubada como incidente de identidade, não como curiosidade forense. O Chrome fez a sua parte ao tornar o roubo de cookies menos portátil. A pergunta honesta é se o resto do stack vai acompanhar, ou se vamos continuar a fingir que o problema acaba no momento em que o utilizador passa no login.

## Fontes

- [BleepingComputer: Google Chrome adds infostealer protection against session cookie theft](https://www.bleepingcomputer.com/news/security/google-chrome-adds-infostealer-protection-against-session-cookie-theft/)
- [Chrome for Developers: Device Bound Session Credentials (DBSC)](https://developer.chrome.com/docs/web-platform/device-bound-session-credentials)
- [Google Online Security Blog: Improving the security of Chrome cookies on Windows](https://security.googleblog.com/2024/07/improving-security-of-chrome-cookies-on.html)
