@echo off
rem =====================================================================
rem  OTIMIZADOR WINDOWS 10 / 11  -  v1.2
rem  Autor: Eliel Filho  -  Full Stack Developer
rem
rem  CHANGELOG v1.2
rem   [NEW] Camada de apresentacao com cores ANSI / VT100.
rem   [NEW] Deteccao de suporte a ANSI com degradacao segura: se o
rem         terminal nao interpretar as sequencias de escape, as
rem         variaveis de cor viram string vazia e a saida sai em texto
rem         limpo. Nunca imprime lixo do tipo "ESC[92m" na tela.
rem   [NEW] Helpers de UI - H1, H2, OK, WARN, ERR, INFO, STEP - com a
rem         paleta centralizada em um unico bloco. Trocar o tema
rem         inteiro e editar a paleta, nao 300 linhas de echo.
rem
rem  CHANGELOG v1.1
rem   [FIX] Fechamento inesperado da janela. Tres causas eliminadas:
rem         1. Parentese vindo de expansao de variavel dentro de bloco
rem            if/for. O cmd expande %~1 ANTES de fechar o parse do
rem            bloco, entao o ")" do texto encerrava o bloco no lugar
rem            errado e abortava o interpretador.
rem         2. Comparacao numerica com variavel vazia.
rem         3. Janela sumindo antes de exibir o erro. A auto-elevacao
rem            passa a abrir via cmd /k.
rem   [DEL] wmic removido - descontinuado no Windows 11 24H2.
rem   [NEW] Livro-razao de alteracoes com valor antes e depois.
rem   [NEW] Snapshot de metricas e relatorio final com Indice de Saude.
rem
rem  TEXTO SEM ACENTOS: proposital. Acento em .bat e a causa numero 1
rem  de saida corrompida, porque o code page do console varia conforme
rem  regiao e codificacao do arquivo.
rem =====================================================================

setlocal EnableExtensions EnableDelayedExpansion
chcp 65001 >nul 2>&1

set "AUTOR=Eliel Filho"
set "VERSAO=1.2"
title Otimizador Windows 10/11 - v%VERSAO% - por %AUTOR%

rem ---------------------------------------------------------------------
rem  DETECCAO DE SUPORTE A ANSI
rem  Ordem de confianca:
rem    1. WT_SESSION definido = Windows Terminal, ANSI garantido.
rem    2. VirtualTerminalLevel ja valia 1 quando este console nasceu.
rem    3. Parametro ELEVATED = console criado por nos, depois de
rem       gravarmos a chave, entao ja nasceu com VT ativo.
rem  Fora desses casos assumimos que NAO ha suporte e caimos para
rem  texto limpo. Falso negativo custa cor; falso positivo custa
rem  uma tela ilegivel. A assimetria decide o default.
rem ---------------------------------------------------------------------
set "ANSI=0"
set "VTL="
for /f "tokens=3" %%A in ('reg query "HKCU\Console" /v VirtualTerminalLevel 2^>nul ^| find /i "VirtualTerminalLevel"') do set "VTL=%%A"
if "%VTL%"=="0x1" set "ANSI=1"
if defined WT_SESSION set "ANSI=1"
if /I "%~1"=="ELEVATED" set "ANSI=1"
if not "%VTL%"=="0x1" reg add "HKCU\Console" /v VirtualTerminalLevel /t REG_DWORD /d 1 /f >nul 2>&1

call :PALETTE

rem ---------------------------------------------------------------------
rem  ELEVACAO
rem  O parametro ELEVATED evita loop de UAC. Start-Process abre
rem  "cmd /k", entao um erro fatal deixa a janela aberta com a
rem  mensagem visivel em vez de sumir.
rem ---------------------------------------------------------------------
set "LAUNCHMODE=DIRETO"
if /I "%~1"=="ELEVATED" set "LAUNCHMODE=RELANCADO"

net session >nul 2>&1
if not errorlevel 1 goto ADMIN_OK

if "%LAUNCHMODE%"=="RELANCADO" goto ELEV_FAIL
echo.
call :INFO "Este script precisa de privilegios de Administrador."
call :INFO "Solicitando elevacao..."
set "SELF=%~f0"
powershell -NoProfile -Command "$q=[char]34; Start-Process -FilePath 'cmd.exe' -ArgumentList '/k',($q + $env:SELF + $q + ' ELEVATED') -Verb RunAs" >nul 2>&1
if errorlevel 1 goto ELEV_FAIL
exit /b 0

:ELEV_FAIL
echo.
call :ERR "Nao foi possivel elevar privilegios."
call :INFO "Clique com o botao direito no arquivo e escolha"
call :INFO "Executar como administrador."
echo.
pause
exit /b 1

:ADMIN_OK
if "%ANSI%"=="0" color 0B
if "%ANSI%"=="0" mode con: cols=100 lines=45 >nul 2>&1

rem ---------------------------------------------------------------------
rem  PASTAS E ARQUIVOS DE TRABALHO
rem ---------------------------------------------------------------------
set "BASEDIR=%ProgramData%\OtimizadorWin"
set "LOGDIR=%BASEDIR%\logs"
set "BKPDIR=%BASEDIR%\backup"
if not exist "%LOGDIR%" mkdir "%LOGDIR%" >nul 2>&1
if not exist "%BKPDIR%" mkdir "%BKPDIR%" >nul 2>&1

for /f "delims=" %%A in ('powershell -NoProfile -Command "Get-Date -Format yyyy-MM-dd_HH-mm-ss"') do set "TS=%%A"
if not defined TS set "TS=sessao"
set "LOG=%LOGDIR%\execucao_%TS%.log"
set "CHANGES=%LOGDIR%\alteracoes_%TS%.log"
set "REPORT=%LOGDIR%\relatorio_%TS%.txt"

set /a CNT_CHANGES=0
set /a CNT_FAIL=0

call :LOG "=== Sessao iniciada - Otimizador v%VERSAO% - autor: %AUTOR% ==="
echo Livro-razao de alteracoes - Otimizador v%VERSAO% - %TS% > "%CHANGES%"
echo ------------------------------------------------------------------- >> "%CHANGES%"

cls
call :SPLASH
call :DETECT_PROFILE
call :SNAP ANTES
goto MENU


rem =====================================================================
rem  MENU PRINCIPAL
rem =====================================================================
:MENU
cls
call :HEADER
echo   %MG%%L2%%R%
echo    %D%DIAGNOSTICO%R%
echo     %CI%[ 1]%R%  Varredura completa do sistema        %D%somente leitura%R%
echo     %CI%[ 2]%R%  Varredura completa antivirus         %D%Microsoft Defender%R%
echo.
echo    %D%REPARO%R%
echo     %CI%[ 3]%R%  Reparar arquivos de sistema          %D%DISM + SFC + CHKDSK%R%
echo     %CI%[ 4]%R%  Reparar componentes do Windows Update
echo.
echo    %D%OTIMIZACAO%R%
echo     %CI%[ 5]%R%  Limpeza profunda                     %D%temp, cache, lixeira, WinSxS%R%
echo     %CI%[ 6]%R%  Otimizar discos                      %D%TRIM em SSD / desfrag em HDD%R%
echo     %CI%[ 7]%R%  Otimizar boot e inicializacao
echo     %CI%[ 8]%R%  Otimizar abertura de aplicativos     %D%e responsividade%R%
echo     %CI%[ 9]%R%  Otimizar rede                        %D%DNS, Winsock, TCP/IP%R%
echo     %CI%[10]%R%  Auditar programas de inicializacao
echo.
echo    %D%CONTROLE%R%
echo     %VD%[11]%R%  %B%PACOTE RECOMENDADO%R%                   %D%3 + 5 + 6 + 7 + 8%R%
echo     %CI%[12]%R%  Desfazer alteracoes deste script
echo     %CI%[13]%R%  Criar ponto de restauracao
echo     %AM%[14]%R%  RELATORIO                            %D%o que mudou e quanto melhorou%R%
echo     %CI%[15]%R%  Abrir pasta de logs
echo     %VM%[ 0]%R%  Sair
echo   %MG%%L2%%R%
echo    %D%Alteracoes aplicadas nesta sessao:%R% %B%%CNT_CHANGES%%R%
echo.
set "OP="
set /p "OP=   %CI%>%R% Escolha uma opcao: "
if not defined OP goto MENU
if "%OP%"=="1"  goto DIAG
if "%OP%"=="2"  goto AVSCAN
if "%OP%"=="3"  goto REPAIR
if "%OP%"=="4"  goto WUFIX
if "%OP%"=="5"  goto CLEAN
if "%OP%"=="6"  goto DISKOPT
if "%OP%"=="7"  goto BOOTOPT
if "%OP%"=="8"  goto APPOPT
if "%OP%"=="9"  goto NETOPT
if "%OP%"=="10" goto STARTUP
if "%OP%"=="11" goto PACOTE
if "%OP%"=="12" goto ROLLBACK
if "%OP%"=="13" goto RESTOREPOINT
if "%OP%"=="14" goto RELATORIO
if "%OP%"=="15" goto OPENLOG
if "%OP%"=="0"  goto FIM
call :ERR "Opcao invalida."
timeout /t 2 >nul
goto MENU


rem =====================================================================
rem  1 - VARREDURA COMPLETA - SOMENTE LEITURA
rem =====================================================================
:DIAG
cls
call :H1 "VARREDURA COMPLETA DO SISTEMA" "somente leitura, nada e alterado"
call :LOG "Diagnostico iniciado"

call :H2 "1/8  Identidade do sistema"
call :KV "Sistema" "%OSNAME%"
call :KV "Build" "%OSBUILD%   familia %OSFAMILY%"
call :KV "Arquitetura" "%PROCESSOR_ARCHITECTURE%"
call :KV "Maquina" "%COMPUTERNAME%"
call :KV "Tipo" "%CHASSI%"
echo.

call :H2 "2/8  Tempo desde o ultimo boot"
powershell -NoProfile -Command "$b=(Get-CimInstance Win32_OperatingSystem).LastBootUpTime; $u=(Get-Date)-$b; '     Ligado ha {0}d {1}h {2}m - desde {3}' -f $u.Days,$u.Hours,$u.Minutes,$b"
echo.
call :NOTA "Uptime de semanas degrada desempenho por fragmentacao de"
call :NOTA "memoria e handles vazados. Reiniciar 1x por semana ajuda."
echo.

call :H2 "3/8  Duracao dos ultimos boots - Event Log ID 100"
powershell -NoProfile -Command "try{ $e=Get-WinEvent -FilterHashtable @{LogName='Microsoft-Windows-Diagnostics-Performance/Operational';Id=100} -MaxEvents 5 -ErrorAction Stop; foreach($x in $e){ $d=([xml]$x.ToXml()).Event.EventData.Data; $bt=0; foreach($i in $d){ if($i.Name -eq 'BootTime'){ $bt=$i.'#text' } }; '     {0:dd/MM HH:mm}   {1,6:N1} segundos' -f $x.TimeCreated,($bt/1000) } } catch { '     Log de performance indisponivel neste sistema.' }"
echo.

call :H2 "4/8  Memoria e processador"
powershell -NoProfile -Command "$c=Get-CimInstance Win32_Processor -ErrorAction SilentlyContinue; if($c -is [array]){$c=$c[0]}; $o=Get-CimInstance Win32_OperatingSystem; '     CPU .......: {0} - {1}C/{2}T' -f $c.Name.Trim(),$c.NumberOfCores,$c.NumberOfLogicalProcessors; '     RAM total .: {0:N1} GB' -f ($o.TotalVisibleMemorySize/1MB); '     RAM livre .: {0:N1} GB - {1:N0} pct em uso' -f ($o.FreePhysicalMemory/1MB),(100-($o.FreePhysicalMemory/$o.TotalVisibleMemorySize*100))"
echo.

call :H2 "5/8  Discos - tipo, saude e espaco livre"
powershell -NoProfile -Command "try{ $p=Get-PhysicalDisk -ErrorAction Stop; foreach($d in $p){ '     {0,-30} {1,-6} Saude: {2}' -f $d.FriendlyName,$d.MediaType,$d.HealthStatus } } catch { '     Enumeracao de discos fisicos indisponivel.' }"
echo.
powershell -NoProfile -Command "$v=Get-CimInstance Win32_LogicalDisk -Filter 'DriveType=3'; foreach($d in $v){ $p=[math]::Round($d.FreeSpace/$d.Size*100,0); $a='OK'; if($p -lt 10){$a='CRITICO'} elseif($p -lt 20){$a='ATENCAO'}; '     {0} {1,7:N1} GB livres de {2,7:N1} GB - {3} pct - {4}' -f $d.DeviceID,($d.FreeSpace/1GB),($d.Size/1GB),$p,$a }"
echo.
call :NOTA "Abaixo de 15 pct livre o Windows perde desempenho de escrita"
call :NOTA "e o SSD perde over-provisioning para wear leveling."
echo.

call :H2 "6/8  Servicos que otimizadores costumam quebrar"
call :CHECKSVC SysMain   "SysMain - pre-carregamento de aplicativos"
call :CHECKSVC WSearch   "Windows Search - indexacao de arquivos"
call :CHECKSVC Schedule  "Agendador de Tarefas - manutencao automatica"
call :CHECKSVC BITS      "BITS - transferencia em segundo plano"
echo.

call :H2 "7/8  Integridade da imagem - DISM CheckHealth"
DISM /Online /Cleanup-Image /CheckHealth
echo.

call :H2 "8/8  Reinicializacao pendente"
call :CHECK_PENDING
if "%PENDING%"=="1" call :WARN "Existe reinicializacao pendente. Otimizacoes podem nao ter efeito ate reiniciar."
if "%PENDING%"=="0" call :OK "Nenhuma reinicializacao pendente."

call :LOG "Diagnostico concluido"
echo.
call :VOLTAR
goto MENU


rem =====================================================================
rem  2 - VARREDURA COMPLETA DE ANTIVIRUS
rem =====================================================================
:AVSCAN
cls
call :H1 "VARREDURA COMPLETA" "Microsoft Defender"
call :NOTA "A varredura le todos os arquivos do disco."
call :NOTA "Duracao: de 30 minutos a varias horas."
echo.
choice /C SN /N /M "  Iniciar varredura completa?  [S/N]: "
if errorlevel 2 goto MENU

echo.
call :STEP "1/2" "Atualizando definicoes de virus"
powershell -NoProfile -Command "try{ Update-MpSignature -ErrorAction Stop; '        Definicoes atualizadas.' } catch { '        Falha ao atualizar: ' + $_.Exception.Message }"
echo.
call :STEP "2/2" "Executando varredura completa - nao feche a janela"
call :LOG "Defender full scan iniciado"
powershell -NoProfile -Command "try{ Start-MpScan -ScanType FullScan -ErrorAction Stop; '        Varredura concluida.' } catch { '        Falha: ' + $_.Exception.Message }"
call :CHANGE "SEGURANCA" "Varredura completa do Defender executada" "nao executada" "concluida"
echo.
call :H2 "Ultimas ameacas detectadas"
powershell -NoProfile -Command "try{ $t=Get-MpThreatDetection -ErrorAction Stop; if($t){ $u=$t[-5..-1]; foreach($i in $u){ if($i){ '     ' + $i.InitialDetectionTime + ' - ID ' + $i.ThreatID } } } else { '     Nenhuma.' } } catch { '     Historico indisponivel.' }"
call :LOG "Defender full scan concluido"
echo.
call :VOLTAR
goto MENU


rem =====================================================================
rem  3 - REPARO DE ARQUIVOS DE SISTEMA
rem  ORDEM IMPORTA: DISM repara a IMAGEM base, SFC repara os ARQUIVOS
rem  usando essa imagem. SFC antes de DISM em imagem corrompida falha.
rem =====================================================================
:REPAIR
cls
call :H1 "REPARO DE ARQUIVOS DE SISTEMA" "DISM + SFC + CHKDSK"
call :NOTA "Sequencia: DISM ScanHealth, DISM RestoreHealth, SFC, CHKDSK."
call :NOTA "A ordem importa: DISM repara a imagem base, SFC repara os"
call :NOTA "arquivos usando essa imagem. Invertido, o SFC falha."
call :WARN "Duracao estimada de 15 a 45 minutos. Nao interrompa."
echo.
choice /C SN /N /M "  Iniciar?  [S/N]: "
if errorlevel 2 goto MENU
call :REPAIR_CORE
echo.
call :NOTA "Detalhes de arquivos nao reparados ficam em:"
call :NOTA "%windir%\Logs\CBS\CBS.log"
echo.
call :VOLTAR
goto MENU


rem =====================================================================
rem  4 - REPARO DO WINDOWS UPDATE
rem =====================================================================
:WUFIX
cls
call :H1 "REPARO DO WINDOWS UPDATE" "reconstroi os caches de atualizacao"
call :NOTA "Para os servicos de update, renomeia os caches corrompidos"
call :NOTA "SoftwareDistribution e catroot2 e reinicia os servicos."
call :NOTA "O Windows recria as pastas sozinho. Operacao segura."
echo.
choice /C SN /N /M "  Continuar?  [S/N]: "
if errorlevel 2 goto MENU

call :LOG "Reparo Windows Update iniciado"
echo.
call :STEP "1/3" "Parando servicos"
for %%S in (wuauserv cryptSvc bits msiserver appidsvc) do net stop %%S >nul 2>&1
call :STEP "2/3" "Renomeando caches"
if exist "%windir%\SoftwareDistribution" ren "%windir%\SoftwareDistribution" "SoftwareDistribution.old_%TS%" >nul 2>&1
if exist "%windir%\System32\catroot2" ren "%windir%\System32\catroot2" "catroot2.old_%TS%" >nul 2>&1
call :STEP "3/3" "Reiniciando servicos"
for %%S in (appidsvc msiserver bits cryptSvc wuauserv) do net start %%S >nul 2>&1
call :CHANGE "WINDOWS UPDATE" "Caches SoftwareDistribution e catroot2 recriados" "cache antigo" "cache limpo"
call :LOG "Reparo Windows Update concluido"
echo.
call :OK "Concluido. As pastas .old podem ser apagadas depois de"
call :NOTA "confirmar que o Windows Update voltou a funcionar."
echo.
call :VOLTAR
goto MENU


rem =====================================================================
rem  5 - LIMPEZA PROFUNDA
rem =====================================================================
:CLEAN
cls
call :H1 "LIMPEZA PROFUNDA" "temporarios, cache, lixeira e WinSxS"
call :NOTA "Alvos: TEMP do usuario, TEMP do Windows, relatorios de erro,"
call :NOTA "cache do Windows Update, lixeira e componentes obsoletos."
echo.
call :WARN "A pasta Prefetch NAO sera apagada."
call :NOTA "Apagar Prefetch faz o Windows perder o mapa de pre-carga e"
call :NOTA "deixa a abertura de apps MAIS LENTA por dias, ate o cache"
call :NOTA "ser reconstruido. E o mito mais repetido da internet."
echo.
choice /C SN /N /M "  Continuar?  [S/N]: "
if errorlevel 2 goto MENU
call :CLEAN_CORE
echo.
call :H2 "Opcional avancado - ResetBase"
call :WARN "Remove TODAS as versoes antigas dos componentes. Libera"
call :WARN "bastante espaco, mas voce perde a capacidade de desinstalar"
call :WARN "atualizacoes ja aplicadas. Operacao IRREVERSIVEL."
echo.
choice /C SN /N /M "  Executar ResetBase?  Recomendado N  [S/N]: "
if errorlevel 2 goto CLEAN_END
DISM /Online /Cleanup-Image /StartComponentCleanup /ResetBase
call :CHANGE "LIMPEZA" "WinSxS ResetBase executado - irreversivel" "componentes antigos presentes" "componentes antigos removidos"
:CLEAN_END
echo.
call :VOLTAR
goto MENU


rem =====================================================================
rem  6 - OTIMIZACAO DE DISCOS
rem =====================================================================
:DISKOPT
cls
call :H1 "OTIMIZACAO DE DISCOS" "estrategia definida pelo tipo de midia"
call :KV "Midia detectada" "%DISKTYPE%"
echo.
if /I "%DISKTYPE%"=="SSD" call :NOTA "Estrategia ReTrim: informa ao controlador quais blocos estao"
if /I "%DISKTYPE%"=="SSD" call :NOTA "livres, restaurando a velocidade de escrita. Desfragmentar SSD"
if /I "%DISKTYPE%"=="SSD" call :NOTA "e inutil e consome ciclos de escrita da NAND."
if /I "%DISKTYPE%"=="HDD" call :NOTA "Estrategia de desfragmentacao e consolidacao de espaco livre."
if /I "%DISKTYPE%"=="HDD" call :NOTA "Em HDD o tempo de seek domina, entao contiguidade tem impacto."
echo.
call :NOTA "O comando defrag /O escolhe sozinho a operacao correta para"
call :NOTA "cada midia. Nao ha risco de desfragmentar um SSD."
echo.
choice /C SN /N /M "  Continuar?  [S/N]: "
if errorlevel 2 goto MENU
call :DISK_CORE
echo.
call :H2 "Manutencao automatica"
powershell -NoProfile -Command "try{ $t=Get-ScheduledTask -TaskName 'ScheduledDefrag' -ErrorAction Stop; '     Tarefa ScheduledDefrag: ' + $t.State } catch { '     Tarefa automatica nao encontrada.' }"
echo.
call :VOLTAR
goto MENU


rem =====================================================================
rem  7 - OTIMIZACAO DE BOOT
rem =====================================================================
:BOOTOPT
cls
call :H1 "OTIMIZACAO DE BOOT" "gerenciador, energia e pre-carregamento"
call :NOTA "1. Timeout do gerenciador de boot: 30s para 5s"
call :NOTA "2. Inicializacao Rapida - Fast Startup"
call :NOTA "3. Plano de energia ajustado ao tipo de maquina"
call :NOTA "4. Reativacao de SysMain e Prefetch se estiverem desligados"
call :NOTA "5. Remocao do atraso artificial de apps de inicializacao"
echo.
call :WARN "FAST STARTUP e dual boot nao combinam. Se voce tem Linux ou"
call :WARN "acessa as particoes do Windows por outro sistema, responda"
call :WARN "SIM na pergunta de dual boot: o kernel hiberna, o volume"
call :WARN "fica em estado sujo e ha risco real de corrupcao de dados."
echo.
choice /C SN /N /M "  Continuar?  [S/N]: "
if errorlevel 2 goto MENU

call :BACKUP_REG
call :LOG "Otimizacao de boot iniciada"
echo.
call :STEP "1/5" "Timeout do gerenciador de boot"
bcdedit /timeout 5 >nul 2>&1
if errorlevel 1 call :CHANGE "BOOT" "Timeout do bootloader" "30s" "FALHA - politica bloqueou"
if errorlevel 1 call :ERR "Bloqueado por politica ou Secure Boot."
if not errorlevel 1 call :CHANGE "BOOT" "Timeout do bootloader" "30s" "5s"
if not errorlevel 1 call :OK "Definido para 5 segundos."

call :STEP "2/5" "Inicializacao Rapida"
choice /C SN /N /M "        Voce usa dual boot?  [S/N]: "
if not errorlevel 2 goto BOOT_NOFAST
powercfg /hibernate on >nul 2>&1
call :REGSET "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Power" "HiberbootEnabled" "REG_DWORD" "1" "Fast Startup - hibernacao do kernel no shutdown"
call :OK "Ativada."
goto BOOT_STEP3
:BOOT_NOFAST
call :CHANGE "BOOT" "Fast Startup mantido desativado por causa do dual boot" "desativado" "desativado"
call :OK "Mantida desativada por seguranca do dual boot."

:BOOT_STEP3
call :STEP "3/5" "Plano de energia"
if /I "%CHASSI%"=="Notebook" goto BOOT_PWR_NB
powercfg /setactive SCHEME_MIN >nul 2>&1
if errorlevel 1 goto BOOT_PWR_FB
call :CHANGE "ENERGIA" "Plano de energia - desktop" "anterior" "Alto Desempenho"
call :OK "Alto Desempenho - desktop."
goto BOOT_STEP4
:BOOT_PWR_FB
powercfg /setactive SCHEME_BALANCED >nul 2>&1
call :CHANGE "ENERGIA" "Plano de energia - fallback" "anterior" "Equilibrado"
call :OK "Equilibrado - plano Alto Desempenho indisponivel."
goto BOOT_STEP4
:BOOT_PWR_NB
powercfg /setactive SCHEME_BALANCED >nul 2>&1
call :CHANGE "ENERGIA" "Plano de energia - notebook" "anterior" "Equilibrado"
call :OK "Equilibrado."
call :NOTA "Em notebook, Alto Desempenho causa throttling termico e"
call :NOTA "gasto de bateria sem ganho real de velocidade."

:BOOT_STEP4
call :STEP "4/5" "Servicos de pre-carregamento"
call :ENABLESVC SysMain
call :REGSET "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management\PrefetchParameters" "EnablePrefetcher" "REG_DWORD" "3" "Prefetcher - pre-carregamento de boot e apps"
call :REGSET "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management\PrefetchParameters" "EnableSuperfetch" "REG_DWORD" "3" "Superfetch - cache preditivo de memoria"
call :OK "Prefetch e SysMain ativos."

call :STEP "5/5" "Atraso de aplicativos de inicializacao"
call :REGSET "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Serialize" "StartupDelayInMSec" "REG_DWORD" "0" "Atraso artificial dos apps de inicializacao"
call :OK "Removido."

call :LOG "Otimizacao de boot concluida"
echo.
call :NOTA "Reinicie para medir o ganho. Depois use a opcao 1, item 3."
echo.
call :VOLTAR
goto MENU


rem =====================================================================
rem  8 - APLICATIVOS E RESPONSIVIDADE
rem =====================================================================
:APPOPT
cls
call :H1 "APLICATIVOS E RESPONSIVIDADE" "tudo em HKCU, tudo reversivel"
call :NOTA "1. Efeitos visuais priorizando desempenho"
call :NOTA "2. Atraso de menus: 400ms para 20ms"
call :NOTA "3. Animacoes de janela e barra de tarefas desativadas"
call :NOTA "4. Transparencia desativada no Windows 11"
echo.
call :NOTA "A suavizacao de fonte ClearType fica ATIVA de proposito."
call :NOTA "Sem ela o texto fica ilegivel em telas modernas, e o ganho"
call :NOTA "de desempenho e nulo. Otimizar nao e desligar tudo."
echo.
choice /C SN /N /M "  Continuar?  [S/N]: "
if errorlevel 2 goto MENU

call :BACKUP_REG
call :LOG "Otimizacao de UI iniciada"
echo.
call :STEP "1/4" "Efeitos visuais"
call :REGSET "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects" "VisualFXSetting" "REG_DWORD" "3" "Efeitos visuais - modo personalizado"
call :REGSET "HKCU\Control Panel\Desktop" "FontSmoothing" "REG_SZ" "2" "Suavizacao de fonte ClearType mantida ativa"
call :REGSET "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "TaskbarAnimations" "REG_DWORD" "0" "Animacoes da barra de tarefas"
call :STEP "2/4" "Atraso de menus"
call :REGSET "HKCU\Control Panel\Desktop" "MenuShowDelay" "REG_SZ" "20" "Atraso de abertura de menus em ms"
call :STEP "3/4" "Animacoes de janela"
call :REGSET "HKCU\Control Panel\Desktop\WindowMetrics" "MinAnimate" "REG_SZ" "0" "Animacao de minimizar e maximizar"
call :STEP "4/4" "Transparencia"
if not "%OSFAMILY%"=="Windows 11" goto APP_NOTRANSP
call :REGSET "HKCU\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" "EnableTransparency" "REG_DWORD" "0" "Transparencia Mica e Acrylic do Windows 11"
goto APP_APPLY
:APP_NOTRANSP
call :OK "Mantida - impacto baixo no Windows 10."

:APP_APPLY
call :LOG "Otimizacao de UI concluida"
echo.
call :INFO "Reiniciando o Explorer para aplicar..."
taskkill /f /im explorer.exe >nul 2>&1
timeout /t 2 >nul
start "" explorer.exe
call :OK "Pronto. Faca logoff e logon para efeito completo."
echo.
call :VOLTAR
goto MENU


rem =====================================================================
rem  9 - REDE
rem  NAO desativo o auto-tuning do TCP. Esse e o tweak mais repetido
rem  da internet e ele REDUZ a vazao em links modernos, porque trava
rem  a janela de recepcao. O correto e garantir o padrao 'normal'.
rem =====================================================================
:NETOPT
cls
call :H1 "OTIMIZACAO DE REDE" "DNS, Winsock e pilha TCP/IP"
call :WARN "A conexao cai por alguns segundos. O reset do Winsock e da"
call :WARN "pilha IP so vale apos reiniciar."
echo.
call :NOTA "O auto-tuning do TCP sera RESTAURADO ao padrao, nao"
call :NOTA "desativado. Desativar trava a janela de recepcao e reduz a"
call :NOTA "vazao em links acima de 50 Mbps."
echo.
choice /C SN /N /M "  Continuar?  [S/N]: "
if errorlevel 2 goto MENU

call :LOG "Otimizacao de rede iniciada"
echo.
call :STEP "1/6" "Limpando cache DNS"
ipconfig /flushdns >nul 2>&1
call :STEP "2/6" "Registrando DNS"
ipconfig /registerdns >nul 2>&1
call :STEP "3/6" "Renovando IP"
ipconfig /release >nul 2>&1
ipconfig /renew >nul 2>&1
call :STEP "4/6" "Reset do catalogo Winsock"
netsh winsock reset >nul 2>&1
call :STEP "5/6" "Reset da pilha TCP/IP"
netsh int ip reset >nul 2>&1
call :STEP "6/6" "Restaurando parametros TCP ao padrao Microsoft"
netsh int tcp set global autotuninglevel=normal >nul 2>&1
netsh int tcp set global ecncapability=default >nul 2>&1
call :CHANGE "REDE" "Winsock, pilha TCP/IP e cache DNS resetados" "estado anterior" "padrao de fabrica - exige reboot"
echo.
call :H2 "Estado atual da pilha TCP"
netsh int tcp show global
call :LOG "Otimizacao de rede concluida"
echo.
call :VOLTAR
goto MENU


rem =====================================================================
rem  10 - AUDITORIA DE INICIALIZACAO
rem  Deliberadamente NAO desabilita nada. Um script nao tem como saber
rem  se AgenteX.exe e bloatware ou a VPN corporativa que voce precisa.
rem =====================================================================
:STARTUP
cls
call :H1 "AUDITORIA DE INICIALIZACAO" "lista, nao desabilita"
call :NOTA "Desligar entradas sem saber o proposito de cada uma e como"
call :NOTA "derrubar servico em producao sem analise de impacto."
echo.
call :H2 "Entradas de registro Run"
powershell -NoProfile -Command "try{ $s=Get-CimInstance Win32_StartupCommand -ErrorAction Stop; foreach($i in $s){ '     {0,-24} | {1}' -f $i.Name,$i.Command } } catch { '     Nao foi possivel enumerar.' }"
echo.
call :H2 "Pasta Inicializar do usuario"
dir /b "%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup" 2>nul || echo      vazia.
echo.
call :H2 "Pasta Inicializar de todos os usuarios"
dir /b "%ProgramData%\Microsoft\Windows\Start Menu\Programs\Startup" 2>nul || echo      vazia.
echo.
call :H2 "Tarefas agendadas no logon - fora do escopo Microsoft"
powershell -NoProfile -Command "try{ $t=Get-ScheduledTask -ErrorAction Stop; $n=0; foreach($i in $t){ if($i.State -eq 'Ready' -and $i.TaskPath -notlike '\Microsoft\*'){ $g=$i.Triggers.CimClass.CimClassName; if($g -contains 'MSFT_TaskLogonTrigger'){ if($n -lt 25){ '     ' + $i.TaskName; $n++ } } } } } catch { '     Nao foi possivel enumerar.' }"
echo.
call :NOTA "Para desabilitar com medicao real, use o Gerenciador de"
call :NOTA "Tarefas: ele mostra o custo de cada item no tempo de boot."
echo.
choice /C SN /N /M "  Abrir o Gerenciador de Tarefas agora?  [S/N]: "
if not errorlevel 2 start "" taskmgr.exe
goto MENU


rem =====================================================================
rem  11 - PACOTE RECOMENDADO
rem =====================================================================
:PACOTE
cls
call :H1 "PACOTE RECOMENDADO" "reparo, limpeza, disco, boot e interface"
call :NOTA "Sequencia: ponto de restauracao, reparo de sistema, limpeza,"
call :NOTA "otimizacao de disco, boot e responsividade."
call :WARN "Tempo estimado de 40 a 90 minutos."
echo.
choice /C SN /N /M "  Iniciar?  [S/N]: "
if errorlevel 2 goto MENU
call :LOG "PACOTE COMPLETO iniciado"
call :DO_RESTOREPOINT
call :REPAIR_CORE
call :CLEAN_CORE
call :DISK_CORE
call :BOOT_CORE
call :UI_CORE
call :LOG "PACOTE COMPLETO concluido"
goto RELATORIO


rem =====================================================================
rem  12 - ROLLBACK
rem =====================================================================
:ROLLBACK
cls
call :H1 "DESFAZER ALTERACOES" "restaura backups e padroes do Windows"
if not exist "%BKPDIR%\Desktop.reg" goto ROLL_NONE
call :H2 "Backups disponiveis"
dir /b "%BKPDIR%\*.reg"
echo.
choice /C SN /N /M "  Restaurar TODOS os backups?  [S/N]: "
if errorlevel 2 goto MENU
call :LOG "Rollback iniciado"
for %%F in ("%BKPDIR%\*.reg") do reg import "%%F" >nul 2>&1
call :OK "Registro restaurado."
powercfg -restoredefaultschemes >nul 2>&1
call :OK "Planos de energia restaurados."
bcdedit /timeout 30 >nul 2>&1
call :OK "Timeout de boot restaurado para 30s."
call :CHANGE "ROLLBACK" "Backups de registro, energia e boot restaurados" "alterado" "padrao original"
call :LOG "Rollback concluido"
echo.
call :INFO "Reinicie para aplicar."
echo.
call :VOLTAR
goto MENU
:ROLL_NONE
call :WARN "Nenhum backup encontrado em:"
call :NOTA "%BKPDIR%"
echo.
call :VOLTAR
goto MENU


rem =====================================================================
rem  13 - PONTO DE RESTAURACAO
rem =====================================================================
:RESTOREPOINT
cls
call :H1 "PONTO DE RESTAURACAO" "rede de seguranca antes de alterar"
call :DO_RESTOREPOINT
call :VOLTAR
goto MENU


:OPENLOG
start "" "%LOGDIR%"
goto MENU


rem =====================================================================
rem  14 - RELATORIO FINAL
rem  Gera em arquivo e exibe. Mostra deltas MEDIDOS, nao estimativas.
rem  O arquivo sai SEM cor: sequencias ANSI em .txt viram lixo em
rem  editor de texto. Cor e para tela, nao para arquivo.
rem =====================================================================
:RELATORIO
cls
call :INFO "Coletando metricas finais..."
call :SNAP DEPOIS
set "SAVEANSI=%ANSI%"
set "ANSI=0"
call :PALETTE
call :REPORT_BUILD > "%REPORT%" 2>&1
set "ANSI=%SAVEANSI%"
call :PALETTE
cls
call :REPORT_BUILD
echo.
call :INFO "Relatorio salvo em: %REPORT%"
echo.
call :VOLTAR
goto MENU


:REPORT_BUILD
echo %CI%%L1%%R%
echo   %TI%RELATORIO DE OTIMIZACAO%R%
echo   %D%Otimizador Windows 10/11 v%VERSAO% - por %AUTOR%%R%
echo %CI%%L1%%R%
call :KV "Maquina" "%COMPUTERNAME%"
call :KV "Sistema" "%OSNAME% - build %OSBUILD%"
call :KV "Hardware" "%CHASSI% - disco %DISKTYPE%"
call :KV "Sessao" "%TS%"
echo %CI%%L1%%R%
echo.
call :H2 "1.  O QUE FOI ALTERADO"
if %CNT_CHANGES%==0 call :NOTA "Nenhuma alteracao aplicada nesta sessao."
if not %CNT_CHANGES%==0 type "%CHANGES%"
echo.
echo      %D%Total de alteracoes aplicadas:%R% %B%%CNT_CHANGES%%R%
echo.
call :H2 "2.  METRICAS MEDIDAS - ANTES x DEPOIS"
powershell -NoProfile -Command "$fa=[double]'%FREE_ANTES%'; $fd=[double]'%FREE_DEPOIS%'; $tt=[double]'%TOTAL_ANTES%'; $ga=($fa/1GB); $gd=($fd/1GB); $pa=0; $pd=0; if($tt -gt 0){ $pa=($fa/$tt*100); $pd=($fd/$tt*100) }; '     Espaco livre em disco'; '       antes  : {0,8:N2} GB   {1,5:N1} pct do volume' -f $ga,$pa; '       depois : {0,8:N2} GB   {1,5:N1} pct do volume' -f $gd,$pd; '       ganho  : {0,8:N2} GB   {1,5:N1} pontos percentuais' -f ($gd-$ga),($pd-$pa)"
echo.
powershell -NoProfile -Command "$ra=[double]'%RAM_ANTES%'; $rd=[double]'%RAM_DEPOIS%'; '     Memoria RAM livre'; '       antes  : {0,5:N1} pct' -f $ra; '       depois : {0,5:N1} pct' -f $rd"
echo.
powershell -NoProfile -Command "$sa=[double]'%START_ANTES%'; $sd=[double]'%START_DEPOIS%'; '     Programas de inicializacao'; '       antes  : {0,5:N0} entradas' -f $sa; '       depois : {0,5:N0} entradas' -f $sd"
echo.
call :H2 "3.  INDICE DE SAUDE DO SISTEMA"
call :WARN "Nao existe metrica honesta de sistema X pct otimizado."
call :NOTA "Aquele numero que otimizadores comerciais exibem e"
call :NOTA "marketing, nao medicao. O indice abaixo e uma heuristica"
call :NOTA "com formula aberta, para voce auditar e discordar."
echo.
echo      %D%Composicao dos 100 pontos%R%
echo      %CI%30 pts%R%  espaco livre no volume de sistema
echo              %D%25 pct ou mais = 30  ^|  15 a 25 pct = 20%R%
echo              %D%10 a 15 pct = 10  ^|  abaixo de 10 pct = 0%R%
echo      %CI%15 pts%R%  memoria RAM livre
echo              %D%30 pct ou mais = 15  ^|  15 a 30 pct = 8  ^|  menos = 0%R%
echo      %CI%20 pts%R%  servicos de desempenho ativos
echo              %D%SysMain, Schedule e BITS - 6.6 pts cada%R%
echo      %CI%20 pts%R%  quantidade de programas de inicializacao
echo              %D%ate 5 = 20  ^|  ate 10 = 12  ^|  ate 20 = 6  ^|  acima = 0%R%
echo      %CI%15 pts%R%  uptime e pendencia de reboot
echo              %D%menos de 7 dias e sem reboot pendente = 15%R%
echo.
powershell -NoProfile -Command "$a=[double]'%SCORE_ANTES%'; $d=[double]'%SCORE_DEPOIS%'; '     Indice antes  : {0,3:N0} / 100' -f $a; '     Indice depois : {0,3:N0} / 100' -f $d; $delta=$d-$a; if($delta -gt 0){ '     Evolucao      : +{0:N0} pontos' -f $delta } elseif($delta -lt 0){ '     Evolucao      : {0:N0} pontos' -f $delta } else { '     Evolucao      : sem variacao' }"
echo.
call :H2 "4.  O QUE ESTE RELATORIO NAO MEDE"
call :NOTA "Tempo de boot: so muda apos reiniciar. Reinicie duas vezes,"
call :NOTA "porque o primeiro boot pos-alteracao sempre e atipico, e"
call :NOTA "rode a opcao 1, item 3, para ler a medicao do proprio"
call :NOTA "Windows no Event Log ID 100. Cronometro na mao nao serve."
echo.
call :NOTA "Abertura de aplicativos: depende do cache do SysMain, que"
call :NOTA "leva alguns dias de uso normal para se reconstruir."
echo.
call :H2 "5.  ARQUIVOS DESTA SESSAO"
call :KV "Execucao" "%LOG%"
call :KV "Alteracoes" "%CHANGES%"
call :KV "Backups" "%BKPDIR%"
echo %CI%%L1%%R%
exit /b 0


rem =====================================================================
rem  SUB-ROTINAS DE EXECUCAO - reutilizadas pelo pacote completo
rem =====================================================================
:REPAIR_CORE
echo.
call :H2 "Reparando sistema"
DISM /Online /Cleanup-Image /ScanHealth
DISM /Online /Cleanup-Image /RestoreHealth
sfc /scannow
chkdsk %SystemDrive% /scan
call :CHANGE "REPARO" "DISM RestoreHealth, SFC scannow e CHKDSK scan executados" "nao verificado" "verificado e reparado"
exit /b 0

:CLEAN_CORE
echo.
call :H2 "Limpando"
call :STEP "1/6" "TEMP do usuario"
call :RMTEMP "%TEMP%"
call :STEP "2/6" "TEMP do Windows"
call :RMTEMP "%windir%\Temp"
call :STEP "3/6" "Relatorios de erro"
call :RMTEMP "%ProgramData%\Microsoft\Windows\WER\ReportQueue"
call :STEP "4/6" "Cache do Windows Update"
net stop wuauserv >nul 2>&1
net stop dosvc >nul 2>&1
call :RMTEMP "%windir%\SoftwareDistribution\Download"
net start dosvc >nul 2>&1
net start wuauserv >nul 2>&1
call :STEP "5/6" "Lixeira"
powershell -NoProfile -Command "try{ Clear-RecycleBin -Force -ErrorAction Stop; '        esvaziada.' } catch { '        ja estava vazia.' }"
call :STEP "6/6" "Componentes obsoletos do WinSxS"
DISM /Online /Cleanup-Image /StartComponentCleanup
call :CHANGE "LIMPEZA" "Temporarios, relatorios de erro, cache de update, lixeira e WinSxS" "ocupando disco" "removidos"
exit /b 0

:DISK_CORE
echo.
call :H2 "Otimizando discos"
set "VOLS="
for /f "delims=" %%D in ('powershell -NoProfile -Command "try{ $v=Get-Volume -ErrorAction Stop; foreach($x in $v){ if($x.DriveType -eq 'Fixed' -and $x.DriveLetter){ $x.DriveLetter } } } catch { 'C' }"') do set "VOLS=!VOLS! %%D"
if not defined VOLS set "VOLS= C"
for %%D in (%VOLS%) do (
    echo.
    call :STEP "vol" "Volume %%D:"
    defrag %%D: /O /U
)
call :CHANGE "DISCO" "Otimizacao de volumes fixos - TRIM ou desfragmentacao conforme midia" "%DISKTYPE% nao otimizado" "otimizado"
exit /b 0

:BOOT_CORE
echo.
call :H2 "Otimizando boot"
call :BACKUP_REG
bcdedit /timeout 5 >nul 2>&1
call :CHANGE "BOOT" "Timeout do bootloader" "30s" "5s"
call :ENABLESVC SysMain
call :REGSET "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management\PrefetchParameters" "EnablePrefetcher" "REG_DWORD" "3" "Prefetcher - pre-carregamento de boot e apps"
call :REGSET "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Serialize" "StartupDelayInMSec" "REG_DWORD" "0" "Atraso artificial dos apps de inicializacao"
if /I "%CHASSI%"=="Notebook" goto BC_NB
powercfg /setactive SCHEME_MIN >nul 2>&1
call :CHANGE "ENERGIA" "Plano de energia - desktop" "anterior" "Alto Desempenho"
exit /b 0
:BC_NB
powercfg /setactive SCHEME_BALANCED >nul 2>&1
call :CHANGE "ENERGIA" "Plano de energia - notebook" "anterior" "Equilibrado"
exit /b 0

:UI_CORE
echo.
call :H2 "Ajustando responsividade"
call :BACKUP_REG
call :REGSET "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects" "VisualFXSetting" "REG_DWORD" "3" "Efeitos visuais - modo personalizado"
call :REGSET "HKCU\Control Panel\Desktop" "MenuShowDelay" "REG_SZ" "20" "Atraso de abertura de menus em ms"
call :REGSET "HKCU\Control Panel\Desktop" "FontSmoothing" "REG_SZ" "2" "Suavizacao de fonte ClearType mantida ativa"
call :REGSET "HKCU\Control Panel\Desktop\WindowMetrics" "MinAnimate" "REG_SZ" "0" "Animacao de minimizar e maximizar"
call :REGSET "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "TaskbarAnimations" "REG_DWORD" "0" "Animacoes da barra de tarefas"
exit /b 0

:DO_RESTOREPOINT
call :INFO "Criando ponto de restauracao..."
powershell -NoProfile -Command "try{ Enable-ComputerRestore -Drive ($env:SystemDrive + '\') -ErrorAction SilentlyContinue; Checkpoint-Computer -Description 'OtimizadorWin' -RestorePointType 'MODIFY_SETTINGS' -ErrorAction Stop; '     Ponto criado com sucesso.' } catch { '     Falha ao criar ponto de restauracao.'; '     Causas comuns: Protecao do Sistema desativada, ou ja existe'; '     um ponto criado nas ultimas 24h, que e o limite do Windows.' }"
call :CHANGE "SEGURANCA" "Ponto de restauracao solicitado" "sem ponto recente" "solicitado"
exit /b 0


rem =====================================================================
rem  CAMADA DE APRESENTACAO
rem  Toda a identidade visual vive aqui. Alterar o tema do script
rem  inteiro e alterar este bloco - nenhuma cor fica espalhada pelo
rem  codigo de negocio. Separacao de responsabilidades vale em batch
rem  tanto quanto em qualquer outra linguagem.
rem =====================================================================
:PALETTE
if "%ANSI%"=="0" goto PALETTE_PLAIN
for /f %%a in ('echo prompt $E ^| cmd') do set "E=%%a"
set "R=%E%[0m"
set "B=%E%[1m"
set "D=%E%[90m"
set "VM=%E%[91m"
set "VD=%E%[92m"
set "AM=%E%[93m"
set "AZ=%E%[94m"
set "MG=%E%[95m"
set "CI=%E%[96m"
set "BR=%E%[97m"
set "TI=%E%[1;96m"
set "L1=================================================================================="
set "L2=----------------------------------------------------------------------------------"
exit /b 0
:PALETTE_PLAIN
set "R="
set "B="
set "D="
set "VM="
set "VD="
set "AM="
set "AZ="
set "MG="
set "CI="
set "BR="
set "TI="
set "L1=================================================================================="
set "L2=----------------------------------------------------------------------------------"
exit /b 0

:SPLASH
echo.
echo   %TI%   OTIMIZADOR WINDOWS 10 / 11%R%
echo   %D%   versao %VERSAO%  -  por %AUTOR%%R%
echo.
echo   %CI%%L2%%R%
call :INFO "Coletando perfil da maquina..."
if "%ANSI%"=="0" call :NOTA "Cores serao ativadas na proxima execucao deste script."
exit /b 0

:HEADER
echo  %CI%%L1%%R%
echo   %TI%OTIMIZADOR WINDOWS 10 / 11%R%   %D%v%VERSAO%  -  por %AUTOR%%R%
echo  %CI%%L1%%R%
echo   %D%Sistema%R% %BR%%OSNAME%%R%  %D%Build%R% %OSBUILD%  %D%^|%R% %CHASSI%  %D%^|%R% Disco %DISKTYPE%
echo   %D%Log%R% %D%%LOG%%R%
exit /b 0

:H1
rem  %1 titulo  %2 subtitulo
echo  %CI%%L1%%R%
echo   %TI%%~1%R%   %D%%~2%R%
echo  %CI%%L1%%R%
echo.
exit /b 0

:H2
echo   %AM%%~1%R%
echo   %D%%L2%%R%
exit /b 0

:KV
rem  %1 rotulo  %2 valor
echo    %D%%~1%R%  %BR%%~2%R%
exit /b 0

:OK
echo      %VD%[ OK ]%R%  %~1
exit /b 0

:WARN
echo      %AM%[AVISO]%R% %~1
exit /b 0

:ERR
echo      %VM%[FALHA]%R% %~1
exit /b 0

:INFO
echo      %AZ%[ i ]%R%   %~1
exit /b 0

:NOTA
echo      %D%%~1%R%
exit /b 0

:STEP
rem  %1 contador  %2 descricao
echo   %CI%[%~1]%R% %BR%%~2%R%
exit /b 0


rem =====================================================================
rem  LIVRO-RAZAO E HELPERS DE SISTEMA
rem =====================================================================
:CHANGE
rem  %1 categoria  %2 descricao  %3 valor antes  %4 valor depois
set /a CNT_CHANGES+=1
echo      [%time:~0,8%] %~1 ^| %~2 ^| antes: %~3 ^| depois: %~4 >> "%CHANGES%"
call :LOG "ALTERACAO %~1 - %~2 - de %~3 para %~4"
exit /b 0

:REGSET
rem  %1 chave  %2 valor  %3 tipo  %4 dado  %5 descricao
rem  Le o valor atual ANTES de gravar, para o relatorio registrar o
rem  par antes/depois em vez de apenas "alterado".
set "OLD=nao definido"
for /f "tokens=2,*" %%A in ('reg query "%~1" /v "%~2" 2^>nul ^| find /i "%~2"') do set "OLD=%%B"
reg add "%~1" /v "%~2" /t %~3 /d "%~4" /f >nul 2>&1
set "NEWV=%~4"
if errorlevel 1 set "NEWV=FALHA - nao aplicado"
if errorlevel 1 set /a CNT_FAIL+=1
call :CHANGE "REGISTRO" "%~5" "!OLD!" "!NEWV!"
exit /b 0

:BACKUP_REG
if exist "%BKPDIR%\Desktop.reg" exit /b 0
reg export "HKCU\Control Panel\Desktop" "%BKPDIR%\Desktop.reg" /y >nul 2>&1
reg export "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "%BKPDIR%\ExplorerAdvanced.reg" /y >nul 2>&1
reg export "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects" "%BKPDIR%\VisualEffects.reg" /y >nul 2>&1
reg export "HKCU\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" "%BKPDIR%\Personalize.reg" /y >nul 2>&1
call :LOG "Backup de registro criado em %BKPDIR%"
exit /b 0

:RMTEMP
rem  Apaga o CONTEUDO da pasta, nunca a pasta. Erros suprimidos de
rem  proposito: arquivo em uso e esperado, nao e falha.
if not exist "%~1" goto RMTEMP_END
del /f /s /q "%~1\*.*" >nul 2>&1
for /d %%X in ("%~1\*") do rd /s /q "%%X" >nul 2>&1
:RMTEMP_END
call :OK "concluido"
exit /b 0

:CHECKSVC
rem  %1 servico  %2 descricao SEM parenteses
rem  Parentese vindo de %~2 dentro de bloco if quebra o parser do cmd,
rem  entao este helper usa goto no lugar de if/else com bloco.
set "SVCSTART=2"
set "SVCSTATE=desconhecido"
for /f "tokens=3" %%S in ('sc qc "%~1" 2^>nul ^| find "START_TYPE"') do set "SVCSTART=%%S"
for /f "tokens=3" %%S in ('sc query "%~1" 2^>nul ^| find "STATE"') do set "SVCSTATE=%%S"
if "!SVCSTART!"=="4" goto CHECKSVC_BAD
echo      %VD%[ OK ]%R%  %~2  %D%estado !SVCSTATE!%R%
exit /b 0
:CHECKSVC_BAD
echo      %VM%[ALERTA]%R% %~2
echo              %D%Servico DESABILITADO. Corrija na opcao 7.%R%
exit /b 0

:ENABLESVC
sc config "%~1" start= auto >nul 2>&1
sc start "%~1" >nul 2>&1
call :CHANGE "SERVICO" "Servico %~1 configurado para inicio automatico" "estado anterior" "automatico"
exit /b 0

:CHECK_PENDING
set "PENDING=0"
reg query "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending" >nul 2>&1 && set "PENDING=1"
reg query "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired" >nul 2>&1 && set "PENDING=1"
exit /b 0

:SNAP
rem  %1 = ANTES ou DEPOIS. Captura metricas para o relatorio.
rem  Toda a aritmetica fica no PowerShell: batch e inteiro de 32 bits
rem  com sinal e estoura em contagem de bytes de disco.
set "TAG=%~1"
set "FREE_%TAG%=0"
set "TOTAL_%TAG%=0"
set "RAM_%TAG%=0"
set "START_%TAG%=0"
set "SCORE_%TAG%=0"
for /f "delims=" %%A in ('powershell -NoProfile -Command "$d=Get-PSDrive C -ErrorAction SilentlyContinue; if($d){[int64]$d.Free}else{0}"') do set "FREE_%TAG%=%%A"
for /f "delims=" %%A in ('powershell -NoProfile -Command "$d=Get-PSDrive C -ErrorAction SilentlyContinue; if($d){[int64]($d.Free + $d.Used)}else{0}"') do set "TOTAL_%TAG%=%%A"
for /f "delims=" %%A in ('powershell -NoProfile -Command "$o=Get-CimInstance Win32_OperatingSystem; [math]::Round($o.FreePhysicalMemory/$o.TotalVisibleMemorySize*100,1)"') do set "RAM_%TAG%=%%A"
for /f "delims=" %%A in ('powershell -NoProfile -Command "$s=@(Get-CimInstance Win32_StartupCommand -ErrorAction SilentlyContinue); $s.Count"') do set "START_%TAG%=%%A"
call :CALCSCORE %TAG%
exit /b 0

:CALCSCORE
rem  Indice de Saude 0-100. Formula aberta, impressa no relatorio.
for /f "delims=" %%A in ('powershell -NoProfile -Command "$s=0; $d=Get-PSDrive C -ErrorAction SilentlyContinue; $pd=0; if($d -and ($d.Free+$d.Used) -gt 0){$pd=$d.Free/($d.Free+$d.Used)*100}; if($pd -ge 25){$s+=30}elseif($pd -ge 15){$s+=20}elseif($pd -ge 10){$s+=10}; $o=Get-CimInstance Win32_OperatingSystem; $pr=$o.FreePhysicalMemory/$o.TotalVisibleMemorySize*100; if($pr -ge 30){$s+=15}elseif($pr -ge 15){$s+=8}; foreach($n in @('SysMain','Schedule','BITS')){ $sv=Get-Service -Name $n -ErrorAction SilentlyContinue; if($sv -and $sv.StartType -ne 'Disabled'){$s+=6.6} }; $st=@(Get-CimInstance Win32_StartupCommand -ErrorAction SilentlyContinue).Count; if($st -le 5){$s+=20}elseif($st -le 10){$s+=12}elseif($st -le 20){$s+=6}; $up=((Get-Date)-$o.LastBootUpTime).TotalDays; $rb=Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired'; if($up -lt 7 -and -not $rb){$s+=15}; [math]::Round($s,0)"') do set "SCORE_%~1=%%A"
exit /b 0

:DETECT_PROFILE
rem  Todos os valores recebem default ANTES da coleta. Variavel vazia
rem  em comparacao numerica e erro fatal de sintaxe no cmd.
set "OSNAME=Windows"
set "OSBUILD=0"
set "OSFAMILY=Desconhecido"
set "CHASSI=Desktop"
set "DISKTYPE=Indefinido"
for /f "delims=" %%A in ('powershell -NoProfile -Command "(Get-CimInstance Win32_OperatingSystem).Caption.Trim()"') do set "OSNAME=%%A"
for /f "delims=" %%A in ('powershell -NoProfile -Command "[Environment]::OSVersion.Version.Build"') do set "OSBUILD=%%A"
if not defined OSBUILD set "OSBUILD=0"
if !OSBUILD! GEQ 22000 set "OSFAMILY=Windows 11"
if !OSBUILD! GEQ 10240 if !OSBUILD! LSS 22000 set "OSFAMILY=Windows 10"
for /f "delims=" %%A in ('powershell -NoProfile -Command "if(Get-CimInstance Win32_Battery -ErrorAction SilentlyContinue){'Notebook'}else{'Desktop'}"') do set "CHASSI=%%A"
for /f "delims=" %%A in ('powershell -NoProfile -Command "try{ $m=@(); $p=Get-PhysicalDisk -ErrorAction Stop; foreach($x in $p){$m += $x.MediaType}; $j=$m -join ','; if($j -match 'SSD'){'SSD'}elseif($j -match 'HDD'){'HDD'}else{'Indefinido'} }catch{'Indefinido'}"') do set "DISKTYPE=%%A"
call :LOG "Perfil: %OSNAME% build %OSBUILD% - %CHASSI% - disco %DISKTYPE%"
exit /b 0

:LOG
echo [%date% %time%] %~1 >> "%LOG%"
exit /b 0

:VOLTAR
echo   %D%%L2%%R%
pause
exit /b 0

:FIM
cls
call :H1 "SESSAO ENCERRADA" "Otimizador v%VERSAO% - por %AUTOR%"
call :KV "Alteracoes aplicadas" "%CNT_CHANGES%"
call :KV "Execucao" "%LOG%"
call :KV "Alteracoes" "%CHANGES%"
call :KV "Backups" "%BKPDIR%"
echo.
if %CNT_CHANGES% GTR 0 call :INFO "Reinicie o computador para aplicar tudo."
if %CNT_CHANGES% GTR 0 call :NOTA "Depois rode a opcao 14 para comparar o resultado."
echo.
call :LOG "=== Sessao encerrada - %CNT_CHANGES% alteracoes ==="
timeout /t 5 >nul
if "%LAUNCHMODE%"=="RELANCADO" exit
endlocal
exit /b 0
