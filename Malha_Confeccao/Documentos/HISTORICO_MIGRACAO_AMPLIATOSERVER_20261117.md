# Histórico de migração e homologação — AMPLIATOSERVER

Data: 17/11/2026. Este documento consolida o histórico relatado da migração e o relaciona aos fontes disponíveis. Onde não existe evidência local direta, o fato está marcado como **relatado**.

## Resumo final

A migração do Agente Malhas para o AMPLIATOSERVER foi homologada funcionalmente em 17/11/2026, segundo informação relatada. O fluxo validado foi:

```text
Flutter -> API Nuvem -> Agente AMPLIATOSERVER -> Firebird -> Painel Delphi -> Pedido de Venda
```

O teste de reinicialização efetiva do servidor ainda não foi realizado; portanto, a inicialização por boot trigger permanece pendente de comprovação prática, embora a presença do gatilho `MSFT_TaskBootTrigger` tenha sido relatada.

## Linha do tempo

1. **Preparação do pacote.** Foi auditada a estrutura do Agente Malhas, excluindo `venv`, caches, estado, logs e credenciais. O pacote passou a conter `main.py`, o diretório completo `agent` e scripts de instalação, teste, inicialização e registro de tarefa.

2. **Problema de transferência.** Foi identificado que uma transferência continha módulos Python na raiz, mas não o diretório obrigatório `agent`. Isso provocou `ModuleNotFoundError: No module named 'agent'`. O pacote foi consolidado para exigir a estrutura de pacote Python e o diagnóstico passou a usar `python -m agent.diagnostics`.

3. **Python e dependências.** Conforme relatado, o AMPLIATOSERVER recebeu Python 3.11.9 x86 e `fdb 2.0.4`. O código do pacote exige Python 3.11 de 32 bits e fixa `fdb==2.0.4`.

4. **Firebird 2.5.** Conforme relatado, o Firebird local usa `C:\Parmasoft\Dados\DADOS.FDB`. O cliente x86 foi localizado em `C:\Program Files\Firebird\Firebird_2_5\WOW64\fbclient.dll`. Os wrappers validam a arquitetura x86 e inserem esse diretório apenas no PATH do processo.

5. **Diagnóstico inicial.** HTTPS `/api/v1/health` e a conexão Firebird de leitura foram aprovados, conforme relatado. O health confirma transporte/TLS básico, mas não autenticação técnica.

6. **Tarefa agendada.** A criação via propriedade `Delay` do objeto PowerShell falhou em Windows Server 2012 R2/PowerShell 4. A solução passou a usar API COM Task Scheduler 2.0. Problemas posteriores de XML foram evitados pela API COM; a ordem da chamada `RegisterTaskDefinition` foi corrigida para incluir a definição da tarefa. A tarefa foi registrada para SYSTEM, com Boot Trigger, atraso de um minuto, `IgnoreNew` e inicialmente desativada.

7. **Autenticação e comunicação.** O agente apresentou aviso genérico de comunicação mesmo com health aprovado. A auditoria mostrou que erros HTTP e de transporte eram condensados em `CommunicationError`. O pacote consolidado passou a registrar status/categoria sem segredos e inclui sonda autenticada sem gravação, baseada em payload propositalmente incompleto.

8. **Conflito de snapshots.** O AMPLIATOSERVER registrou `HTTP 409` em `POST /api/v1/agente/vendedores/snapshot`. Os fontes da API demonstram duas causas: revisão antiga ou mesma revisão com hash diferente. A migração sem o SQLite histórico é compatível com a hipótese de revisão antiga.

9. **Diagnóstico SQLite.** Foram informadas revisões anteriores `vendedores=38435` e `catalogo=38432`. Também foi identificada diferença entre `C:\Parmasoft\AgenteMalhas\state.db` e `C:\ProgramData\ParmaSoft\AgenteMalhas\state.db`: são arquivos distintos. O caminho válido é aquele indicado por `MALHAS_AGENT_STATE_PATH` no `.env`.

10. **Backup e restauração do estado.** Foi relatado que o SQLite anterior foi copiado em backup antes de substituição e que o histórico correto foi restaurado. Essa prática preserva revisões e snapshots pendentes; o estado não deve ser apagado como correção de 409.

11. **Confirmações da API.** Foi relatado que, após a restauração do histórico correto, os snapshots foram confirmados pela API. Esse resultado não foi reproduzido localmente nesta auditoria e deve ser preservado nos logs operacionais do servidor.

12. **Homologação funcional.** O agente foi homologado funcionalmente no mesmo dia, conforme os dados relatados abaixo.

## Resultado da homologação funcional — relatado

| Item | Resultado informado |
| --- | --- |
| Pedido recebido no painel | 33 |
| Pedido de Venda convertido | 563 |
| Cliente | DAIANA DE SOUZA FREITAS |
| Vendedora | CAMILLA PIRES DURIGUETTO |
| Itens distintos | 4 |
| Valor total | R$ 2.495,70 |
| Conferência | Recepção, conversão, valores e itens conferidos visualmente |

O fluxo Flutter → API Nuvem → Agente AMPLIATOSERVER → Firebird → Painel Delphi → Pedido de Venda foi informado como validado e aprovado. Os números, nomes e a conferência são evidências operacionais relatadas; não foram obtidos por consulta aos bancos nesta atividade documental.

## Evidências técnicas verificadas nos fontes locais

- Configuração por variáveis de ambiente, com exigência de HTTPS externo.
- Firebird por `fdb.connect` usando host, porta, database, usuário, senha e charset configurados.
- Estado SQLite com tabelas `pending` e `revisions`.
- Persistência do snapshot pendente antes de `POST` e marcação de concluído após resposta bem-sucedida.
- Lock exclusivo em `state.db.lock`.
- Claim de pedido, gravação em Firebird, commit e ACK posterior.
- Idempotência de pedido por empresa, origem, ID local e hash de conteúdo.
- Rotas da API para snapshots de vendedores/catálogo, claim e ACK.
- HTTP 409 de vendedores somente por `REVISAO_ANTIGA` ou `REVISAO_CONFLITANTE` no contrato auditado.
- Scripts PowerShell com tarefa SYSTEM desativada no registro, Boot Trigger e validação de `fbclient.dll` x86.

## Pontos pendentes

- Realizar e registrar teste de reinicialização física do AMPLIATOSERVER, verificando o disparo automático após o atraso configurado.
- Manter evidências dos logs de inicialização, diagnóstico e confirmação de snapshots em local protegido.
- Em migrações futuras, documentar o caminho efetivo de `MALHAS_AGENT_STATE_PATH` antes de mover estado SQLite.
- Se voltar a ocorrer HTTP 409, comparar revisões/hashes locais com o estado da API antes de qualquer intervenção.

## Conclusão

A homologação funcional foi aprovada conforme relato de 17/11/2026. O ambiente possui documentação de instalação e de migração, mas o teste de reboot do servidor ainda deve ser concluído para encerrar a comprovação de inicialização automática.
