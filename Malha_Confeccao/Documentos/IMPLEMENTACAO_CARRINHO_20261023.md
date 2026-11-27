# Implementação do carrinho local — 23/10/2026

## Entrega

O carrinho foi implementado somente em memória no App de Malhas. Ele compartilha a lista de linhas do rascunho do pedido: não há cópia independente, persistência, preço, total monetário, envio à API, gravação Firebird ou sincronização.

## Fluxo implementado

1. Na aba **Itens**, o vendedor escolhe a malha, informa a quantidade e toca em **Adicionar ao carrinho**.
2. Se a mesma malha for incluída outra vez, a quantidade é acumulada na linha existente; não é criada uma duplicação acidental.
3. O ícone do carrinho no cabeçalho mostra a quantidade de linhas e atualiza imediatamente.
4. A tela **Carrinho** permite alterar uma quantidade positiva ou excluir a linha. Ao excluir a última linha, apresenta estado vazio.
5. Ao voltar, cliente, forma de pagamento, observações e itens do rascunho continuam preservados na mesma instância de pedido.

Não há botão Salvar/Enviar no carrinho, pois persistência e sincronização não fazem parte desta etapa.

## Arquivos alterados

- `lib/main.dart`: contador no cabeçalho, tela local do carrinho, edição/exclusão e simplificação da aba Itens.
- `test/widget_test.dart`: testes de estado vazio, inclusão, acúmulo, edição, exclusão, contador e preservação de observações.

## Quantidade e unidade comercial

O carrinho valida quantidade estritamente positiva e preserva a unidade recebida no catálogo. A regra atual aceita até três casas decimais, pois `quantityPrecision` ainda assume esse padrão no aplicativo.

É necessária uma definição comercial/API por produto ou unidade informando se a venda é inteira ou fracionada e qual precisão é permitida. Até essa definição, nenhuma unidade é forçada a ser inteira e não se inferem regras comerciais novas.

## Validação

- `flutter test`: aprovado, 2 testes.
- `flutter analyze`: sem erros; 5 apontamentos preexistentes em `lib/main.dart` (elementos sem uso e um uso de API deprecada).
- `flutter build apk --debug`: concluído. APK: `build/app/outputs/flutter-apk/app-debug.apk`.

O teste antigo foi substituído porque verificava o texto obsoleto “Entrar no modo demonstrativo”, que não existe na tela atual; a falha anterior não era causada pelo carrinho.

## Teste recomendado no Samsung

1. Abra **Novo Pedido** e a aba **Itens**.
2. Adicione uma malha, depois repita a inclusão dela para confirmar o acúmulo em uma só linha.
3. Abra o ícone de carrinho, altere a quantidade e exclua a linha.
4. Retorne ao pedido e confirme que cliente, pagamento e observações não foram perdidos.
