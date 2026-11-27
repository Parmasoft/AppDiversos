# App Motorista

## Documentação viva

Antes de alterar qualquer coisa, ler [ESTADO_ATUAL](Documentacao/ESTADO_ATUAL.md)
e [ULTIMO_PONTO](Documentacao/ULTIMO_PONTO.md). Atualizar o
[DIARIO_TECNICO](Documentacao/DIARIO_TECNICO.md) logo após cada validação ou
bloqueio; [MAPA_COMPONENTES](Documentacao/MAPA_COMPONENTES.md) define os
limites entre ambientes. Esses arquivos evitam reconstrução manual por memória.

Os blocos históricos abaixo foram preservados como evidência, mas o estado
operacional vigente é exclusivamente o da documentação viva acima.

## STATUS / ULTIMO PONTO - 23/11/2026 (V2 homologado localmente, nao implantado)

- Preparacao de deploy concluida somente em leitura: a API publica respondeu
  health HTTP 200, a unidade `api-motorista-nuvem.service` esta ativa e o
  PostgreSQL de producao esta em `20260925_0004 (head)`. Nenhum deploy ou
  reinicio ocorreu.
- O contrato V1 continua implantado. O rebase controlado contra os arquivos
  reais de producao foi concluido e aprovado em 10 testes PostgreSQL locais,
  preservando o ledger da migration 0004. O patch final esta em
  `ApiMotoristaNuvem/DELIVERY_READ_V2_PRODUCTION_REBASED.patch`; aguarda apenas
  revisao e autorizacao expressa de deploy.
- A primeira janela autorizada foi interrompida na conferência obrigatória de
  hash do `service.py`; nenhum backup, patch, restart ou escrita em produção foi
  realizado. Consulte `Documentacao/ULTIMO_PONTO.md` para o valor divergente.
- Com o hash corrigido, o patch V2 foi aplicado com backup, dry-run, compilação,
  importação, restart exclusivo e health local/público aprovados. A leitura real
  no S20 ainda não foi executada; retorno Firebird permanece desabilitado.
- A dependencia `mobile_driver_company_access` foi resolvida somente no ambiente
  temporario: o `tables.py` de producao e identico ao do workspace. Nenhum
  arquivo de producao, banco, servico ou aparelho foi alterado.

- A carga 776 foi publicada e a viagem aparece no Samsung S20, com 3 paradas,
  pedido 22014 e etiqueta 8635.
- A leitura foi bloqueada antes de qualquer confirmacao: a API oficial respondeu
  `delivery_read: campos nao permitidos: occurrence_guid`. O Flutter envia o
  contrato V2; a resposta identifica o whitelist V1 ainda implantado na Nuvem.
- O patch executavel e revisavel esta em
  `ApiMotoristaNuvem/DELIVERY_READ_V2_POSTGRESQL_HOMOLOGATION.patch` (SHA-256
  `6d187641788bec440adbfd41ab7ce336562a6f7f63031779f27b156c4a5dd434`). Ele
  altera somente `contracts.py`, `service.py` e os testes estritamente
  necessarios; nao altera Flutter, Firebird, agente, rotas, login ou migrations.
- O patch preserva replay por `tenant_id + operation_guid`, inclui
  `occurrence_guid` no hash V2, valida a ocorrencia contra viagem/parada/pedido/
  codigo e recusa novas operacoes sem GUID. Nenhum deploy foi feito, nenhuma
  leitura real foi reenviada e nenhum retorno ao Firebird foi habilitado.
- A homologacao PostgreSQL foi executada no WSL local, exclusivamente no
  `motorista_nuvem_test` do cluster `18/main`, em `127.0.0.1:5432`, migration
  `20260925_0004`. A suite `tests.test_postgresql_integration` aprovou 10 testes:
  ocorrencia exata, GUID valido/invalido, replay, conflito, concorrencia,
  rollback, unicidade e compatibilidade V1. Nenhuma conexao externa foi usada.
- O backup anterior a limpeza esta em
  `/var/backups/app-motorista-homologacao/motorista_nuvem_test_pre_v2_20261123T131727Z.dump`
  (SHA-256 `300230f9d15c2fec794812e31dc542b7a62a0c02e0b32936f8cb0a331d3f346a`).
  As fixtures foram removidas ao final; o banco continua na migration atual.
- A compatibilidade com `20260925_0004` exige preencher apenas metadados de
  ledger de retorno existentes (`return_payload_hash`, estado `PENDING`), sem
  chamar claim/ack, agente, Firebird ou `SP_APL_ENTREGA_NUVEM`. Nenhum deploy,
  reenvio do S20 ou retorno ao Firebird foi realizado. O patch esta pronto para
  revisao final de publicacao, nao para implantacao automatica.

## STATUS / ÚLTIMO PONTO — 19/11/2026

### Concluído

- O App Motorista Flutter opera pela internet contra a API oficial
  `https://motorista.parmatech.com.br`, hospedada na nuvem com PostgreSQL. O APK
  usa esse endereço por `dart-define`; o motorista não precisa configurar IP.
- A arquitetura definida é: App Flutter ↔ API Nuvem/PostgreSQL ↔
  `AgenteMotoristaGramDecor` ↔ Firebird. Ela segue o conceito operacional do
  App Malhas. O agente ainda não está automatizado para execução contínua.
- A sessão de homologação sincronizou, em rodada única e controlada, Paulo
  Henrique Gonçalves: empresa 10, transportador 22 e Motorista App ID 1, a
  partir de `E:\Dados Clientes\GramDecor\DADOS.FDB`. O retorno de entregas
  permaneceu desabilitado.
- Foi corrigido o bloqueio em **"Abrindo suas viagens..."**: o
  `SessionController` começava em `bootstrapping`, mas `restore()` não era
  chamado pelo ciclo real do app. `restore()` agora é iniciado uma única vez
  por instância, depois da inicialização dos listeners e da outbox; falhas de
  armazenamento seguro deixam o estado de bootstrap e são expostas como erro,
  sem serem tratadas como logout silencioso.
- Foram adicionados testes para o bootstrap sem sessão, para a chamada única
  de `restore()` em rebuilds e para falha de armazenamento. A validação desta
  rodada registrou `flutter analyze` sem problemas e `flutter test` com 103
  testes aprovados.
- APK de homologação gerado com:

  ```text
  API_BASE_URL=https://motorista.parmatech.com.br
  API_ENV=homologacao
  API_TIMEOUT_SECONDS=20
  MOTORISTA_READ_ONLY=false
  ```

  Artefato: `build\app\outputs\flutter-apk\app_motorista.apk`;
  versão `1.0.0+1` (versionCode 1).

- No Samsung S20, o APK foi instalado; o endpoint `/api/v1/health` respondeu
  `status: ok` no Chrome, login e autenticação funcionaram, e a tela **Minhas
  viagens** abriu exibindo **"Nenhuma viagem liberada"**. O aplicativo ainda
  não está homologado para entregas reais.

### Carga 776 e bloqueio atual

- A carga 776 (empresa 10, emissão 19/11/2026), para Paulo Henrique
  Gonçalves, contém 3 pedidos e 4 itens: 22014, 23318 e 23327. O ParmaGestor
  informou **"Manifesto gerado com sucesso"**, mas a viagem ainda não apareceu
  no aplicativo.
- O status efetivo do manifesto (`G` ou `L`) não foi consultado nesta rodada;
  tampouco foi executada ou confirmada a publicação pelo agente. A geração do
  manifesto, por si só, não comprova a liberação ao motorista nem a publicação
  na nuvem.
- Viagem e Acompanhamento no ParmaGestor falham com `Firebird SQL error -204:
  Table unknown TB_CARGA_MANIFESTO_NUVEM`. A causa estrutural foi confirmada:
  a tabela está ausente do Firebird de homologação. A consulta compartilhada
  está em `E:\Repositorio_Parmasoft\ParmaDistribuidora\Source\View\Mov\UManCargaViagem.pas`,
  linhas 641–690 (referência direta na linha 667); os chamadores estão em
  `UMovCarga.pas`, linhas 199–202 e 317–319.

### Pendências, bloqueios e próximo passo exato

- **Pendente/bloqueado:** instalar com segurança no Firebird de homologação
  `TB_CARGA_MANIFESTO_NUVEM` e `SP_APL_ENTREGA_NUVEM`. Nenhum DDL foi executado
  nesta auditoria.
- Os scripts-fonte identificados são:
  `E:\PARMASOFT_INTEGRACAO\Documentos\SQL_PACOTE_02A_PARADAS_MANIFESTO_APP_TABELAS_2026-10-19.sql`,
  `SQL_PACOTE_02B_PARADAS_MANIFESTO_APP_CHAVES_2026-10-19.sql` e
  `SQL_PACOTE_03_PROCEDURES_TRQ_PARADAS_MANIFESTO_APP_2026-10-19.sql`.
  O pacote 03 não deve ser executado integralmente. O arquivo do agente
  `firebird\20260925_0001_sp_apl_entrega_nuvem.sql` é apenas um envelope e não
  contém o corpo validado da procedure; não serve isoladamente para instalação.
- Os objetos existem como referência nos bancos
  `E:\_PARMA_TESTES\TEKNO_PRIME_PACOTES_20261019\TEKNO_PRIME_CLONE_RETRY.FDB`
  e `TEKNO_PRIME_COMPLEMENTO_CONSOLIDADO_20261020_V4.FDB`.
- **Próximo passo:** extrair o delta mínimo dos pacotes, comparar suas
  definições com um banco de referência e testá-lo em cópia descartável
  Firebird 2.5.9. Somente depois solicitar autorização para aplicação no
  `DADOS.FDB`, validar Viagem/Acompanhamento, consultar a carga 776 e as
  condições de liberação `G → L`, e executar uma rodada controlada do agente
  com retorno desabilitado.

#### Roteiro de retomada autorizado somente por etapas

1. Preparar scripts mínimos extraídos dos pacotes originais e comparar suas
   definições com o banco de referência.
2. Testá-los numa cópia descartável Firebird 2.5.9 e solicitar autorização
   específica antes de qualquer aplicação no `DADOS.FDB` de homologação.
3. Validar os botões Viagem e Acompanhamento; consultar o status real da carga
   776, o vínculo de Paulo e as condições de liberação `G → L`.
4. Executar uma rodada controlada do agente, com retorno desabilitado, e
   confirmar a publicação da viagem na nuvem e sua exibição no S20.
5. Homologar separadamente o retorno de entregas e, somente quando aprovado,
   integrar os scripts ao atualizador oficial do ParmaGestor.

### Regras de segurança permanentes

- Nunca alterar banco operacional de cliente sem autorização específica.
- Trabalhar somente com backups, cópias descartáveis e homologação autorizada.
- Não executar pacotes SQL completos indiscriminadamente; preservar
  idempotência, rastreabilidade e os scripts pendentes do atualizador oficial.
- Não habilitar retorno de entregas antes de homologar
  `SP_APL_ENTREGA_NUVEM` e todo o fluxo de retorno.

### Arquivos Flutter alterados nesta correção

- `lib/app.dart`
- `lib/auth/services/session_controller.dart`
- `test/app_initialization_widget_test.dart`
- `test/auth/session_controller_test.dart`

Flutter V1 do motorista Parmasoft. O primeiro bloco contém login, sessão segura,
refresh, Minhas Viagens, detalhe da viagem, paradas, pedidos e visualização das
ocorrências esperadas. Scanner e registro de leitura C/R ainda não fazem parte
deste bloco.

## Ambiente local

A API é configurada centralmente por `dart-define`. No emulador Android, o valor
padrão aponta para a máquina hospedeira:

```text
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:5055
```

Para celular físico, use o IP da máquina que executa a API:

```text
flutter run --dart-define=API_BASE_URL=http://SEU_IP_LOCAL:5055
```

Ambiente e timeout também podem ser definidos:

```text
--dart-define=API_ENV=desenvolvimento
--dart-define=API_TIMEOUT_SECONDS=20
```

Tokens são armazenados com `flutter_secure_storage`; senha e tokens não são
gravados em log. A interface segue o padrão mobile-first do projeto: letras
grandes, cartões amplos, alto contraste e somente informação operacional.
