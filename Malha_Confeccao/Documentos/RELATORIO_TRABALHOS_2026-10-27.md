# Relatório de trabalhos — 27/10/2026

**Projeto:** App Malhas/Confecção  
**Escopo:** encerramento documental. Nenhum código, banco, configuração, serviço ou APK foi alterado por este relatório.

## Resumo executivo

O dia reuniu a recuperação operacional de pedidos e correções localizadas na experiência do aplicativo. A auditoria de leitura confirmou o processamento único de quatro pedidos após a retomada do Agente. No Flutter, foram ajustados carrinho, Login, Novo Pedido, contadores, ordenação de Meus Pedidos e validação dos dados antes de acessar Itens.

Regra permanente preservada: o pedido é o snapshot do vendedor. Preços, quantidades, totais, pagamento, prazo, previsão, observações e gerencial não podem ser recalculados pela sincronização; UUID e idempotência impedem duplicação.

## Manhã — problemas, diagnósticos e recuperação

O histórico solicitado registra resultados intermediários de **9 aprovados/6 reprovados**, **11 aprovados/4 reprovados** e **13 aprovados/2 reprovados**. Esses totais foram relatados para a reconstrução do dia; os logs versionados disponíveis não contêm a saída completa de cada uma dessas rodadas, portanto não é possível atribuir com segurança cada falha individual a uma delas.

Foram investigados erros de sintaxe em `lib/main.dart`, incluindo a região então referida como linhas 2887–2911, com colchetes e fechamentos de widgets; esperas assíncronas, seletores de widgets, fixtures incompatíveis, simulação de persistência local, testes do carrinho e pedidos históricos sem preço. O mock de `LocalDraftStore` também precisou acompanhar `remoteOrderId`.

As evidências distinguem problemas de código/teste dos problemas de ambiente. Os registros anteriores confirmam que, depois do ajuste do mock, houve uma execução com 13 testes aprovados e nenhuma falha; o analisador não encontrou erro de compilação, embora tenha retornado avisos de lint. Em contrapartida, daemon Flutter do VS Code e processos Dart bloquearam o SDK em diferentes tentativas. O ambiente diagnosticado usava Flutter **3.38.5** e Dart **3.10.4**.

Nesta sessão, `dart format`, `flutter analyze` e `flutter test` voltaram a ficar sem saída devido a processos Dart do ambiente e foram interrompidos. Logo, os testes adicionados ao final do dia não são declarados aprovados sem uma nova execução observável.

O proprietário decidiu não preservar pedidos fictícios antigos sem os campos comerciais introduzidos posteriormente. A decisão não representa limpeza realizada nesta etapa: nenhum dado foi apagado, migrado ou alterado por este encerramento.

## Tarde — integração e recuperação auditada

Fluxo auditado: `Samsung S20 → API HTTPS → PostgreSQL → Agente Malhas → Firebird → Painel Delphi`.

Por volta de 14h20 houve indisponibilidade relacionada à compactação de `DADOS.FDB`; o Agente ficou interrompido por problema de permissão. Após o responsável iniciá-lo manualmente, a auditoria somente de leitura confirmou a recuperação. O log registra início às 15:34:13 e quatro ACKs entre 15:34:16 e 15:34:19, aproximadamente 15 segundos.

| Firebird | Cliente | Total confirmado | Resultado |
| --- | --- | ---: | --- |
| 13 | Ana Júlia Gonçalves Candian | R$ 134,90 | Conforme |
| 14 | Ana Paula Dias Marques | R$ 398,00 | Conforme |
| 15 | Luciana Aparecida Nogueira Teixeira | R$ 12.397,38 | Conforme |
| 16 | Elaine Aparecida Viana | R$ 18.066,45 | Conforme |

Para os pedidos 13–16, cada UUID local corresponde a um UUID remoto, um cabeçalho e um evento `RECEBIDO`, sem duplicidade. No PostgreSQL, todos terminaram em `RECEBIDO_PARMAGESTOR`, com uma tentativa, `CLAIMED` seguido de `ACK`; a fila da empresa 1 ficou sem pedido pendente, reservado ou rejeitado. Itens, unidades, quantidades, preços, subtotais, totais, pagamento, prazo, previsão, gerencial e observações foram conferidos contra os snapshots, sem divergência.

## Produtos, carrinho e Login

Na seleção de produtos, o fluxo direciona à quantidade e ao preço. A inclusão local ganhou confirmação central temporária e não bloqueante: **"Item adicionado ao carrinho!"**, com ícone verde e somente após atualizar o carrinho. Quantidade inválida não confirma sucesso e toques concorrentes são ignorados.

Foi diagnosticado `RenderFlex overflowed by 179 pixels on the right` nessa confirmação. A causa era visual — linha do `OverlayEntry` sem limite de largura — e foi corrigida com margem lateral, largura máxima e texto flexível, preservando o fluxo do carrinho. Não há resultado automatizado posterior observável para declarar a correção validada.

No Login, foram removidos "Confecção • ParmaGestor" e "ACESSO DEMONSTRATIVO"; logo, título e campos foram reorganizados. Usuário usa Próximo; Senha usa Concluir/Entrar e chama a mesma rotina do botão, com bloqueio contra submissões simultâneas. Autenticação, sessão e API não foram alteradas. A aprovação no Samsung S20 é registrada conforme informado pelo proprietário.

## Novo Pedido

Foram integrados rótulos às bordas de Cliente, Forma de pagamento, Prazo e Previsão; a previsão calculada ganhou fundo diferenciado; Gerencial passou a cartão Sim/Não; e Observações recebeu área multilinha. Controladores, consultas, cálculo da previsão, persistência e valores comerciais foram preservados. A aprovação visual é registrada conforme informado pelo proprietário.

Cliente, Forma de pagamento, Prazo válido e Gerencial passaram a ser obrigatórios para abrir Itens. A validação destaca o campo e apresenta a mensagem correspondente; Observações segue opcional. A mesma regra protege o salvamento, sem atribuição automática, limpeza de campos ou alteração na fórmula de previsão. Há testes adicionados para bloqueios, prazo inválido, dados válidos e retorno à aba Pedido, pendentes de execução Flutter comprovada.

## Meus Pedidos

O cartão superior classificava todos os registros como pendentes ao usar o tamanho da lista e exibia literalmente `0 enviados`. A correção usa `RECEBIDO_EMPRESA` como enviado; `RASCUNHO_LOCAL`, `PENDENTE_ENVIO`, `ENVIANDO` e `ERRO_ENVIO` permanecem pendentes. Assim, um pendente e quatro recebidos resultam em **1 pedido pendente | 4 enviados**.

Pedidos que requerem envio são exibidos antes dos recebidos pela API. Dentro de cada grupo, a ordem anterior por `updated_at DESC` é preservada de forma estável. A ordenação é somente de apresentação: não grava, oculta, duplica ou altera pedidos. Sincronização e lógica aprovada dos contadores não foram modificadas. A aprovação manual é registrada conforme relato do proprietário.

## APK e compilação

Em tentativa anterior de `flutter build apk --debug`, o Gradle não conseguiu excluir `build\\app\\intermediates\\assets\\debug\\mergeDebugAssets`. A hipótese inicial foi handle externo, mas `openfiles` não teve permissão para inspecioná-lo. O diagnóstico posterior confirmou atributos `ReadOnly` em 1.465 itens de `build`, sem handle encontrado pelo utilitário Handle.

Foram orientados parada do Gradle, `flutter clean`, `flutter pub get` e nova compilação com API HTTPS. O que está comprovado é diferente: atributos foram removidos somente de `build`, sem limpeza, e um APK debug foi gerado em 25/10/2026 às 16:42:30 em `build/app/outputs/flutter-apk/app-debug.apk`, versão 0.1.0, versionCode 1 e assinatura Android Debug. Não há comprovação nesta tarefa de novo build HTTPS, instalação no Samsung ou compatibilidade da assinatura com o APK instalado.

## Regras preservadas

- Snapshot comercial original, preços e condições; sem recálculo posterior.
- Funcionamento offline e SQLite.
- UUID, idempotência, API HTTPS, Agente Malhas, Firebird e Painel Delphi.
- Autenticação, empresa/vendedor, regras comerciais e telas aprovadas.
- Receber pedido não significa criar Pedido de Venda; esse fluxo continua sem autorização de implementação.

## Pendências e próximo ponto de retomada — 28/10/2026

1. Proprietário apresentar vídeo do aplicativo para avaliação visual e funcional.
2. Demonstrar o aplicativo à funcionária usuária e recolher necessidades reais de ajuste.
3. Depois, avaliar APK menor para WhatsApp/Samsung S20: universal versus dividido por arquitetura, arquitetura compatível, release, assinatura e preservação de dados locais em atualizações.
4. Reexecutar `flutter analyze` e `flutter test` em ambiente sem bloqueio Dart, registrando resultados observáveis.

Não gerar ou assinar APK agora, nem presumir que release substitui debug sem verificar a assinatura. A primeira ação objetiva de amanhã é receber o vídeo do proprietário; não iniciar outras tarefas antes dessa avaliação.
