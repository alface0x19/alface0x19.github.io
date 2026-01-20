---
title: Um Rato e Teclado para 2 Laptops - Synergy e Mouse Without Borders
date: 2026-01-20
categories: [Produtividade, Software]
tags: [synergy, mouse without borders, multi-os, partilha, teclado, rato]
---

## Introdução

Trabalhar com múltiplos computadores tornou-se cada vez mais comum, seja por questões profissionais ou pessoais. No entanto, ter vários ratos e teclados sobre a secretária pode ser incómodo e pouco prático - é quase como tentar tocar bateria e guitarra ao mesmo tempo, mas sem o talento do Phil Collins!

Felizmente, existem soluções que permitem controlar vários computadores com apenas um rato e um teclado. Como diz o ditado: "Um rato para os governar a todos" (desculpa, Tolkien!).

> **⚠️ Aviso Importante**: Este artigo é puramente informativo e educacional. Não recebo qualquer compensação ou patrocínio das empresas mencionadas. As opiniões expressas são baseadas em experiência pessoal e pesquisa independente.

Neste artigo, vamos explorar duas ferramentas populares:
- **Synergy**: Uma solução multi-plataforma que funciona em Windows, macOS e Linux
- **Mouse Without Borders**: Uma ferramenta gratuita da Microsoft exclusiva para Windows

## Synergy - Solução Multi-OS

### O que é o Synergy?

O Synergy é uma aplicação que permite partilhar um rato e teclado entre múltiplos computadores através da rede. O melhor de tudo é que funciona entre diferentes sistemas operativos, permitindo controlar, por exemplo, um Mac e um PC Windows com o mesmo conjunto de periféricos.

![Exemplo de uso do Synergy com múltiplos computadores](/assets/images/post-5/IMG_4957.png)

### Características Principais

- **Multi-plataforma**: Funciona em Windows, macOS e Linux
- **Partilha de área de transferência**: Copia e cola conteúdo entre computadores
- **Ligação encriptada**: Suporta SSL para comunicações seguras
- **Configuração flexível**: Permite arranjar os ecrãs em qualquer disposição
- **Atalhos personalizáveis**: Define teclas de atalho para trocar entre computadores

### Como Configurar o Synergy

#### 1. Instalação

1. Acede ao site oficial do Synergy ([symless.com/synergy](https://symless.com/synergy))
2. Descarrega a versão apropriada para cada sistema operativo
3. Instala o Synergy em todos os computadores que pretendes controlar

**Nota**: O Synergy é uma aplicação paga, mas existe uma versão de avaliação gratuita. Existe também o Synergy Core, que é open-source e gratuito.

#### 2. Configuração do Servidor

O computador onde tens o rato e teclado físicos ligados será o "servidor":

1. Abre o Synergy
2. Seleciona **"Server"** (Servidor)
3. Clica em **"Configure Server"** (Configurar Servidor)
4. Arrasta os ícones dos monitores para representar a disposição física dos teus ecrãs
5. Atribui um nome a cada computador cliente
6. Clica em **"Start"** (Iniciar)

#### 3. Configuração dos Clientes

Nos outros computadores:

1. Abre o Synergy
2. Seleciona **"Client"** (Cliente)
3. Introduz o endereço IP do computador servidor
4. Clica em **"Start"** (Iniciar)

#### 4. Encontrar o Endereço IP

**No Windows:**
```bash
ipconfig
```

**No macOS/Linux:**
```bash
ifconfig
```

Procura pelo endereço IPv4 (geralmente algo como 192.168.1.x).

### Resolução de Problemas no Synergy

**Problema**: Os computadores não se ligam

**Soluções**:
- Verifica se ambos os computadores estão na mesma rede
- Desativa temporariamente a firewall para testar
- Certifica-te de que o porto 24800 está aberto
- Verifica se os nomes dos computadores estão corretos

**Problema**: O rato move-se de forma errática

**Solução**:
- Ajusta a sensibilidade nas definições
- Verifica a qualidade da ligação de rede
- Usa uma ligação por cabo em vez de Wi-Fi para melhor desempenho

> **Dica de Produtor Musical**: Tal como numa mesa de mistura, às vezes é preciso ajustar os níveis até tudo soar harmonioso!

## Mouse Without Borders - Solução para Windows

### O que é o Mouse Without Borders?

O Mouse Without Borders é uma aplicação gratuita desenvolvida pela Microsoft que permite controlar até 4 computadores Windows com um único rato e teclado. É especialmente útil para quem trabalha exclusivamente em ambientes Windows.

### Características Principais

- **Totalmente gratuito**: Desenvolvido pela Microsoft
- **Até 4 computadores**: Controla até 4 PCs simultaneamente
- **Arrastar e largar ficheiros**: Move ficheiros entre computadores
- **Partilha de área de transferência**: Copia e cola entre PCs
- **Bloqueio sincronizado**: Bloqueia todos os computadores de uma vez
- **Fácil configuração**: Processo de instalação simplificado

### Como Configurar o Mouse Without Borders

#### 1. Instalação

1. Descarrega o Mouse Without Borders do [site oficial da Microsoft](https://www.microsoft.com/en-us/download/details.aspx?id=35460)
2. Instala a aplicação em todos os computadores Windows
3. Executa a aplicação no primeiro computador

#### 2. Configuração do Primeiro Computador

1. Ao abrir pela primeira vez, seleciona **"NO"** quando perguntarem se já instalaste noutro computador
2. A aplicação irá gerar um **código de segurança** e mostrar o **nome do computador**
3. Anota estas informações (vais precisar delas)

#### 3. Configuração dos Outros Computadores

1. Abre o Mouse Without Borders nos outros PCs
2. Seleciona **"YES"** quando perguntarem se já instalaste noutro computador
3. Introduz o **código de segurança** e o **nome do computador** do primeiro PC
4. Clica em **"LINK"**

#### 4. Organizar os Ecrãs

1. No primeiro computador, abre as definições do Mouse Without Borders
2. Vai ao separador **"Machine Setup"**
3. Arrasta os ícones dos computadores para corresponder à disposição física dos teus ecrãs
4. Guarda as configurações

### Funcionalidades Avançadas

#### Arrastar e Largar Ficheiros

Podes simplesmente arrastar ficheiros de um computador para outro passando o rato pela borda do ecrã:

1. Seleciona o ficheiro que queres mover
2. Arrasta-o até à borda do ecrã na direção do outro computador
3. Continua a arrastar para o ecrã do outro computador
4. Larga o ficheiro no destino pretendido

#### Atalhos de Teclado Úteis

- **CTRL + ALT + F12**: Bloqueia todos os computadores
- **Tecla de bloqueio + Tecla de seta**: Move o cursor para outro computador específico

#### Partilha de Área de Transferência

A área de transferência é partilhada automaticamente. Copia num computador e cola noutro - funciona sem configuração adicional!

### Resolução de Problemas no Mouse Without Borders

**Problema**: Não consegue ligar os computadores

**Soluções**:
- Verifica se todos os PCs estão na mesma rede
- Desativa temporariamente a firewall do Windows
- Certifica-te de que introduziste o código corretamente
- Reinicia ambos os computadores e tenta novamente

> **Momento Stand-up Comedy**: Se nada funcionar, faz como o clássico conselho de IT: "Já tentaste desligar e ligar outra vez?" - funciona 60% das vezes... sempre!

**Problema**: Desempenho lento

**Soluções**:
- Usa uma ligação de rede por cabo em vez de Wi-Fi
- Fecha aplicações desnecessárias
- Desativa a encriptação nas definições (apenas se estiveres numa rede segura)

## Comparação: Synergy vs Mouse Without Borders

| Característica | Synergy | Mouse Without Borders |
|---------------|---------|----------------------|
| **Preço** | Pago (com teste gratuito) | Gratuito |
| **Sistemas Operativos** | Windows, macOS, Linux | Apenas Windows |
| **Número de Computadores** | Ilimitado | Máximo 4 |
| **Transferência de Ficheiros** | Não | Sim |
| **Partilha de Área de Transferência** | Sim | Sim |
| **Encriptação** | Sim (SSL) | Sim |
| **Facilidade de Configuração** | Moderada | Fácil |
| **Suporte** | Comercial | Comunidade |

## Qual Escolher?

### Escolhe o Synergy se:
- Trabalhas com diferentes sistemas operativos (Windows, Mac, Linux)
- Precisas de controlar mais de 4 computadores
- Valorizas suporte comercial profissional
- Necessitas de funcionalidades avançadas e personalizações

### Escolhe o Mouse Without Borders se:
- Todos os teus computadores têm Windows
- Queres uma solução gratuita
- Precisas de transferir ficheiros facilmente entre computadores
- Valorizas simplicidade e facilidade de configuração

## Vantagem Extra: Ecrãs com PIP (Picture-in-Picture)

Uma configuração ainda mais produtiva é combinar estas ferramentas com um monitor que suporte **PIP (Picture-in-Picture)** ou **PBP (Picture-by-Picture)**. Esta funcionalidade permite-te visualizar dois computadores diferentes no mesmo ecrã físico, dividindo-o em duas secções.

### Benefícios de Usar PIP/PBP

**Visualização Simultânea**: Podes ver ambos os PCs ao mesmo tempo, cada um ocupando metade do ecrã (ou numa janela menor, no caso do PIP clássico).

**Menos Espaço Ocupado**: Em vez de teres dois monitores completos, usas apenas um ecrã grande (geralmente ultrawide ou 4K) com duas entradas de vídeo.

**Controlo Unificado**: Com o Synergy ou Mouse Without Borders, o teu rato e teclado movem-se livremente entre as duas "metades" do ecrã como se fossem ecrãs separados.

### Como Configurar

1. **Escolhe o monitor certo**: Procura monitores com suporte PIP/PBP (comuns em monitores profissionais de 32" ou superiores)
2. **Liga ambos os computadores**: Usa duas entradas de vídeo diferentes (por exemplo, HDMI e DisplayPort)
3. **Ativa o modo PBP**: No menu OSD do monitor, ativa o modo Picture-by-Picture
4. **Configura o Synergy/Mouse Without Borders**: Define a disposição dos ecrãs para corresponder à divisão física no monitor

### Exemplo de Configuração Ideal

- **Monitor 34" Ultrawide (3440x1440)** com PBP
- **PC 1 (Trabalho)**: Liga via DisplayPort - lado esquerdo do ecrã
- **PC 2 (Pessoal)**: Liga via HDMI - lado direito do ecrã
- **Synergy/Mouse Without Borders**: Configurado para mudar entre os dois quando o cursor passa do lado esquerdo para o direito

Desta forma, tens uma estação de trabalho extremamente eficiente com dois PCs completamente independentes, mas controlados por um único conjunto de periféricos e visualizados num único ecrã!

## Dicas para Melhor Desempenho

Independentemente da solução escolhida:

1. **Usa ligação por cabo**: Para melhor desempenho, liga os computadores à rede através de cabo Ethernet
2. **Mesma rede**: Certifica-te de que todos os computadores estão na mesma rede local
3. **Firewall**: Configura exceções na firewall para evitar bloqueios
4. **Disposição lógica**: Organiza os ecrãs virtuais de acordo com a disposição física
5. **Atualizações**: Mantém o software atualizado para melhor estabilidade
6. **Monitor com PIP/PBP**: Se possível, investe num monitor com esta funcionalidade para maximizar o aproveitamento do espaço

## Conclusão

Tanto o Synergy como o Mouse Without Borders são excelentes soluções para partilhar um rato e teclado entre múltiplos computadores. A escolha entre eles depende principalmente do teu orçamento, dos sistemas operativos que utilizas e das funcionalidades específicas que necessitas.

Para utilizadores exclusivos de Windows que procuram uma solução gratuita e fácil, o **Mouse Without Borders** é a escolha óbvia. Para ambientes multi-plataforma ou necessidades mais exigentes, o **Synergy** oferece flexibilidade adicional que justifica o investimento.

Qualquer uma destas ferramentas irá melhorar significativamente a tua produtividade ao eliminar a necessidade de múltiplos ratos e teclados, tornando o teu espaço de trabalho mais limpo e eficiente.
