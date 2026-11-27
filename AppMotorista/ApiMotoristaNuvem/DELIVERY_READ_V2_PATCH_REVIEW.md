# Patch minimo para revisao — delivery_read V2

Status: preparado e testado localmente; **nao implantado**.

Base: commit `9f699964`. Esta proposta nao deve transportar o diretorio de trabalho
atual, que tambem contem mudancas de login e retorno fora de escopo.

## Arquivos de produto

1. `app/contracts.py`
   - trocar o whitelist unico V1 por dois conjuntos exatos: V1 e V2;
   - aceitar V2 somente com `occurrence_guid` UUID valido;
   - normalizar o GUID para a carga util entregue ao servico.
2. `app/service.py`
   - manter a consulta de ledger por `(tenant_id, operation_guid)` antes de
     qualquer validacao de negocio, preservando replay identico e conflito;
   - localizar a ocorrencia pelo GUID no manifesto;
   - validar que ela pertence a parada/pedido da URL e confere com o codigo;
   - para operacao nova V1, gravar resposta idempotente `RECUSADA` /
     `OCORRENCIA_GUID_OBRIGATORIA`; jamais confirmar entrega;
   - nao adicionar campos de retorno, nem alterar `routes.py`.

## Diff funcional revisavel

```text
contracts.py
- _DELIVERY_READ_FIELDS = {operacao_guid, codigo, data_hora_aparelho, fuso_minutos}
+ _DELIVERY_READ_V1_FIELDS = {operacao_guid, codigo, data_hora_aparelho, fuso_minutos}
+ _DELIVERY_READ_V2_FIELDS = V1 + {occurrence_guid}
+ validar UUID occurrence_guid quando presente e inclui-lo no payload normalizado

service.py, apos o lookup existente de operation_guid
- selecionar primeira ocorrencia pendente por pedido + codigo
+ selecionar a ocorrencia exata por occurrence_guid
+ recusada se GUID ausente, desconhecido, fora da parada/pedido, codigo divergente ou ja entregue
+ aceita somente ocorrencia pendente exata
```

`_read_hash` ja recebe o payload normalizado inteiro; assim, no V2 o GUID passa
a integrar o hash sem mudar a chave unica `(tenant_id, operation_guid)`.

## Esquema e migrations

Nenhuma migration e necessaria. O schema ja armazena `request_json`,
`response_json` e `request_hash` no ledger `delivery_read_operation`. Nao incluir
as migrations locais de login ou retorno nesta publicacao.

## Testes obrigatorios antes do deploy

- V2 aceita a ocorrencia exata e devolve seu GUID;
- mesmo payload V2 e replay, sem novo ledger;
- mesmo `operation_guid` com GUID/codigo diferente gera conflito;
- GUID invalido gera 400;
- GUID de outra viagem/parada/pedido ou codigo divergente e recusado;
- nova operacao V1 e recusada sem entrega; replay V1 previamente gravado e
  devolvido identicamente;
- teste de integracao PostgreSQL descartavel para unicidade e concorrencia.
