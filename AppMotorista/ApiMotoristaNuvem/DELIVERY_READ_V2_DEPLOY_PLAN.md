# Delivery read V2 — plano de publicacao (nao executar)

Data: 23/11/2026. Nenhuma publicacao, reinicio, reenvio do S20 ou alteracao em
producao foi realizada nesta etapa.

Atualizacao de deploy: com o hash corrigido, o patch foi aplicado em 23/11/2026.
Backup: `/root/backup-api-motorista-v2-20261123T164456Z`. O `dry-run`, a
compilacao/importacao e o restart exclusivo de `api-motorista-nuvem.service`
passaram; health local/publico retornou 200 e a validacao pura V2 aceitou
`occurrence_guid`. Nenhum POST de leitura ou retorno Firebird foi executado.

Atualizacao de correcao pontual: apos a leitura real revelar comparacao sensivel
a caixa de `occurrence_guid`, foi aplicado somente o patch
`DELIVERY_READ_V2_OCCURRENCE_GUID_CANONICAL.patch` (SHA-256
`18a04bd3316b5245cee9d4d879138856b1e0b5e43c2d35ebb5df823659f907c9`).
Backup: `/root/backup-api-motorista-occurrence-guid-20261123T170419Z`; hash final
de `service.py`: `42eb5a3262c922bb264d3b9b2e53740e4951ac42c0c2c835e9cf5c72bc72eb47`.
Health e validacao pura passaram; nova leitura S20 ainda nao foi executada.

Atualizacao de pre-deploy: a janela autorizada foi interrompida antes de qualquer
alteracao porque o hash literal autorizado para `service.py` diverge do hash real
por um caractere. Consultar `AppMotorista/Documentacao/ULTIMO_PONTO.md` antes de
qualquer nova tentativa.

## Evidencia de producao, somente leitura

- URL publica: `https://motorista.parmatech.com.br/api/v1/health` respondeu
  HTTP 200 com `{"contrato":1,"servico":"api-motorista-nuvem","status":"ok"}`.
- Servidor: `parmasoft-cotacao` (DigitalOcean); unidade ativa:
  `api-motorista-nuvem.service`.
- Diretorio: `/opt/api-motorista-nuvem`; usuario: `api-motorista`; Gunicorn:
  `127.0.0.1:8091`; arquivo de ambiente: `/etc/api-motorista-nuvem.env`.
- PostgreSQL/Alembic efetivo: `20260925_0004 (head)`.
- O endpoint e o contrato V1 ainda estao implantados: a whitelist contem apenas
  `operacao_guid`, `codigo`, `data_hora_aparelho` e `fuso_minutos`.

## Artefatos e revisao

- Homologacao completa (inclui testes):
  `DELIVERY_READ_V2_POSTGRESQL_HOMOLOGATION.patch`, SHA-256
  `6d187641788bec440adbfd41ab7ce336562a6f7f63031779f27b156c4a5dd434`.
- Recorte de producao gerado do commit-base `9f699964`:
  `DELIVERY_READ_V2_PRODUCTION.patch`, SHA-256
  `8aecd284ec034e4f582b2796769b4f19cf4f5bb1917a148887e7a7c0dda367a7`.
  Ele contem somente `app/contracts.py` e `app/service.py`.

O recorte de producao **nao deve ser aplicado ainda**: a implantacao atual ja
possui o insert do ledger com os campos da migration `20260925_0004`, enquanto
o patch foi produzido contra o commit-base anterior. A aplicacao literal pode
conflitar nesse hunk. O rebase final precisa preservar o insert existente de
`return_contract_version`, `return_payload_hash`, `return_state` e
`return_attempt_count`; esses campos sao apenas ledger. O V2 nao deve chamar
claim/ack, agente, Firebird ou `SP_APL_ENTREGA_NUVEM`.

## Dependência resolvida no rebase controlado

O `tables.py` implantado foi posteriormente autorizado para leitura e tem SHA-256
`e4549c4bfce8d927f892705a92c043cbe1b6a2f615f35c555364ef86d8065c7d`, identico
ao do workspace. Ele define `mobile_driver_company_access` e o ledger 0004.
Com essa copia apenas no ambiente temporario, o rebase passou 10 testes PostgreSQL
e deixou `motorista_nuvem_test` vazio em `20260925_0004`.

O patch definitivo para revisao e `DELIVERY_READ_V2_PRODUCTION_REBASED.patch`,
SHA-256 `3204d8f597d0561cde2cb2affaf58e001a2de232d808bdfcfb798ad19555fa5f`.
Ele contem apenas `app/contracts.py` e `app/service.py` e passou `patch --dry-run`
contra as copias exatas de producao. Nenhum deploy ocorreu.

O diff V2 em si nao inclui `routes.py`, configuracao, login, migrations,
endpoints claim/ack ou codigo Firebird. A unica mudanca funcional pretendida e:

1. aceitar os dois conjuntos exatos de campos V1 e V2 e validar UUID de
   `occurrence_guid`;
2. manter replay por `tenant_id + operation_guid`, com `occurrence_guid` no
   hash V2;
3. exigir a ocorrencia em novas operacoes, validando-a contra
   viagem/parada/pedido/codigo antes de responder aceita;
4. manter a gravacao atual do ledger, sem executar retorno.

## Condicao para gerar o patch aplicavel

Antes do deploy, obter autorizacao especifica para copiar, somente para pasta
temporaria local protegida, os dois arquivos atualmente implantados
`/opt/api-motorista-nuvem/app/contracts.py` e `app/service.py`. Com eles, gerar
um diff de dois arquivos contra os checksums registrados em producao e validar
`git apply --check` sobre essa revisao. Sem isso, nao ha como provar que um
patch de commit-base sera aplicado sem conflitar ou substituir mudancas locais
de producao.

## Comandos para a janela de publicacao — nao executar agora

Executar como `root` no servidor e interromper ao primeiro erro. Substituir
`<PATCH_REBASADO_SHA256>` somente depois do rebase acima.

```bash
set -euo pipefail
STAMP=$(date -u +%Y%m%dT%H%M%SZ)
APP=/opt/api-motorista-nuvem
UNIT=api-motorista-nuvem.service
BACKUP=/root/backup-api-motorista-v2-$STAMP
install -d -m 700 "$BACKUP"
cp -a "$APP/app/contracts.py" "$APP/app/service.py" "$BACKUP/"
sha256sum "$BACKUP/contracts.py" "$BACKUP/service.py" | tee "$BACKUP/SHA256SUMS"
systemctl is-active --quiet "$UNIT"
curl --fail --silent --show-error http://127.0.0.1:8091/api/v1/health
git apply --check /root/DELIVERY_READ_V2_REBASED.patch
sha256sum /root/DELIVERY_READ_V2_REBASED.patch
# conferir manualmente o SHA-256 contra <PATCH_REBASADO_SHA256>
git apply /root/DELIVERY_READ_V2_REBASED.patch
systemctl restart "$UNIT"
systemctl is-active --quiet "$UNIT"
curl --fail --silent --show-error http://127.0.0.1:8091/api/v1/health
curl --fail --silent --show-error https://motorista.parmatech.com.br/api/v1/health
```

Nao executar Alembic, `pip install`, migration, claim/ack, rotinas do agente ou
qualquer comando Firebird: o schema efetivo ja e `20260925_0004` e a correcao
V2 nao requer migration.

## Rollback — nao executar agora

Se health, logs ou teste funcional falharem, restaurar somente os dois arquivos
do backup da janela e reiniciar a unidade:

```bash
set -euo pipefail
APP=/opt/api-motorista-nuvem
UNIT=api-motorista-nuvem.service
BACKUP=<diretorio-backup-da-janela>
sha256sum -c "$BACKUP/SHA256SUMS"
install -m 640 "$BACKUP/contracts.py" "$APP/app/contracts.py"
install -m 640 "$BACKUP/service.py" "$APP/app/service.py"
chown api-motorista:api-motorista "$APP/app/contracts.py" "$APP/app/service.py"
systemctl restart "$UNIT"
systemctl is-active --quiet "$UNIT"
curl --fail --silent --show-error http://127.0.0.1:8091/api/v1/health
```

## Teste posterior controlado

Com retorno Firebird mantido desabilitado, no S20 abrir a carga 776, parada e
pedido 22014 e ler a etiqueta 8635 uma vez. Confirmar HTTP/resposta aceita,
`ocorrencia_guid` igual ao enviado e uma unica linha de ledger. Repetir somente
o envio da mesma operacao para confirmar `replay=true`; nunca gerar outro
`operacao_guid` para essa leitura. Em caso de falha, parar e usar o rollback.

Para recuperar a tentativa que o S20 teve rejeitada por whitelist V1, a outbox
deve reenviar o mesmo registro persistido com o mesmo `operacao_guid` e
`occurrence_guid` apos o V2 estar ativo. Como o servidor V1 rejeitou o campo
antes da criacao do ledger, nao existe entrega a duplicar. Isto deve ser apenas
verificado no aparelho na janela autorizada; nao reenviar nem alterar o S20
antes disso.

Confirmacao em fonte Flutter, sem alteracao: `delivery_local_store.dart` grava
ambos os GUIDs na outbox; `trips_repository.dart` le o payload persistido e os
repassa sem gerar novos IDs; `outbox_sync_controller.dart` recupera estado
`sending` interrompido e agenda o replay. Portanto a recuperacao segura e
reutilizar a entrada existente, nunca escanear novamente nem recriar a operacao.
