# Correção de confirmação e retorno à Home — 23/10/2026

## Alteração concluída

Após a transação SQLite ser confirmada, o aplicativo apresenta um diálogo
central não interativo por aproximadamente dois segundos:

- `Rascunho salvo com sucesso!`
- `Pedido armazenado neste aparelho.`

O diálogo usa o padrão visual do aplicativo (amarelo claro, grafite e ícone de
confirmação). Depois do prazo, ele é fechado e a navegação retorna pela pilha
existente até a rota inicial, sem criar uma Home duplicada. Portanto, a
confirmação não permanece em Meus Pedidos, na Home ou em qualquer outra tela.

## Falha de persistência

Quando o SQLite falha, não há confirmação de sucesso nem retorno automático.
O carrinho continua aberto para nova tentativa e apresenta uma mensagem de
erro temporária: `Falha ao salvar o rascunho local. Tente novamente.`

O bloqueio já existente durante o salvamento permanece ativo, evitando toques
repetidos e navegações concorrentes.

## Preservado

Não foram alterados o esquema SQLite v2, a migração, rascunhos múltiplos,
isolamento por empresa/vendedor, carrinho, API, USB, Firebird, envio ou
sincronização.

## Validação

- `flutter test`: 8 testes aprovados.
- Cobertura adicional para aviso central temporário, remoção automática,
  retorno à rota inicial e falha de persistência sem navegação.
- `flutter analyze`: sem erros; 5 avisos preexistentes fora do escopo.
- APK debug gerado em `build/app/outputs/flutter-apk/app-debug.apk`.
