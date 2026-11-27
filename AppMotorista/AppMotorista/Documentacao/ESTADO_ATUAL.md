# Estado atual — App Motorista

Atualizado em 23/11/2026. Etiquetas: **CONFIRMADO** = evidência observada;
**NÃO TESTADO** = existe em fonte, sem prova no alvo; **HIPÓTESE** = requer prova.

## Matriz de estado

| Componente | Estado | Evidência / ambiente |
| --- | --- | --- |
| Flutter / S20 | **CONFIRMADO parcialmente** | Carga 776, 3 paradas, pedido 22014 e etiqueta 8635 aparecem no S20. Fonte atual preserva `operacao_guid` e `occurrence_guid` na outbox (`lib/viagens/local/delivery_local_store.dart`, `lib/viagens/repositories/trips_repository.dart`, `lib/sync/services/outbox_sync_controller.dart`). Leitura V2 não foi aceita pela Nuvem V1. |
| API local `ApiMotorista` | **LEGADA/SUBSTITUÍDA** | Registros históricos de agosto/2026 comprovam leitura por ADB/`localhost:5055`, contrato V1 e fluxo Firebird local. Não é o destino do S20 atual. |
| API Nuvem implantada | **IMPLEMENTADA E TESTADA PARCIALMENTE** | Deploy V2 em 23/11/2026: serviço reiniciado e ativo; health local/público HTTP 200. A função pura `validate_delivery_read` aceitou payload V2 com `occurrence_guid`; o worker novo carregou os arquivos implantados. Não foi feito POST de leitura, portanto aceitação end-to-end no S20 permanece pendente. |
| API Nuvem no workspace | **IMPLEMENTADA, TESTADA, NÃO IMPLANTADA** | O rebase contra as cópias exatas de produção aprovou 10 testes em PG18/migration 0004. O patch de dois arquivos passou `patch --dry-run`; está pronto apenas para revisão/autorização de deploy. |
| Agente GramDecor | **CONFIRMADO parcialmente** | Publicação controlada da carga 776 foi confirmada anteriormente. Allowlist e retorno desabilitado existem em `.env.example`/`agent/config.py`; não há serviço contínuo autorizado. |
| Firebird homologação | **CONFIRMADO parcialmente** | Estrutura aplicada e botões Viagem/Acompanhamento funcionam. Retorno, `SP_APL_ENTREGA_NUVEM` e DML de entrega estão **NÃO TESTADOS / DESABILITADOS**. |

## Causa confirmada

O fluxo antigo funcionava porque a API local V1 recebia código e escolhia a
ocorrência. O S20 atual usa HTTPS na Nuvem e envia V2 com `occurrence_guid`.
A Nuvem implantada admite só os quatro campos V1 e rejeita a operação antes de
criar ledger ou confirmar entrega; portanto não há duplicação da tentativa rejeitada.

## Diagnóstico pontual da etiqueta 22014/8635 — 23/11/2026

- **CONFIRMADO:** não há parser de posições para a etiqueta no Flutter. Câmera e
  leitor físico encaminham o texto bruto, apenas com `trim().toUpperCase()`;
  `C02201400086350800000` é tratado como código opaco, não como pedido/produto/
  quantidade extraídos por substring.
- **CONFIRMADO:** a projeção da carga 776 contém exatamente código
  `C02201400086350800000`, parada 1997, pedido 22014, produto 8635, quantidade
  80, status `P` e ocorrência `74DDEA91-1913-4877-A53B-AAD5DC74281F`.
- **CONFIRMADO:** o ledger registrou duas operações V2 rejeitadas, ambas para a
  mesma parada/pedido/código e GUID em minúsculas
  `74ddea91-1913-4877-a53b-aad5dc74281f`: operações
  `2c7eb37e-07e2-44e6-945b-f15ea3481da3` e
  `5e0cfe68-679a-4a45-91ff-4236ab3a53eb`, com
  `OCORRENCIA_NAO_ENCONTRADA`.
- **CAUSA RAIZ CONFIRMADA:** `validate_delivery_read` transforma UUID em
  `str(UUID(...))`, portanto minúsculo; `register_delivery_read` compara esse
  valor com `value.get("guid") == occurrence_guid`, sensível à caixa. A projeção
  publicada preserva o GUID em maiúsculas. A ocorrência correta deixa de ser
  localizada antes da validação de parada/pedido/código.
- **CORREÇÃO IMPLANTADA, AINDA NÃO TESTADA NO S20:** `service.py` agora
  canoniza ambos os UUIDs por `UUID` antes da igualdade. O patch de um arquivo,
  testes PostgreSQL e validação pura pós-restart passaram. Não houve nova leitura
  real, portanto a confirmação end-to-end permanece pendente.

## Auditoria final do ledger V2 — 23/11/2026

- **CONFIRMADO, somente leitura:** o manifesto 776 tem quatro ocorrências: uma
  do pedido 22014, uma do 23318 e duas do 23327. O ledger registra quatro
  aceitações `LEITURA_CONFIRMADA`, uma por GUID de ocorrência, e duas recusas
  históricas `OCORRENCIA_NAO_ENCONTRADA` do pedido 22014 anteriores à correção.
- **CONFIRMADO:** não há GUID com mais de uma aceitação. As operações aceitas
  são o registro autoritativo atual das leituras V2; elas ainda não retornaram ao
  Firebird.
- **PENDÊNCIA REAL:** `manifest_projection.detail_json` permanece com ocorrências,
  pedidos e paradas em `P` e sem status de manifesto. O V2 atual grava ledger,
  mas não persiste a mutação da projeção. Não encerrar viagem nem inferir retorno
  Firebird a partir desta auditoria.

## Diagnóstico integrado — consistência Nuvem e offline — 23/11/2026

- **CONFIRMADO:** `register_delivery_read` executa sob advisory lock, calcula
  resposta `ACEITA` alterando somente o dicionário `detail` em memória e insere
  `delivery_read_operation` na mesma transação. O comentário e o teste PostgreSQL
  `test_delivery_read_refresh_replay_conflict_rollback_and_projections_read_only`
  comprovam que a projeção permanece somente leitura.
- **Status comprovados:** `P` e `E` são os status técnicos recebidos no snapshot;
  `_tracking_status` deriva `PENDENTE` (todos P), `EM_ANDAMENTO` (mistura) ou
  `ENTREGUE` (todos E). Pedidos/paradas são calculados E somente quando todas as
  respectivas ocorrências estão E. O manifesto técnico não é encerrado pelo V2.
- **OFFLINE IMPLEMENTADO E TESTADO AUTOMATICAMENTE:** viagem previamente aberta
  é salva em SQLite; leitura local cria payload V2/outbox persistente com GUIDs;
  falha de rede deixa `pending`/`retry`; reabertura recupera `sending` como
  `pending`; replay conserva os GUIDs. Há testes de persistência, queda de resposta,
  ordem, recusa e múltiplas ocorrências.
- **OFFLINE NÃO HOMOLOGADO NO S20:** não há evidência de teste real em modo avião,
  reinício físico, retorno de rede ou sincronização posterior no aparelho. Não
  declarar funcionamento integral antes desse ensaio.
- **DIVERGÊNCIA DE FONTE:** o `service.py` do workspace ainda mostra a comparação
  V2 anterior; a DigitalOcean contém a correção canônica implantada. Não alterar
  nem usar o workspace como prova da revisão implantada até reconciliação futura.
- **NÃO COMPROVADO:** o estado físico da outbox do S20, pois nenhum aparelho ADB
  estava conectado. Pela fonte Flutter, resposta `RECUSADA` marca a operação como
  `rejected` e repõe a ocorrência local em `P`; reenviar o mesmo `operation_guid`
  apenas reproduzirá a rejeição já gravada no ledger.

## Divergências relevantes

1. O workspace é sujo e possui mudanças não versionadas de login, retorno,
   migrations `20260924_0003`/`20260925_0004` e V2; isso não prova implantação.
2. Produção está em `20260925_0004` e preserva ledger com `return_payload_hash`.
   V2 não pode chamar claim/ack, agente ou Firebird, mas deve manter esse insert.
3. `service.py` implantado importa `mobile_driver_company_access`; o `tables.py`
   implantado foi inspecionado e é byte a byte igual ao do workspace (SHA-256
   `e4549c4bfce8d927f892705a92c043cbe1b6a2f615f35c555364ef86d8065c7d`).
   A dependência ficou reproduzida somente no ambiente temporário.
4. `DELIVERY_READ_V2_PRODUCTION.patch` deriva do commit-base e não deve ser aplicado;
   o patch rebased foi implantado. Os hashes pós-deploy são `contracts.py`
   `a3e83e65fa391edf91b65606f6a0338eac4dc7ecc351335c31c1d6adbafaa5c9` e
   `service.py` `9081ec67a23241ea3dfe9e070e0aff9d789d65b70968ce025079233b53fe004f`.

## Limites invariáveis

- App Motorista e App Malhas são independentes; App Malhas está fora do escopo.
- Não habilitar retorno Firebird, claim/ack, agente contínuo ou reenvio S20.
- Não declarar implantação sem verificação efetiva posterior.
