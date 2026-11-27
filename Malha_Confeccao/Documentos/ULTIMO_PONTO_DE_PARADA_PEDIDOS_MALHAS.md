# Último ponto de parada — Pedidos de Malhas

## Homologação controlada registrada — 12/11/2026

O pedido nº 29, criado no Samsung S20 e recebido pela API, foi conferido no
Firebird de homologação Tekno Prime e no painel Delphi. A migration
`20261110_0001_cliente_provisorio_dados_ampliados.sql` foi aplicada somente
nesse banco após confirmação de caminho, teste de integridade do backup RAR e
verificação de ausência prévia das dez colunas.

O pedido está em situação `RECEBIDO`, com um único item e um único evento de
recebimento. Os snapshots conferidos foram: MALHA BRANCA 60 CM, 400 UN, R$
19,90 por unidade e R$ 7.960,00 total; prazo de 30 dias, entrega em
12/12/2026, gerencial e observação `T3STE DE OBSERVAÇÃO JORGINHO`. O cliente
provisório vinculado possui os dez campos ampliados preenchidos. A chave
empresa/origem/ID-local ocorre uma única vez e o hash do pedido está gravado.

O log registra início manual do Agente às 10:50:40 e confirmação do ciclo às
10:50:43, após a gravação Firebird. Isso comprova o processamento local; o
ACK remoto não foi consultado diretamente e o log não expõe o UUID local, logo
a correspondência com o pedido nº 29 é temporal, não uma prova remota direta.
O payload original da API também não foi relido nesta etapa.

**Próxima ação mínima:** projetar, sem implementar ainda, a consulta dos dados
ampliados no painel Delphi e o fluxo auditado de transformação em cliente fixo.
Natália deve validar o cadastro e realizar a análise Serasa antes de qualquer
conversão. Não criar botão, não alterar `TB_CLIENTE`, não modificar pedidos,
não recalcular snapshots e não iniciar consulta financeira no aplicativo.

Data: 10/11/2026

## Retomada controlada — correção localizada no teste

`test/widget_test.dart` foi ajustado somente para declarar `completeRequiredOrderDetails` antes de `pumpOrder`; seu conteúdo e as chamadas foram preservados. O erro de compilação reportado na linha 32 deixa de decorrer de referência à função antes da declaração.

Foram iniciados `flutter analyze`, `flutter test` e `flutter test test/local_draft_store_test.dart`. Nesta máquina, todos permaneceram em processamento sem saída por mais de um minuto (a análise passou de três minutos) e foram interrompidos somente nos processos criados para a validação. Assim, não há resultado novo para classificar erros/avisos nem confirmação atual dos três testes SQLite. O último resultado documentado antes desta correção continua sendo três testes SQLite aprovados. Não avançar para API, PostgreSQL, Agente, Firebird, Delphi, migrations ou APK sem autorização.

---

Data: 10/11/2026

## Validação Flutter — 10/11/2026

O Flutter foi liberado de processos órfãos e os comandos foram executados com limite controlado. A migração SQLite v6→v7 foi validada em teste automatizado, com todos os testes de armazenamento local aprovados. O conjunto completo permanece bloqueado somente pelo erro preexistente em `test/widget_test.dart`, em que `completeRequiredOrderDetails` é referenciada antes da declaração. Não corrigir esse teste fora de uma etapa específica; não avançar para Firebird ou Delphi.

## Estado ao encerrar

Implementada a ampliação opcional do cliente provisório no Flutter, SQLite, contratos de API e Agente. Antes da homologação ponta a ponta, aplicar manualmente o script Firebird versionado em ambiente de desenvolvimento/homologação e confirmar a consulta dos campos pelo painel Delphi. Não executar o script em produção sem autorização. A futura transformação em cliente fixo continua sem implementação.

---

Data: 21/10/2026

## Estado ao encerrar

Nenhuma implementação foi realizada neste encerramento; somente documentação foi atualizada.

O próximo passo obrigatório é exclusivamente diagnosticar o processo que atende a porta `5056` e homologar o login real no Samsung.

Sequência de retomada:

1. Encerrar instâncias antigas da API.
2. Verificar se há processo remanescente na porta `5056`.
3. Iniciar novamente `api\iniciar_api_malhas.bat` atualizado.
4. Acessar `/health` pelo navegador do Samsung.
5. Confirmar que a janela correta mostra `GET /health -> HTTP 200`.
6. Só então repetir o login no Samsung.
7. Confirmar a presença de `POST /api/v1/sessoes` no log.
8. Registrar o código HTTP e diagnosticar a causa concreta de qualquer falha.

Não alterar senha, autenticação, banco ou Flutter antes desses passos. Não iniciar consultas de clientes/produtos, pedidos, sincronização offline ou acesso externo.
