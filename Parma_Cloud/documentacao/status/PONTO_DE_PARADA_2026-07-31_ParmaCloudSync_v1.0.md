# Ponto de Parada - 31/07/2026

Projeto: ParmaCloudSync v1.0  
Cliente piloto: Fabri Tecidos  
Status: pronto para implantação controlada como Serviço do Windows

## Resumo Geral

Nesta etapa foi concluída praticamente toda a preparação técnica da versão 1.0 do ParmaCloudSync para execução em produção.

O projeto começou como um sincronizador funcional em Python e foi evoluído, em etapas pequenas e validadas, para uma arquitetura mais robusta, preparada para rodar continuamente e ser instalada como Serviço do Windows.

Todas as mudanças preservaram os contratos já validados:

- `config.ini` não foi alterado;
- SQL não foi alterado;
- payload da API não foi alterado;
- endpoint não foi alterado;
- modelo `Produto` não foi alterado;
- consulta Firebird não foi alterada;
- loteamento não foi alterado;
- regras de sincronização não foram alteradas;
- formato, rotação e localização do arquivo de log foram preservados.

## Validação da Sincronização

No ambiente real da Fabri Tecidos foi validado com sucesso:

- leitura do `config.ini`;
- conexão com Firebird;
- leitura de aproximadamente 3.155 produtos;
- montagem dos lotes;
- envio dos lotes para a API;
- autenticação por token;
- atualização dos produtos no Portal;
- consulta dos produtos pelo navegador.

Resultado observado:

- sincronização completa concluída com sucesso;
- aproximadamente 3.155 produtos enviados;
- 32 lotes concluídos;
- tempo médio aproximado de 16 segundos.

## Melhorias no Progresso Operacional

O progresso da sincronização foi mantido para execução manual, mas a arquitetura passou a permitir desativá-lo no modo Serviço do Windows.

Na execução manual:

- o console continua exibindo progresso;
- o operador consegue acompanhar os lotes;
- as mensagens principais continuam aparecendo;
- os detalhes operacionais continuam gravados no arquivo de log.

No Serviço do Windows:

- não há dependência de `sys.stdout`;
- o progresso visual é desativado;
- os logs continuam sendo gravados no arquivo rotativo.

## Etapa 1 - Separação Entre Sincronização e Execução Contínua

Foi criado:

- `runner.py`

Responsabilidades do `RunnerSincronizacao`:

- executar um ciclo;
- executar continuamente;
- controlar o intervalo configurado;
- capturar exceções do ciclo sem encerrar a aplicação;
- aguardar o próximo ciclo;
- permitir parada controlada com `solicitar_parada()`.

O `SincronizadorProdutos` deixou de controlar:

- `while True`;
- `sleep`;
- execução contínua;
- intervalo entre ciclos.

O `SincronizadorProdutos` ficou responsável apenas pela sincronização em si:

- consultar produtos;
- montar lotes;
- gerar payload com `produto.para_dict()`;
- enviar para API;
- registrar logs do ciclo.

## Subetapa 2.1 - Bootstrap da Aplicação

Foi criado:

- `app.py`

Função principal:

- `criar_aplicacao(usar_console=True)`

Ela centraliza a montagem de:

- configuração;
- logger;
- `BancoFirebird`;
- `ClienteApi`;
- `SincronizadorProdutos`;
- `RunnerSincronizacao`.

Foi criada a estrutura:

- `AplicacaoParmaCloudSync`

Campos:

- `config`;
- `logger`;
- `banco`;
- `runner`.

Com isso, tanto `main.py` quanto o futuro serviço reutilizam a mesma montagem, sem duplicar bootstrap.

## Subetapa 2.2 - Serviço do Windows Mínimo

Foi criado:

- `servico_windows.py`

Características implementadas:

- classe derivada de `win32serviceutil.ServiceFramework`;
- nome técnico `ParmaCloudSync`;
- nome exibido `ParmaCloudSync - ParmaSoft`;
- descrição `Sincronizador de dados do ERP ParmaSoft com a nuvem.`;
- implementação de `SvcDoRun()`;
- implementação de `SvcStop()`;
- uso de `app.criar_aplicacao(usar_console=False)`;
- uso de `RunnerSincronizacao.executar_continuamente()`;
- uso de `runner.solicitar_parada()`;
- tratamento de erro fatal;
- suporte aos comandos padrão do `pywin32` via `HandleCommandLine`.

O serviço ainda não foi instalado nem registrado no ambiente real.

## Ajustes Para Execução Sem Console

Foram ajustados:

- `logger.py`;
- `sincronizador.py`;
- `app.py`;
- `main.py`;
- `servico_windows.py`.

Em `logger.py`:

- `configurar_logger(config, usar_console=True)` permite escolher se haverá handler de console;
- em modo manual, permanece arquivo + console;
- em modo serviço, fica somente arquivo rotativo.

Em `sincronizador.py`:

- `mostrar_progresso=True` mantém o comportamento visual manual;
- `mostrar_progresso=False` evita escrita em `sys.stdout` no serviço.

Em `app.py`:

- `criar_aplicacao(usar_console=True)` propaga o modo correto para logger e sincronizador.

Em `main.py`:

- usa `criar_aplicacao(usar_console=True)`.

Em `servico_windows.py`:

- usa `criar_aplicacao(usar_console=False)`.

## Parada Controlada do Serviço

O serviço possui um `Event` próprio:

- `_parada_pendente`

Esse evento evita perda de comando STOP se o Windows solicitar parada durante a inicialização.

Fluxo normal de parada:

1. Windows envia STOP.
2. `SvcStop()` informa `SERVICE_STOP_PENDING`.
3. `SvcStop()` marca `_parada_pendente`.
4. Se a aplicação já existir, chama `runner.solicitar_parada()`.
5. O `RunnerSincronizacao` conclui o ciclo atual, se houver um em andamento.
6. O runner não inicia novo ciclo.
7. O serviço registra encerramento e informa `SERVICE_STOPPED`.

Decisão técnica:

- não interromper consulta Firebird ou envio HTTP no meio;
- concluir o ciclo atual com segurança;
- encerrar antes de iniciar o próximo ciclo.

## Pywin32

Foi adicionado ao `requirements.txt`:

- `pywin32==306`

Dependências atuais:

- `fdb==2.0.2`;
- `pywin32==306`;
- `requests==2.32.5`.

Foi confirmado pelo comportamento real do `pywin32` que o comando correto para instalar com início automático é:

```bat
venv\Scripts\python.exe servico_windows.py --startup auto install
```

Não usar:

```bat
venv\Scripts\python.exe servico_windows.py install --startup auto
```

## Testes Realizados

Foram realizados e aprovados:

- validação de sintaxe dos arquivos Python;
- validação isolada de composição com fakes;
- validação isolada do `RunnerSincronizacao`;
- validação isolada do serviço com fakes;
- teste com `sys.stdout = None`;
- parada antecipada antes de `criar_aplicacao()` terminar;
- parada durante `Event.wait()`;
- validação manual no ambiente real da Fabri Tecidos;
- `python main.py --testar-conexao`;
- `python main.py --uma-vez`;
- modo contínuo manual;
- consulta Firebird;
- envio em lotes;
- atualização dos produtos no Portal.

Validações reais confirmadas na Fabri:

- conexão Firebird validada;
- sincronização completa aprovada;
- 3.155 produtos enviados;
- 32 lotes concluídos;
- comportamento externo preservado.

## Portal Web

Foi confirmado no Portal:

- login por sessão funcionando;
- autenticação funcionando;
- pesquisa por descrição;
- pesquisa por código;
- pesquisa por código de barras;
- atualização dos produtos após sincronização.

## Arquitetura Atual

Fluxo manual:

```text
main.py
 └── criar_aplicacao(usar_console=True)
      ├── carregar_configuracao()
      ├── configurar_logger(..., usar_console=True)
      ├── BancoFirebird
      ├── ClienteApi
      ├── SincronizadorProdutos(mostrar_progresso=True)
      └── RunnerSincronizacao
           ├── executar_uma_vez()
           └── executar_continuamente()
```

Fluxo como serviço:

```text
servico_windows.py
 └── criar_aplicacao(usar_console=False)
      ├── carregar_configuracao()
      ├── configurar_logger(..., usar_console=False)
      ├── BancoFirebird
      ├── ClienteApi
      ├── SincronizadorProdutos(mostrar_progresso=False)
      └── RunnerSincronizacao
           ├── executar_continuamente()
           └── solicitar_parada()
```

## Arquivos Principais

Arquivos do núcleo:

- `main.py`;
- `app.py`;
- `runner.py`;
- `sincronizador.py`;
- `servico_windows.py`;
- `logger.py`;
- `config.py`;
- `banco.py`;
- `api.py`;
- `modelos.py`.

Arquivos auxiliares preservados:

- `diagnostico_produto.py`;
- `amostra_produtos.py`;
- `previa_json_produtos.py`.

Arquivos de implantação preparados:

- `entrega_servico_windows_fabri`;
- `INSTRUCOES_INSTALACAO_SERVICO.txt`.

## Entrega Para Instalação do Serviço

Foi preparada a pasta:

- `entrega_servico_windows_fabri`

Conteúdo:

- `app.py`;
- `logger.py`;
- `main.py`;
- `requirements.txt`;
- `servico_windows.py`;
- `sincronizador.py`;
- `INSTRUCOES_INSTALACAO_SERVICO.txt`.

Não inclui:

- `config.ini`;
- token;
- logs;
- `__pycache__`;
- `venv`;
- banco de dados;
- backups;
- arquivos auxiliares.

## Situação Atual

O ParmaCloudSync está operacional em modo manual e contínuo.

A infraestrutura de código para Serviço do Windows está pronta.

O serviço ainda não foi instalado na Fabri Tecidos.

O próximo passo é a instalação real e controlada do serviço no servidor da Fabri.

## Próxima Etapa

Sequência prevista:

1. Copiar arquivos finais da entrega.
2. Fazer backup dos arquivos atuais.
3. Instalar dependências com `venv\Scripts\python.exe`.
4. Validar `fdb`, `requests` e `pywin32`.
5. Validar sintaxe.
6. Testar execução manual antes do serviço.
7. Instalar serviço com início automático.
8. Iniciar serviço.
9. Confirmar em `services.msc`.
10. Conferir `logs\ParmaCloudSync.log`.
11. Testar parar, iniciar e reiniciar.
12. Confirmar que não existe Prompt aberto mantendo o sistema rodando.
13. Em janela apropriada, reiniciar o servidor e validar início automático após boot.

## Decisões Técnicas Importantes

- Manter `config.ini` exatamente como está.
- Não alterar payload da API.
- Não alterar SQL.
- Não alterar modelo `Produto`.
- Não alterar estrutura dos logs.
- Não duplicar regra de negócio no Serviço do Windows.
- Toda evolução futura deve reutilizar `criar_aplicacao()`.
- Toda execução contínua deve continuar centralizada em `RunnerSincronizacao`.
- A parada do serviço deve usar `runner.solicitar_parada()`.
- Parada durante ciclo deve aguardar conclusão segura do ciclo atual.
- Não interromper Firebird ou HTTP no meio da operação.

## Ponto de Retomada

Na próxima sessão, iniciar diretamente pela implantação controlada do Serviço do Windows na Fabri Tecidos.

Depois de validar funcionamento automático do serviço, considerar oficialmente concluída a versão 1.0 do ParmaCloudSync e iniciar o planejamento da versão 1.1.

---

# Atualizacao Cronologica - 01/08/2026

Em 01/08/2026, o ParmaCloudSync v1.0 foi tecnicamente aprovado em ambiente de homologacao Windows 10 do escritorio, usando copia/backup do banco da Fabri Tecidos.

O servico ainda precisa ser instalado no servidor real da Fabri Tecidos, mas o codigo e o procedimento correto de implantacao estao aprovados.

## Validacoes Aprovadas

Foram validados:

- leitura do `config.ini`;
- conexao com Firebird;
- consulta de produtos;
- envio em lotes;
- comunicacao com a API;
- execucao continua;
- tolerancia a API indisponivel;
- execucao como Servico do Windows;
- inicializacao automatica apos reiniciar o Windows;
- API da nuvem executando permanentemente via systemd/Gunicorn;
- recuperacao automatica apos reiniciar o Ubuntu;
- sincronizacao limpa de 2.958 produtos;
- login e consulta de produtos pelo navegador.

## Descoberta Critica Sobre o Erro 1053

Foi confirmado que o erro 1053 ocorria quando o Servico do Windows era instalado pelo Python do `venv`:

```bat
venv\Scripts\python.exe servico_windows.py --startup auto install
```

Nesse caso, o Windows registrava:

```text
C:\Parmasoft_Cloud\venv\pythonservice.exe
```

O modo debug retornava:

```text
PythonService was unable to locate the service manager.
Please see the event log for details.
```

A causa confirmada foi o uso do `pythonservice.exe` do `venv` como host do Servico do Windows. A falha ocorria antes de criar a aplicacao e antes de configurar o logger, por isso nenhum registro novo aparecia em `logs\ParmaCloudSync.log`.

## Runtime Oficial do Servico Windows

O Servico do Windows deve usar o Python global dedicado:

```text
C:\Python311-32\python.exe
```

Dependencias aprovadas nesse runtime:

- `fdb==2.0.2`;
- `requests==2.32.5`;
- `pywin32==306`.

O `pywin32_postinstall` deve ser executado fora do `venv`, em Prompt elevado:

```bat
C:\Python311-32\python.exe C:\Python311-32\Scripts\pywin32_postinstall.py -install
```

O servico deve ser instalado com:

```bat
cd /d C:\Parmasoft_Cloud
C:\Python311-32\python.exe servico_windows.py --startup auto install
```

Apos a instalacao, `sc qc ParmaCloudSync` deve apontar para:

```text
C:\Python311-32\pythonservice.exe
```

O `venv` pode continuar sendo usado para testes manuais, mas nunca deve ser usado como host do Servico do Windows.

## Servico Windows Aprovado

Foram aprovados:

- importacao das dependencias;
- conexao com Firebird;
- instalacao do servico;
- modo debug;
- inicio manual;
- parada controlada;
- restart;
- execucao sem Prompt aberto;
- permanencia como `RUNNING` com a API desligada;
- nova tentativa automatica a cada 300 segundos;
- inicializacao automatica apos reiniciar o Windows.

Com a API desligada, o servico registrou falha de comunicacao no log, manteve-se em execucao e aguardou o proximo ciclo. Isso confirmou tolerancia a indisponibilidade temporaria da API.

## API Permanente na DigitalOcean

Tambem foi aprovada a API permanente na nuvem:

- Ubuntu 24.04.4 LTS;
- IP `165.227.77.226`;
- pasta `/var/www/cotacao`;
- aplicacao Flask `/var/www/cotacao/api_nuvem.py`;
- objeto `api_nuvem:app`;
- venv `/var/www/cotacao/venv`;
- Gunicorn 25.1.0;
- servico systemd `parmasoft-portal.service`;
- Gunicorn com `--workers 2`;
- Firebird, Nginx e API subindo automaticamente apos reboot.

## Carga Limpa Final

A carga limpa final enviou 2.958 produtos:

- 30 lotes;
- 29 lotes de 100 registros;
- ultimo lote com 58 registros;
- HTTP 200 em todos os lotes;
- duracao aproximada de 15,59 segundos;
- contagem final na nuvem: 2.958 produtos;
- diferenca entre enviados e armazenados: 0.

## Portal Web

Foi validado no navegador:

- identificacao do cliente Fabri Tecidos;
- tela de login;
- autenticacao por sessao;
- pesquisa por descricao;
- retorno de produtos;
- exibicao de codigo, descricao, unidade, estoque e preco.

Tela atual:

```text
http://165.227.77.226:5000/static/portal/index.html?cliente=fabritecidos
```

O parametro `?cliente=fabritecidos` e obrigatorio na URL atual.

## Pendencias e Melhorias Futuras

Pendencias:

- instalacao controlada no servidor real da Fabri Tecidos;
- melhoria visual do Portal;
- URL amigavel;
- Nginx como reverse proxy;
- HTTPS;
- retirada futura da exposicao publica direta da porta 5000;
- usuario Linux especifico para o servico;
- avaliacao de paginacao, limite de pesquisa e tratamento visual de estoque negativo;
- remocao futura, em etapa separada, do `SERVICE_START_PENDING` manual de `SvcDoRun()`.

Nao misturar essas melhorias com a versao 1.0 tecnicamente aprovada.

## Novo Ponto de Parada

Foi criado o ponto de parada detalhado:

```text
documentacao/status/PONTO_DE_PARADA_2026-08-01_ParmaCloudSync_v1.0.md
```
