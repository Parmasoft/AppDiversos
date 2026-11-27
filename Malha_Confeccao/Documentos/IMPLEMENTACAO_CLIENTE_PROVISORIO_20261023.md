# Cliente provisório e início de pedido

## Escopo entregue

- Tela **Novo Cliente**, acessível pela Home e por Meus Clientes.
- Cadastro local de PF/PJ com nome ou razão social, CPF/CNPJ, telefone com DDD e nome fantasia opcional para PJ.
- Máscaras e validações de CPF, CNPJ e telefone.
- Migração SQLite v3, que cria `local_provisional_client` sem alterar nem apagar as tabelas de pedidos existentes.
- Clientes provisórios isolados por empresa e vendedor, com ID local estável, situação `PENDENTE_ENVIO` e espaço para futuro ID oficial.
- Bloqueio de CPF/CNPJ duplicado para o mesmo par empresa/vendedor.
- Exibição diferenciada em Meus Clientes como “Novo no aparelho - pendente de envio”. A consulta de clientes oficiais continua sendo a API existente.
- Após salvar, o vendedor pode voltar a Meus Clientes ou iniciar Novo Pedido já com o cliente local selecionado.

## Compatibilidade

Pedidos preservam `client_id` textual. Para um cliente provisório, o pedido armazena apenas o ID local com o prefixo `local-client:`; ele não é apresentado nem usado como ID oficial do Firebird. Não houve alteração em Firebird, API, Delphi, autenticação, catálogo, sincronização ou envio.

## Validação executada

- `flutter analyze`: sem erros; há 4 avisos e 14 informações de lint já existentes fora do escopo funcional.
- `flutter test`: 13 testes aprovados, incluindo validação de CPF e CNPJ.
- APK debug gerado em `build/app/outputs/flutter-apk/app-debug.apk`.
- Cobertura incluída: migração e preservação de pedidos v1/v2, recuperação local após reabrir, isolamento por vendedor, duplicidade local e manutenção das telas homologadas.

## Homologação Samsung sugerida

1. Criar uma PF e uma PJ, verificando máscaras e documentos inválidos.
2. Tentar repetir o CPF/CNPJ para o mesmo vendedor e confirmar o bloqueio.
3. Criar pedido pelo botão “Novo Pedido” após salvar o cliente e confirmar que ele vem selecionado.
4. Salvar o pedido, fechar e abrir o aplicativo; confirmar cliente e pedido locais.
5. Entrar com outro vendedor e confirmar que não aparecem os clientes provisórios do primeiro.

## Limitação intencional

O cadastro e o pedido permanecem somente no aparelho. Não há envio de cliente, pedido, sincronização nem criação de ID no sistema da empresa.
