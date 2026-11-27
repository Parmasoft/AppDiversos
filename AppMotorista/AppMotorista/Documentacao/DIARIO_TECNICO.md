# Diário técnico — App Motorista

## 2026-11-23 — deploy controlado da projeção derivada V2

- Backup remoto: `/root/backup-api-motorista-projection-20261123T183100Z`; inclui código, ambiente e dump PostgreSQL pré-0005.
- Migration `20261123_0005` aplicada; hashes finais: `service.py` `1fa4d1f28bbe7968b1e39722a29bc1012b454a31518dc7fb128fb52f59e26c6b`, `tables.py` `b6e2b2894c476426d9646e0365f7d5721fb93293dd3f71dc4bea3fddb3bbd906`.
- Serviço reiniciado exclusivamente; health local e público HTTP 200.
- Reconstrução limitada ao manifesto 776: quatro confirmações derivadas, zero duplicidades; duas recusas não incluídas. Snapshot bruto inalterado em `P`; estado efetivo de pedidos/paradas é `E`.
- Sem retorno Firebird, claim/ack, reenvio S20 ou alteração de Firebird, agente, Flutter ou APK.

Regra operacional: registrar imediatamente cada validação, bloqueio, decisão ou
mudança de direção, com ambiente, evidência, arquivos e se houve escrita. Não
reconstruir o histórico por memória ao fim do dia.

## 2026-11-23 — consolidação documental

- **Confirmado, leitura:** health da Nuvem HTTP 200/contrato 1; serviço ativo;
  Alembic produção `20260925_0004`.
- **Confirmado:** S20 envia `occurrence_guid`; whitelist V1 o rejeita antes do ledger.
- **Confirmado anteriormente:** 10 testes V2 aprovados no WSL/`motorista_nuvem_test`.
  Backup: `/var/backups/app-motorista-homologacao/motorista_nuvem_test_pre_v2_20261123T131727Z.dump`, SHA-256 `300230f9d15c2fec794812e31dc542b7a62a0c02e0b32936f8cb0a331d3f346a`.
- **Bloqueio:** rebase de dois arquivos falhou na importação por
  `mobile_driver_company_access` ausente no `tables.py` do commit-base. Não foram
  copiados outros arquivos de produção.
- **Sem escrita externa:** sem deploy, restart, migration, Firebird/DigitalOcean/S20.

## 2026-11-23 — dependência resolvida e rebase validado

- **Confirmado, leitura autorizada:** `/opt/api-motorista-nuvem/app/tables.py`
  tem SHA-256 `e4549c4bfce8d927f892705a92c043cbe1b6a2f615f35c555364ef86d8065c7d`
  e é idêntico ao `tables.py` atual do workspace. Ele define
  `mobile_driver_company_access` e os campos de ledger `20260925_0004`.
- **Confirmado, local:** usando somente cópias temporárias de `contracts.py`,
  `service.py` e `tables.py` implantados, a suíte PostgreSQL V2 aprovou 10 testes
  em `motorista_nuvem_test`/PG18/migration `20260925_0004`.
- **Confirmado, local:** fixtures removidas ao final; banco terminou com zero
  tenants e zero `delivery_read_operation`.
- **Artefato pronto para revisão:**
  `ApiMotoristaNuvem/DELIVERY_READ_V2_PRODUCTION_REBASED.patch`, SHA-256
  `3204d8f597d0561cde2cb2affaf58e001a2de232d808bdfcfb798ad19555fa5f`.
  Contém apenas `app/contracts.py` e `app/service.py`; `patch --dry-run` passou
  contra as cópias de produção. Não houve deploy, restart ou escrita externa.

## 2026-11-23 — pré-verificação de deploy interrompida

- **Confirmado, somente leitura:** patch rebased confere SHA-256
  `3204d8f597d0561cde2cb2affaf58e001a2de232d808bdfcfb798ad19555fa5f` e tem
  somente `app/contracts.py` e `app/service.py`.
- **Impedimento:** `contracts.py` atual confere com o hash esperado. O hash real
  de `service.py` é `8e567c916b6b5f91f5d1b817d0d63b7d4c454335279ddcedbb412bee84defbb3`,
  mas a autorização desta janela forneceu `8e567c916b6f5f91f5d1b817d0d63b7d4c454335279ddcedbb412bee84defbb3`.
  A divergência é de um caractere; conforme a regra de segurança, o deploy foi
  interrompido antes de backup, dry-run, patch, restart ou escrita externa.

## 2026-11-23 — deploy V2 controlado concluído

- **Pré-condições confirmadas:** hashes corrigidos de produção conferiram com os
  arquivos usados no rebase; patch SHA-256 `3204d8f597d0561cde2cb2affaf58e001a2de232d808bdfcfb798ad19555fa5f` e escopo de dois arquivos.
- **Backup verificável:** `/root/backup-api-motorista-v2-20261123T164456Z`;
  `contracts.py` SHA-256 `753c0670e99fbc52d1911009076c1e78e50d3361bf08042980e0afc4359ae7ba` e
  `service.py` SHA-256 `8e567c916b6b5f91f5d1b817d0d63b7d4c454335279ddcedbb412bee84defbb3`,
  permissões `644 root:root`. Restauração: `cp -a` desses dois arquivos para
  `/opt/api-motorista-nuvem/app/`, seguida de restart exclusivo da unidade.
- **Deploy:** `patch --dry-run`, aplicação, `py_compile` e importação passaram;
  reiniciada somente `api-motorista-nuvem.service` às 16:46:08 UTC.
- **Pós-deploy:** serviço `active`; health local e público retornaram HTTP 200;
  validação pura V2 aceitou `occurrence_guid`; logs posteriores ao boot contêm
  apenas health checks. Hashes pós-deploy: `contracts.py`
  `a3e83e65fa391edf91b65606f6a0338eac4dc7ecc351335c31c1d6adbafaa5c9`,
  `service.py` `9081ec67a23241ea3dfe9e070e0aff9d789d65b70968ce025079233b53fe004f`.
- **Não executado:** POST de leitura, reenvio S20, retorno Firebird, migration ou
  acesso ao PostgreSQL de produção.

## 2026-11-23 — diagnóstico somente leitura da rejeição V2

- A etiqueta `C02201400086350800000` não possui parser posicional no Flutter;
  o texto bruto normalizado é o código da ocorrência. A projeção da carga 776
  confirmou pedido 22014/produto 8635/parada 1997/quantidade 80, código igual e
  GUID `74DDEA91-1913-4877-A53B-AAD5DC74281F` em status `P`.
- O ledger de produção revelou duas recusas, com o mesmo GUID em minúsculas e
  códigos `OCORRENCIA_NAO_ENCONTRADA`; nenhuma entrega foi criada.
- A causa é a normalização `str(UUID(...))` em `contracts.py` seguida da igualdade
  sensível a caixa em `service.py:829`. Não houve alteração de dados ou código.
- ADB não tinha aparelho conectado; o estado SQLite real do S20 não foi lido.

## 2026-11-23 — correção canônica de occurrence_guid implantada

- **Implementação mínima:** apenas `app/service.py`; novo helper privado
  `_canonical_uuid` usa `UUID` nos dois lados da comparação. Não foram alterados
  contracts, tabelas, rotas, migrations, retorno, agente, Flutter ou Firebird.
- **Homologação local:** 10 testes PostgreSQL aprovados no PG18 local/migration
  `20260925_0004`, incluindo ocorrência publicada em maiúsculas e payload em
  minúsculas. Fixtures removidas; banco terminou vazio.
- **Patch:** `ApiMotoristaNuvem/DELIVERY_READ_V2_OCCURRENCE_GUID_CANONICAL.patch`,
  SHA-256 `18a04bd3316b5245cee9d4d879138856b1e0b5e43c2d35ebb5df823659f907c9`.
- **Publicação:** base V2 `service.py` SHA-256
  `9081ec67a23241ea3dfe9e070e0aff9d789d65b70968ce025079233b53fe004f` conferiu;
  backup `/root/backup-api-motorista-occurrence-guid-20261123T170419Z` criado
  (SHA-256 igual, `644 root:root`). Dry-run, compilação/importação e restart
  exclusivo passaram. Hash pós-deploy:
  `42eb5a3262c922bb264d3b9b2e53740e4951ac42c0c2c835e9cf5c72bc72eb47`.
- **Pós-deploy:** serviço active, health local/público HTTP 200 e validação pura
  de igualdade canônica passou. Sem POST, reenvio S20, banco, retorno ou Firebird.

## 2026-11-23 — auditoria somente leitura das recepções V2 da carga 776

- Manifesto `697AE01E-5C7A-4780-BB4F-221C1DFFB56F`: quatro aceitações no ledger,
  não três: 22014/8635 (`74DDEA91-1913-4877-A53B-AAD5DC74281F`),
  23318/8945 (`6A645BA4-43E7-4E22-8627-D7A8BD294EE8`) e duas ocorrências do
  23327, produtos 8896 (`0A75BE00-FCA0-4222-A040-A176FE070621`) e 8909
  (`23B44588-F1C6-43ED-81AD-329B86559F67`). Cada uma tem uma única operação
  `ACEITA/LEITURA_CONFIRMADA`; nenhuma duplicidade.
- Permanecem duas recusas históricas de 22014 com
  `OCORRENCIA_NAO_ENCONTRADA`, anteriores à correção; não são aceitações nem
  devem ser reenviadas.
- A projeção ainda mostra todas as ocorrências/pedidos/paradas `P`, pois este
  fluxo V2 somente grava ledger e não persiste a mutação em `detail_json`.
  Sem encerramento de viagem ou retorno Firebird nesta etapa.

## 2026-11-23 — diagnóstico integrado Nuvem/offline, somente leitura

- **Ledger versus projeção:** a divergência é comportamento atual comprovado:
  `register_delivery_read` altera `detail` apenas em memória e grava ledger; não
  atualiza `detail_json` nem as tabelas de projeção. O teste PostgreSQL existente
  exige explicitamente projeções read-only após aceite.
- **Alternativas avaliadas:** atualizar o snapshot diretamente no aceite é simples
  no curto prazo, mas próximo snapshot Firebird pode sobrescrever E para P e quebra
  a separação fonte/aceite. Recomendada: visão derivada de aceitações, idealmente
  projeção própria por ocorrência com unicidade, atualizada na transação do ledger
  e reconstruível a partir dele; o snapshot de origem permanece imutável.
- **Offline:** Flutter persiste snapshot e outbox SQLite; GUID/payload sobrevivem
  fechamento/reabertura e `sending` interrompido retorna a pending. Retry é por
  timer, início de sessão, retorno ao app e mudança da outbox; não há listener de
  conectividade que garanta envio imediato ao sinal de rede. Testes automatizados
  existem; teste físico em modo avião ainda não foi realizado.
- **Sem alteração:** nenhuma operação, POST, claim/ACK, retorno Firebird ou banco
  foi modificado nesta auditoria.

## Rotina de início

1. Ler `ESTADO_ATUAL.md` e `ULTIMO_PONTO.md`.
2. Confirmar escopo/restrições antes de tocar em fonte ou infraestrutura.
3. Registrar evidência nova assim que validada.

## Rotina de encerramento

1. Consolidar apenas fatos confirmados em `ESTADO_ATUAL.md`.
2. Atualizar `ULTIMO_PONTO.md` com bloqueio e próximo passo único.
3. Não criar documento paralelo: README é o ponto de entrada destes quatro arquivos.
