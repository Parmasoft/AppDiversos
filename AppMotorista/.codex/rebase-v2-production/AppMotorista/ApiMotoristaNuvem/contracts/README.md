# Contratos JSON

Os contratos são versionados na URL (`/api/v1`) e no corpo (`contrato_versao: 1`).
Mudança incompatível exige uma nova pasta e uma nova versão de endpoint; campos opcionais
compatíveis podem ser adicionados preservando a versão.

`snapshot.schema.json` descreve a projeção operacional publicada pelo agente local.
`tracking-event.schema.json` descreve eventos que somente poderão nascer de confirmação
autoritativa do Firebird. Neste bloco não existe endpoint público nem emissor desses eventos.

A chave lógica do evento é composta por tenant, Manifesto, Parada, Pedido, tipo e versão
do evento. `PEDIDO_ENTREGUE` também exige o `OPERACAO_GUID` confirmado pela
`SP_REG_ENTREGA_MANIFESTO`; replay não cria outro evento nem outra notificação.

`SAIU_PARA_ENTREGA` está apenas contratado. A auditoria focal não encontrou uma transição
inequívoca no ParmaGestor, e `CARGM_STATUS = 'L'` não é usado como disparador.

