# Último ponto de parada — 22/10/2026

Foi concluída a auditoria somente leitura do login `EU` e da pesquisa de clientes. A API está configurada para `E:\Dados Clientes\Tekno Prime\DADOS.FDB`; `EU` autentica como empresa 1, vendedor 12. A pesquisa `MARIA` retorna zero porque a API exige clientes ativos vinculados ao vendedor 12, enquanto 110 clientes ativos correspondem ao termo na empresa 1 e nenhum está vinculado a esse vendedor.

Nenhuma alteração de regra, banco, API, Flutter, Home, login, produtos ou formas de pagamento foi implementada neste encerramento. Nenhuma compilação, reinício de serviço ou alteração de configuração foi executada.

## Próxima retomada obrigatória

1. Definir com a área comercial se o tablet `EU` deve ver somente sua carteira, também clientes sem vendedor, ou todos os clientes ativos da empresa.
2. Somente após autorização, implementar a menor alteração correspondente e homologar no aparelho.
3. Validar os quatro produtos touch e as formas de pagamento da empresa 1 antes de qualquer implementação de gravação de pedido.

Não iniciar persistência offline, sincronização, exposição externa ou gravação real de pedidos antes da definição comercial e da homologação manual.

Documento completo: [ENCERRAMENTO_20261022.md](ENCERRAMENTO_20261022.md).

## Histórico preservado

Data: 21/10/2026

O projeto parou após a atualização visual aprovada da Tela Inicial do Vendedor. As três telas navegáveis continuam sendo Login, Tela Inicial do Vendedor e Novo Pedido.

Não iniciar autenticação real, API, banco, consultas de financeiro/boletos, sincronização, painel interno ou integração com Firebird sem nova autorização e especificação.

Antes da próxima etapa, aguardar a avaliação da Tela Inicial atualizada no celular e homologar a arquitetura externa proposta em `STATUS_APP_MALHAS.md`.

## Validação local

- `flutter analyze`: concluído sem problemas.
- `flutter test`: concluído com o teste de exibição do Login demonstrativo aprovado.
- APK debug: compilado em `build/app/outputs/flutter-apk/app-debug.apk`.

O lançador em lote do SDK Flutter deixou locks de cache presos após algumas execuções. Os dois locks vazios foram liberados com autorização para que a validação e a compilação fossem concluídas. Nenhum arquivo dos projetos de referência foi alterado.
