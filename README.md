# Otimizador Windows 10/11

Script de diagnóstico, reparo e otimização para Windows 10 e Windows 11, escrito em Batch puro, com menu interativo, log auditável e relatório de resultados baseado em métricas medidas.

Sem dependências externas. Sem instalação. Sem telemetria.

---

## Sumário

- [Por que este projeto existe](#por-que-este-projeto-existe)
- [Recursos](#recursos)
- [Requisitos](#requisitos)
- [Como usar](#como-usar)
- [Menu de funções](#menu-de-funções)
- [O que o script deliberadamente NÃO faz](#o-que-o-script-deliberadamente-não-faz)
- [Relatório e Índice de Saúde](#relatório-e-índice-de-saúde)
- [Logs, backup e reversão](#logs-backup-e-reversão)
- [Arquitetura do código](#arquitetura-do-código)
- [Decisões técnicas](#decisões-técnicas)
- [Roadmap](#roadmap)
- [Aviso de responsabilidade](#aviso-de-responsabilidade)
- [Licença](#licença)
- [Autor](#autor)

---

## Por que este projeto existe

A maioria dos "otimizadores" de Windows que circulam na internet aplica ajustes que **degradam** o desempenho: apagam a pasta Prefetch, desabilitam o SysMain, desligam o auto-tuning do TCP e limitam núcleos no boot. Nenhum deles explica o que fez, nenhum permite desfazer, e todos exibem uma porcentagem inventada de "otimização" no final.

Este script foi construído com a premissa oposta:

- Cada alteração é registrada com o valor **antes** e **depois**
- Nada é aplicado sem confirmação explícita
- O registro é exportado antes de qualquer modificação, e existe rollback
- As métricas do relatório são **medidas**, não estimadas
- As decisões técnicas estão documentadas no próprio código, com o motivo

---

## Recursos

- **Detecção automática de ambiente** — Windows 10 ou 11 pelo número de build, notebook ou desktop pela presença de bateria, SSD ou HDD pelo `MediaType` do disco físico. As otimizações mudam conforme o perfil.
- **Varredura completa** — integridade da imagem do sistema, saúde e espaço dos discos, memória, tempo real de boot lido do Event Log, serviços críticos e pendências de reinicialização.
- **Reparo na ordem correta** — DISM antes de SFC, porque o SFC usa a imagem que o DISM repara. Invertido, ele falha.
- **Otimização guiada por hardware** — TRIM em SSD, desfragmentação em HDD, plano de energia diferente para notebook e desktop.
- **Livro-razão de alterações** — arquivo de log com uma linha por mudança, contendo categoria, descrição, valor anterior e valor novo.
- **Relatório final** — deltas medidos de espaço em disco, memória e itens de inicialização, mais um índice de saúde com fórmula aberta.
- **Rollback** — restaura os backups de registro, os planos de energia e o gerenciador de boot aos padrões.
- **Interface colorida com degradação segura** — usa sequências ANSI quando o terminal suporta e cai para texto limpo quando não suporta, sem imprimir códigos de escape na tela.

---

## Requisitos

| Item | Detalhe |
|------|---------|
| Sistema | Windows 10 build 10240 ou superior, Windows 11 |
| Privilégios | Administrador (o script se auto-eleva via UAC) |
| Dependências | Nenhuma. Usa apenas DISM, SFC, CHKDSK, defrag, bcdedit, powercfg, netsh e PowerShell, todos nativos |
| Espaço | Menos de 100 KB, mais os logs gerados |

O script **não** usa `wmic`, que foi descontinuado e removido no Windows 11 24H2.

---

## Como usar

1. Baixe o arquivo `Otimizador-Windows.bat`
2. Clique com o botão direito e escolha **Executar como administrador**

Duplo clique também funciona: o script detecta a falta de privilégio e solicita elevação via UAC automaticamente.

```
Otimizador-Windows.bat
```

Para a primeira utilização, o caminho recomendado é:

```
[1]  Varredura completa       ->  entender o estado atual
[13] Ponto de restauração     ->  rede de segurança
[11] Pacote recomendado       ->  aplicar as otimizações
     reiniciar duas vezes
[14] Relatório                ->  comparar o resultado
```

Reiniciar **duas** vezes é intencional: o primeiro boot após alterações de sistema sempre é atípico e não serve como medição.

---

## Menu de funções

| Opção | Função | Altera o sistema |
|:-----:|--------|:----------------:|
| 1 | Varredura completa do sistema | Não |
| 2 | Varredura completa de antivírus (Defender) | Não |
| 3 | Reparo de arquivos de sistema (DISM + SFC + CHKDSK) | Sim |
| 4 | Reparo dos componentes do Windows Update | Sim |
| 5 | Limpeza profunda (temp, cache, lixeira, WinSxS) | Sim |
| 6 | Otimização de discos (TRIM ou desfragmentação) | Sim |
| 7 | Otimização de boot e inicialização | Sim |
| 8 | Otimização de aplicativos e responsividade | Sim |
| 9 | Otimização de rede (DNS, Winsock, TCP/IP) | Sim |
| 10 | Auditoria de programas de inicialização | Não |
| 11 | Pacote recomendado (3 + 5 + 6 + 7 + 8) | Sim |
| 12 | Desfazer alterações | Sim |
| 13 | Criar ponto de restauração | Sim |
| 14 | Relatório de otimização | Não |
| 15 | Abrir pasta de logs | Não |

Toda opção que altera o sistema exige confirmação antes de executar.

---

## O que o script deliberadamente NÃO faz

Esta seção é tão importante quanto a lista de recursos.

| Ajuste popular | Por que ficou de fora |
|----------------|----------------------|
| Apagar `C:\Windows\Prefetch` | Destrói o mapa de pré-carregamento do Windows. A abertura de aplicativos fica **mais lenta** por dias, até o cache ser reconstruído. |
| Desabilitar SysMain / Superfetch | Mesmo efeito. O script faz o oposto: detecta se algum outro "otimizador" desligou o serviço e o **reativa**. |
| `netsh int tcp set global autotuninglevel=disabled` | Trava a janela de recepção do TCP e **reduz** a vazão em links acima de 50 Mbps. O script restaura o valor `normal`, que é o padrão da Microsoft. |
| `bcdedit /set numproc` | Limita a quantidade de núcleos usados no boot. É o contrário de otimizar. |
| `bcdedit /set useplatformclock true` | Força o HPET e aumenta a latência de temporização na maioria das máquinas modernas. |
| Desabilitar serviços em massa | Quebra Windows Update, impressão, VPN corporativa e Windows Search. Custo-benefício negativo. |
| "Limpadores" de registro | Ganho de desempenho mensurável: zero. Risco de inutilizar o sistema: real. |
| Desligar a suavização de fonte ClearType | Ganho nulo e texto ilegível em telas modernas. Otimizar não é desligar tudo. |

---

## Relatório e Índice de Saúde

O relatório da opção 14 tem cinco seções:

1. **O que foi alterado** — livro-razão completo com valores antes e depois
2. **Métricas medidas** — espaço livre, RAM e itens de inicialização, comparando o snapshot da abertura com o do momento
3. **Índice de Saúde** — pontuação de 0 a 100
4. **O que o relatório não mede** — transparência sobre os limites da medição
5. **Arquivos da sessão** — caminhos dos logs e backups

### Sobre a porcentagem de otimização

**Não existe métrica honesta de "sistema X% otimizado".** O número que otimizadores comerciais exibem é marketing, não medição. O que este projeto faz é mostrar deltas reais e um índice heurístico com a fórmula impressa na tela, para que qualquer pessoa possa auditar e discordar:

| Peso | Componente | Critério |
|:----:|------------|----------|
| 30 pts | Espaço livre no volume de sistema | 25% ou mais = 30 · 15–25% = 20 · 10–15% = 10 · abaixo de 10% = 0 |
| 15 pts | Memória RAM livre | 30% ou mais = 15 · 15–30% = 8 · menos = 0 |
| 20 pts | Serviços de desempenho ativos | SysMain, Schedule e BITS, 6,6 pts cada |
| 20 pts | Programas de inicialização | até 5 = 20 · até 10 = 12 · até 20 = 6 · acima = 0 |
| 15 pts | Uptime e pendência de reboot | menos de 7 dias e sem reboot pendente = 15 |

O tempo de boot **não** entra no índice, porque só muda após reiniciar. Ele é medido separadamente, lendo o Event ID 100 do log `Microsoft-Windows-Diagnostics-Performance` — a medição do próprio Windows, mais confiável que cronômetro.

---

## Logs, backup e reversão

Tudo é gravado em `%ProgramData%\OtimizadorWin`:

```
%ProgramData%\OtimizadorWin\
├── logs\
│   ├── execucao_AAAA-MM-DD_HH-mm-ss.log     linha do tempo da sessão
│   ├── alteracoes_AAAA-MM-DD_HH-mm-ss.log   livro-razão com antes/depois
│   └── relatorio_AAAA-MM-DD_HH-mm-ss.txt    relatório final em texto puro
└── backup\
    ├── Desktop.reg
    ├── ExplorerAdvanced.reg
    ├── VisualEffects.reg
    └── Personalize.reg
```

Antes de qualquer escrita no registro, as chaves afetadas são exportadas para `backup\`. A opção 12 reimporta esses arquivos, restaura os planos de energia com `powercfg -restoredefaultschemes` e devolve o timeout do gerenciador de boot ao padrão.

Exemplo de linha do livro-razão:

```
[14:32:07] REGISTRO | Atraso de abertura de menus em ms | antes: 400 | depois: 20
```

O valor anterior é lido com `reg query` **antes** da gravação. Sem isso, o log registraria apenas "alterado", o que é inútil para auditoria.

---

## Arquitetura do código

O script é organizado em camadas, com responsabilidades separadas:

```
Inicialização      detecção de ANSI, elevação UAC, criação de diretórios
Perfil             DETECT_PROFILE, SNAP, CALCSCORE
Menu               roteamento por goto
Módulos            DIAG, REPAIR, CLEAN, DISKOPT, BOOTOPT, APPOPT, NETOPT...
Núcleos reusáveis  REPAIR_CORE, CLEAN_CORE, DISK_CORE, BOOT_CORE, UI_CORE
Apresentação       PALETTE, H1, H2, KV, OK, WARN, ERR, INFO, NOTA, STEP
Persistência       CHANGE, REGSET, BACKUP_REG, LOG
```

Os módulos do menu e o pacote recomendado chamam os mesmos núcleos reusáveis, sem duplicação de lógica. A camada de apresentação concentra toda a identidade visual: trocar o tema inteiro é editar o bloco `PALETTE`, e nenhuma cor está espalhada pelo código de negócio.

---

## Decisões técnicas

**Texto sem acentos.** O code page do console varia conforme região e codificação do arquivo. Acento em `.bat` é a principal causa de saída corrompida e de rótulos quebrados. ASCII elimina a classe inteira de problema.

**Aritmética delegada ao PowerShell.** O `set /a` do Batch é inteiro de 32 bits com sinal e estoura acima de ~2,1 bilhões. Contagem de bytes de disco quebraria em silêncio, com resultado negativo.

**Metacaracteres sempre escapados.** O Batch não separa dados de código: qualquer `& | < > ( ) ^ %` dentro de uma string vira sintaxe executável. É injeção de comando por acidente — o mesmo mecanismo do OWASP A03 aplicado ao shell. Regra do projeto: nenhum metacaractere sem escape em qualquer `echo`.

**Defaults garantidos antes de comparação.** `if %VAR% GEQ 22000` com `VAR` vazia é erro fatal de sintaxe que encerra o interpretador. Toda variável numérica recebe valor padrão antes da coleta.

**Elevação via `cmd /k`.** Se um erro fatal ocorrer no processo elevado, a janela permanece aberta com a mensagem visível, em vez de desaparecer.

**Cor com degradação segura.** ANSI só é ativado quando há certeza de suporte (Windows Terminal, ou `VirtualTerminalLevel` já ativo, ou console criado pelo próprio script). Fora disso, as variáveis de cor viram string vazia. Falso negativo custa cor; falso positivo custa uma tela ilegível — a assimetria define o default.

**Relatório em arquivo sem cor.** A paleta é zerada antes de gerar o `.txt` e restaurada depois. Sequência ANSI dentro de arquivo de texto vira lixo em qualquer editor.

---

## Roadmap

- [ ] Porte para PowerShell com `[CmdletBinding(SupportsShouldProcess)]` e suporte a `-WhatIf`
- [ ] Log estruturado em JSON para consumo por ferramentas externas
- [ ] Relatório em HTML com gráficos de comparação
- [ ] Modo silencioso para execução via GPO ou agendador
- [ ] Perfis de otimização selecionáveis (conservador, padrão, agressivo)
- [ ] Testes automatizados com Pester em máquina virtual descartável

---

## Aviso de responsabilidade

Este script modifica configurações do sistema operacional, incluindo registro, gerenciador de boot, planos de energia, serviços e pilha de rede.

Apesar de todas as alterações serem confirmadas, registradas e reversíveis pela opção 12, **use por sua conta e risco**. Crie um ponto de restauração (opção 13) antes de aplicar qualquer otimização. O autor não se responsabiliza por perda de dados ou indisponibilidade decorrente do uso.

Atenção especial ao **Fast Startup** em máquinas com dual boot: o kernel é hibernado e a partição do Windows fica em estado sujo, com risco real de corrupção quando montada por outro sistema operacional. O script pergunta sobre isso antes de ativar.

---

## Licença

Distribuído sob a licença MIT. Consulte o arquivo `LICENSE` para o texto completo.

---

## Autor

**Eliel Filho** — Full Stack Developer

- GitHub: [@seu-usuario](https://github.com/elielfilhodev)
- LinkedIn: [seu-perfil](https://linkedin.com/in/eliel-filho-dev)

Contribuições, issues e sugestões são bem-vindas.
