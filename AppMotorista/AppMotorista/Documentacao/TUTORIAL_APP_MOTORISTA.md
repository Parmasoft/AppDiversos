# TUTORIAL APP MOTORISTA — PARMASOFT

> Documento mestre do App Motorista. Atualizado em **26/11/2026, 08:43 -03:00**, após homologação física offline do APK `1.0.0+2` no Samsung S20 e auditoria de conciliação somente leitura. App Motorista é independente do App Malhas; este documento não autoriza nem descreve alterações no outro projeto.

## Último ponto

**Atualização de 26/11/2026, 16:36 -03:00 — encerramento da homologação funcional do APK 1.0.0+4 aprovado; carga 782 conciliada:**

- **Homologação física final aprovada no Samsung S20:** carga 782 — DM Decor Ltda., pedido 23377. O produto 8906 foi coletado offline; sua releitura foi bloqueada com a mensagem `Todas as ocorrências desta etiqueta já foram recepcionadas no Pedido`, preservando os contadores em uma entrega e uma pendência. O produto 8899 foi coletado posteriormente ainda offline; parada/carga passaram a azul, `Aguardando sincronização` e disponível offline. Após Internet, a carga passou automaticamente a amarelo e as cargas anteriores permaneceram preservadas. Com as homologações das cargas 779 a 782, o fluxo funcional online, offline, persistência, duplicidade, retorno automático, idempotência e propagação reativa está aprovado para homologação.
- **Conciliação somente leitura da carga 782:** manifesto `FAFD2593-0D5D-44C5-B27E-D55678F8C84F`, parada 2016, pedido 23377. PostgreSQL DigitalOcean, em `READ ONLY`/`ROLLBACK`, tem exatamente duas operações: `59e9a598-7188-479c-b30e-d3ad0a6d72ed` / ocorrência `3091A3DA-2BAF-4445-AD92-D84EF32870C8` / código `C02337700089061017000`; e `c7b25476-ee43-46e7-a722-907444a5a0e4` / ocorrência `2783F5BD-670D-44D8-958A-DB79922993CC` / código `C02337700088991219000`. Ambas `ACEITA/LEITURA_CONFIRMADA`, `APPLIED`, uma tentativa, retorno `ACEITA/ENTREGA_REGISTRADA`, `replay=false`. A consulta devolveu `2 operações / 2 GUIDs de operação distintos / 2 GUIDs de ocorrência distintos / 2 aceitações / 0 fora do padrão` — não existe operação adicional da leitura bloqueada.
- **Agente e Firebird:** SQLite do Agente possui as mesmas duas chaves, ambas `ACKED`, sem erro e `replay=0`; recebidas/aplicadas em `19:31:01Z`, ACK em `19:31:01Z` e `19:31:02Z`; `integrity_check=ok`. Firebird possui as duas ocorrências em `E`, pedido/parada em `E`, manifesto `L` e `CARG_STATUS='A'` preservado. A auditoria Firebird possui exatamente quatro registros técnicos — tentativa `S` e resultado `N` para cada operação — todos `ENTREGA_REGISTRADA` e `REPLAY='N'`. Não há duplicidade ou reaplicação logística. Rodadas do Agente às 16:32–16:34 -03 concluíram `exit=0`, `SEM_ALTERACAO`, sem erro ou retorno pendente.
- **Pendências para implantação — não autorizadas nesta etapa:** (1) validação e implantação das melhorias de segurança da API Nuvem; (2) assinatura definitiva de produção do APK; (3) integração dos scripts necessários ao atualizador oficial do ParmaGestor. Estas pendências não foram implementadas, implantadas nem testadas nesta homologação.
- **Melhorias futuras — não implementadas:** descoberta automática de novas cargas em **Minhas viagens**; correção da acentuação do indicador `Disponível offline` exibida incorretamente nos prints.
- **Backup consolidado final validado:** `E:\BACKUPS_APP_MOTORISTA\APP_MOTORISTA_HOMOLOGADO_FINAL_2026-11-26_163700\APP_MOTORISTA_FONTES_TESTES_DOCUMENTACAO_FINAL_2026-11-26_163700.zip`; 3.216.080 bytes; SHA-256 `EAF9145B2827B5EEA839F64CAE9BABF1C5A38B5A1529097D6881ED30B56FE888`; abertura validada com 181 entradas. APK original preservado separadamente em `E:\BACKUPS_APP_MOTORISTA\APP_MOTORISTA_HOMOLOGADO_FINAL_2026-11-26_163700\APK_APP_MOTORISTA_1.0.0+4_HOMOLOGADO.apk`; 64.491.488 bytes; data `26/11/2026 15:28:29 -03:00`; SHA-256 `913F12290CC903278C39757229F9EA7CA3469A9BCA67543C0219E542DFDA376B`. Todos os backups anteriores, incluindo APKs `1.0.0+2` e `1.0.0+3`, foram preservados sem sobrescrita.
- **STATUS/ÚLTIMO PONTO:** homologação funcional do App Motorista com APK `1.0.0+4` encerrada e aprovada fisicamente. O próximo passo exige autorização explícita para uma das pendências de implantação; não alterar fontes, APK, API, bancos, Agente, ParmaGestor ou App Malhas até nova autorização.

**Atualização de 26/11/2026, 16:06 -03:00 — homologação física do APK 1.0.0+4 aprovada na carga 781; auditoria logística somente leitura conciliada:**

- **Resultado físico homologado no Samsung S20:** na carga 781 — PARMASOFT TESTE FINAL, Maria Aparecida de Araújo Gomes e Carlos Adriano Jovencio foram concluídos online e permaneceram amarelos; Luka Decor Ltda. foi concluída offline e ficou azul. As duas paradas já sincronizadas permaneceram amarelas, comprovando a correção da granularidade. A carga integralmente concluída offline ficou azul; após restabelecer Internet, carga e entrega pendente passaram automaticamente a amarelo, sem pull-to-refresh. O indicador de disponibilidade offline apresentou o estado correto e as cargas anteriores foram preservadas. As duas inconsistências físicas do APK +3 estão, portanto, homologadas no APK +4.
- **Identidade e conciliação da carga:** manifesto `C26D9BDE-F9BC-47D7-8AB4-277BB14B42A9`, empresa 10, carga 781. PostgreSQL DigitalOcean, em `READ ONLY`/`ROLLBACK`, contém exatamente 4 operações `ACEITA/LEITURA_CONFIRMADA`, 4 `operation_guid` distintos e 4 `occurrence_guid` distintos, todos `APPLIED`, uma tentativa, `ACEITA/ENTREGA_REGISTRADA`, `replay=false`; zero linhas fora desse padrão. SQLite do Agente contém as mesmas quatro chaves, todas `ACKED`, sem `last_error`, com `replay=0`; `integrity_check=ok`. Firebird contém as mesmas quatro ocorrências em `E`, pedidos/paradas `E`, manifesto `L` e status comercial `CARG_STATUS='A'` preservado.

| Parada | Pedido / cliente | Ocorrências | PostgreSQL / Agente / Firebird |
|---|---|---:|---|
| 2013 | 23519 — Maria Aparecida de Araújo Gomes | 2 | `APPLIED` / `ACKED` / `E` |
| 2014 | 23492 — Carlos Adriano Jovencio | 1 | `APPLIED` / `ACKED` / `E` |
| 2015 | 23493 — Luka Decor Ltda. | 1 | `APPLIED` / `ACKED` / `E` |

- **GUIDs, ACK e idempotência:** operações/ocorrências conferidas em todas as camadas: `8ed203d3-a138-4c02-b76d-48369d5deec2` / `8D38B9B0-DD20-435F-BBD0-82CB89EC73EC`; `ff82ee90-63c7-4c1e-80b9-d046d8d0e45d` / `95DA77F1-7101-4493-AA85-F4CDEE9CC2ED`; `410dd081-650f-40c1-a7cb-829c987b1cee` / `F0B023DF-32D8-4B4E-9CD9-34EC2DE22424`; `d4bb3e44-8ccb-4bdb-9b4c-74a97398698b` / `C1C0435D-C14B-4A44-9BD4-6B6F4EA3C9E5`. A auditoria Firebird possui exatamente 8 registros técnicos — o par esperado tentativa canônica `S` + resultado `N` por operação — todos `ENTREGA_REGISTRADA`, `REPLAY='N'`. Não há duplicidade nem reaplicação logística. As duas ocorrências de Maria possuem GUIDs distintos; o mesmo código físico foi legitimamente associado a duas ocorrências pendentes diferentes, não sendo duplicidade.
- **Agente preservado e normal:** rodada de 16:04 -03 concluiu `exit=0`; aplicou/reconheceu a revisão 4 do manifesto 781 e a rodada seguinte informou `SEM_ALTERACAO`, sem retorno pendente ou erro. Nenhum processo foi interrompido.
- **Reteste físico recomendado de duplicidade no APK +4:** usar nova carga/pedido pendente e, antes de ficar offline, garantir snapshot `Disponível offline`. Escolher uma etiqueta cujo código tenha **exatamente uma ocorrência pendente**; se houver multiplicidade legítima do mesmo código, consumir todas as ocorrências esperadas antes do teste de bloqueio. Ativar modo avião, coletar a etiqueta uma vez e registrar contadores/GUID; reler a mesma etiqueta imediatamente. Esperado: mensagem de bloqueio, nenhum novo `operation_guid`, nenhum incremento de entregues e nenhum reordenamento indevido. Restaurar Internet, aguardar ACK e transição automática azul → amarelo; então realizar auditoria somente leitura. Nunca usar uma etiqueta cuja multiplicidade pendente seja desconhecida, pois ela pode corresponder a mais de uma ocorrência legítima, como ocorreu na parada 2013.
- **Melhorias futuras registradas, não implementadas:** (1) descoberta automática de novas cargas em **Minhas viagens**, sem exigir login/atualização manual; (2) correção da acentuação do rótulo `Disponível offline` exibida incorretamente nos prints. Nenhuma fonte foi alterada nesta auditoria.
- **STATUS/ÚLTIMO PONTO:** APK `1.0.0+4` está homologado fisicamente para o fluxo principal online/offline, propagação granular de cores e disponibilidade offline. A carga 781 está conciliada nas três camadas. Aguardar autorização antes de qualquer intervenção adicional.

**Atualização de 26/11/2026, 15:29 -03:00 — correção pontual da granularidade reativa concluída, validada e APK 1.0.0+4 gerado; aguardar homologação física:**

- **Recuperação do artefato homologado +3:** o arquivo renomeado pelo usuário foi localizado em `E:\Jorginho\AppMotorista\AppMotorista\build\app\outputs\flutter-apk\app_motorista.apk`; 64.491.488 bytes; data `26/11/2026 13:51:36 -03:00`; SHA-256 `A59914F6B185B1EF92238ACFDF3A6B940A9B23E385C4C1E2EA11910CEB350B03`, idêntico ao hash registrado do APK `1.0.0+3`. Foi preservada cópia independente em `E:\BACKUPS_APP_MOTORISTA\APP_MOTORISTA_PRE_GRANULAR_2026-11-26_144300\APK_APP_MOTORISTA_1.0.0+3_HOMOLOGADO.apk`, com o mesmo tamanho e hash. O ZIP preventivo de fontes/testes/documentação permanece íntegro: 3.210.327 bytes; SHA-256 `07E2F71B4CF9C028FEB0253957848FC24286E50580A57AB53E37003A6F2C6F39`; 181 entradas validadas. O APK `1.0.0+2` e todos os backups anteriores permanecem intactos.
- **Correção localizada implementada:** `TripStateController` continua centralizado, observado e protegido por token monotônico por manifesto, mas agora publica `pendingStopIds` e `pendingOrderIdsByStop`, lidos exclusivamente da outbox SQLite após a leitura do snapshot local confirmado. `awaitingSync` continua global somente para representar a carga. `TripDetailScreen` consome apenas `pendingStopIds`; `StopScreen`, apenas os pedidos pendentes de sua própria parada. Assim, uma coleta offline não torna azuis paradas/pedidos já sincronizados. A atualização de outbox posterior publica nova projeção e preserva a transição automática azul → amarelo.
- **Disponibilidade offline corrigida:** um `TripStateSnapshot` só é publicado quando `TripLocalStore.readSnapshot()` encontrou o snapshot SQLite completo e persistido; por isso ele declara `offlineAvailability=available`. `TripsScreen` passa a consumir esse valor reativo para o resumo afetado, em vez de preservar o rótulo anterior em memória. Não há consulta HTTP, temporizador, reload global ou mudança nos mecanismos de coleta/outbox/idempotência.
- **Arquivos alterados nesta correção:** `lib/main.dart`; `lib/viagens/services/trip_state_controller.dart`; `lib/viagens/screens/trips_screen.dart`; `lib/viagens/screens/trip_detail_screen.dart`; `lib/viagens/screens/stop_screen.dart`; `test/viagens/trip_state_controller_test.dart`; `test/viagens/delivery_navigation_widget_test.dart`; `pubspec.yaml` (somente build `+3` → `+4`); e este documento. API, Agente, bancos, migrations, ParmaGestor e App Malhas não foram alterados. O Agente permaneceu ativo.
- **Testes aprovados:** análise Flutter sem issues. A suíte completa final registrou `done.success=true`, zero eventos de erro, zero skips, 26 eventos internos de carregamento e **114 casos de teste distintos aprovados** (os 110 anteriormente aceitos, mais 4 novos). Cobertura nova: granularidade parada/pedido no controlador; disponibilidade offline após snapshot SQLite; tela Viagem preservando amarelo em parada já sincronizada enquanto outra fica azul; tela Parada isolando pedido pendente. Os testes existentes já cobrem coleta online/offline, retorno de navegação, outbox, sincronização, rejeição/conflito, UUID/idempotência, ordenação e persistência; não houve regressão observada.
- **Ambiente Flutter:** `flutter.bat` permaneceu bloqueado no lock interno do wrapper antes de iniciar o Dart. Sem remover/alterar qualquer arquivo do SDK, `flutter analyze`, `flutter test` e o build foram executados diretamente pelo mesmo `flutter_tools.snapshot` e Dart já instalados; os resultados e o APK são produzidos pelo Flutter Tool oficial. O processo Dart Language Server bloqueado e os processos transitórios do wrapper iniciados por esta sessão foram encerrados controladamente; VS Code, Agente e outros projetos não foram interrompidos.
- **APK release novo:** `E:\Jorginho\AppMotorista\AppMotorista\build\app\outputs\flutter-apk\app-release.apk`; 64.491.488 bytes; compilado em `26/11/2026 15:28:29 -03:00`; SHA-256 `913F12290CC903278C39757229F9EA7CA3469A9BCA67543C0219E542DFDA376B`. `aapt` confirmou package `br.com.parmasoft.app_motorista`, `versionName=1.0.0`, `versionCode=4`, `minSdk=24`, `targetSdk=36`. O build recebeu `API_BASE_URL=https://motorista.parmatech.com.br`, `API_ENV=homologacao`, `API_TIMEOUT_SECONDS=20` e `MOTORISTA_READ_ONLY=false`. A assinatura é compatível com +3: ambos possuem o certificado SHA-256 `1a58367bccab491a3b756b818bdb0ca9eb3c2934ecd1171c930993fd7f80f7f0`; portanto a atualização sobre +3 preserva os dados locais, desde que não haja desinstalação/limpeza manual.
- **Roteiro físico específico para carga 780:** instalar o APK +4 sobre o +3 sem limpar dados; manter duas paradas já amarelas e concluir uma última parada offline; ao retorno automático para Viagem, confirmar somente a parada recém-concluída azul e as anteriores amarelas; entrar/voltar da Parada e Pedido e confirmar a mesma granularidade; em Minhas viagens, confirmar carga azul enquanto houver pendência e `Disponível offline` após snapshot gravado; restaurar Internet sem pull-to-refresh e confirmar transição somente do item/parada/carga pendentes para amarelo. Repetir uma leitura online e uma offline, sem reutilizar etiqueta já recepcionada.
- **STATUS/ÚLTIMO PONTO:** correção construída e validada localmente; APK `1.0.0+4` pronto para homologação física, mas ainda não instalado pelo processo desta auditoria. A descoberta automática de novas cargas em Minhas viagens continua registrada como melhoria futura e não foi implementada. Aguardar homologação física explícita antes de considerar esta correção aprovada definitivamente.

**Atualização de 26/11/2026, 14:50 -03:00 — backup preventivo da correção de granularidade criado; implementação aguardando preservação do APK 1.0.0+3:**

- **Backup independente validado:** `E:\BACKUPS_APP_MOTORISTA\APP_MOTORISTA_PRE_GRANULAR_2026-11-26_144300\APP_MOTORISTA_FONTES_TESTES_DOCUMENTACAO_2026-11-26_144300.zip`; 3.210.327 bytes; criado em `26/11/2026 14:49:53 -03:00`; SHA-256 `07E2F71B4CF9C028FEB0253957848FC24286E50580A57AB53E37003A6F2C6F39`. O arquivo contém 181 entradas de `android`, `lib`, `test`, `Documentacao` e arquivos de configuração/fonte do App Motorista; foi aberto para validação de integridade sem erro. Backups anteriores permanecem intactos, inclusive o APK `1.0.0+2` homologado em `E:\BACKUPS_APP_MOTORISTA\APP_MOTORISTA_PRE_UI_2026-11-26_102128\APK_APP_MOTORISTA_1.0.0+2_HOMOLOGADO.apk`.
- **Impedimento objetivo antes de alterar fontes:** a busca somente leitura no diretório de build, nos backups existentes e no volume `E:` não localizou o APK `1.0.0+3` (`app-release.apk` ou nome equivalente). Portanto não existe cópia disponível a preservar separadamente neste momento. Nenhum APK foi recriado, nenhuma fonte foi alterada e a implementação ainda não foi iniciada, pois recriar o artefato não garante preservar a cópia originalmente homologada e não foi autorizado nesta etapa.
- **STATUS/ÚLTIMO PONTO:** backup de fontes/testes/documentação está íntegro; o APK `1.0.0+2` está preservado; falta localizar ou autorizar explicitamente a recriação controlada do APK `1.0.0+3` antes de iniciar a correção de granularidade. O Agente permaneceu em execução normal.

**Atualização de 26/11/2026, 14:40 -03:00 — auditoria somente leitura da homologação física do APK 1.0.0+3, carga 780; conciliação logística aprovada e inconsistência visual localizada:**

- **Escopo e preservações:** foram executadas apenas leituras no SQLite do Agente, nos logs, no Firebird de homologação (consultas `SELECT` seguidas de `ROLLBACK`) e no PostgreSQL DigitalOcean (transações `BEGIN TRANSACTION READ ONLY`/`ROLLBACK`). Não foram alterados fontes, testes, APK, API, Agente, bancos, configurações, ParmaGestor ou App Malhas. O Agente permaneceu ativo; as rodadas de 14:37, 14:38 e posteriores concluíram `exit=0`, sem erro, e o manifesto `7AD338AF-9D2B-4A95-A0E8-94D49C8D9F62` está na revisão 7 sem alteração.
- **Carga 780 conciliada integralmente:** há **14** entregas legítimas, **14 `operation_guid` distintos** e **14 `occurrence_guid` distintos**. No PostgreSQL, todas estão `ACEITA/LEITURA_CONFIRMADA`, `APPLIED`, com `return_attempt_count=1`, retorno `ACEITA/ENTREGA_REGISTRADA` e `replay=false`; nenhuma divergência de estado/tentativa/replay foi encontrada. No SQLite do Agente, são as mesmas 14 chaves, todas `ACKED`, sem `last_error`, com `replay=0`; `PRAGMA integrity_check=ok`. No Firebird, as 14 ocorrências estão `E`, pedidos/paradas estão `E`, e a auditoria técnica contém exatamente o par esperado por operação: tentativa 1 canônica `S` e tentativa 2 de resultado `N`, ambas `ENTREGA_REGISTRADA`, `REPLAY='N'` — 28 registros técnicos, sem reaplicação.

| Parada | Pedido / cliente | Entregas conciliadas | Estado PostgreSQL / Agente / Firebird |
|---|---|---:|---|
| 2010 | 23536 e 23563 — Marco Aurélio Pereira de Oliveira | 2 + 1 | `APPLIED` / `ACKED` / `E` |
| 2011 | 23572 — Maria Denise Kapronczai | 3 | `APPLIED` / `ACKED` / `E` |
| 2012 | 23569 — Parma Móveis Ltda. | 8 | `APPLIED` / `ACKED` / `E` |

- **GUIDs preservados e idempotência comprovada:** as chaves da carga conferem entre as três camadas: `817c7326…371f/F40ECB03…35B2`, `892a2357…94f3/7713815A…2634`, `009471bd…fa82/90B4DF46…8680`, `f90f3e52…a610/B5403D9E…719D`, `4365b00c…741f/561B0DAF…A224`, `23326370…fe6d/1506FED2…A6CD`, `7575105b…6a00/317969E1…5892`, `605f3d57…68e/685E8972…C2FA`, `8be07d10…8629/A2E2A87B…51E3`, `8860f4b0…d7ec/6E774347…1C4F`, `c82c6769…e199/C346649A…2A19`, `dbf8bbc0…e80c/7DF733E0…873C`, `95bf25cd…c326/878DEF45…453C` e `f91239a7…1951/CA0C7E7F…A40C`. A carga comercial permanece `CARG_STATUS='A'` e o manifesto `L`; a conclusão logística não alterou o status comercial.
- **Causa exata da cor azul indevida — comprovada por leitura do Flutter:** `TripStateController` publica corretamente o `TripDetail` reconstruído do SQLite, mas expõe `awaitingSync` somente no nível do manifesto. Em `lib/viagens/screens/trip_detail_screen.dart`, `_applyLocalState()` transforma esse único booleano em `_stopsAwaitingSync` para **todas** as paradas concluídas (`if (state.awaitingSync && stopIsCompleted(stop))`). Portanto, ao concluir Parma Móveis offline, a pendência legítima de uma operação do manifesto colore também Marco Aurélio e Maria Denise de azul. O mesmo padrão existe em `lib/viagens/screens/stop_screen.dart` para pedidos concluídos de uma parada. Não houve propagação logística indevida: é exclusivamente apresentação transitória em memória.
- **Por que reabrir a viagem corrige ainda offline:** a reabertura chama `TripsService.get()`; como há snapshot local, ele lê `TripLocalStore`/SQLite persistido. Em seguida `TripDetailScreen._loadTrip()` consulta `pendingSyncStopIds(manifestGuid)` no `OutboxLocalStore`, que calcula os IDs individuais pendentes. Assim, somente a parada 2012 fica azul e as paradas 2010/2011 voltam imediatamente a amarelo, sem chamada necessária à API. A primeira apresentação é a projeção em memória do controlador; a reabertura reconstrói a projeção persistida no SQLite e aplica o marcador granular da outbox.
- **Indicador “Aguardando download” — causa comprovada por leitura:** o download em segundo plano persiste o snapshot completo no SQLite e chama `TripsService.notifyListeners()`. Com `TripStateController` instalado, `TripsScreen._handleSyncEvent()` retorna deliberadamente sem recarregar; depois, `_updatedSummary()` preserva `item.offlineAvailability` em vez de derivá-lo do SQLite. Por isso um cartão já funcional offline pode conservar visualmente `Aguardando download`. Não é ausência de snapshot nem bloqueio offline.
- **Proposta mínima e localizada, sem implementação:** estender `TripStateSnapshot` com os conjuntos granulares `pendingStopIds` (e, para a tela de parada, `pendingOrderIds` por parada), calculados após a confirmação da transação SQLite juntamente com o snapshot; `TripDetailScreen` e `StopScreen` devem consumir esses conjuntos, nunca o booleano global, para suas cores. Manter `awaitingSync` apenas no nível da carga em `TripsScreen`. No mesmo controlador, publicar a disponibilidade offline derivada de `TripLocalStore.hasCompleteSnapshot`/estado de download e fazer `TripsScreen` atualizar somente o resumo afetado, sem HTTP nem reload global. Testar cenário exatamente reproduzido: duas paradas já ACKed + última offline, retorno automático, reabertura offline, e azul→amarelo após ACK.
- **Melhoria futura registrada, não implementada:** a relação **Minhas viagens** deve incorporar automaticamente novas cargas disponibilizadas ao motorista, sem exigir novo login ou atualização manual. Essa melhoria é distinta da correção de estado local: exige uma estratégia de descoberta/atualização de lista que preserve o uso offline, sem temporizador artificial nem impacto nos manifestos já carregados.
- **STATUS/ÚLTIMO PONTO:** a homologação física da carga 780 confirmou a atualização reativa para os fluxos online, offline e azul→amarelo sem pull-to-refresh. A única pendência funcional conhecida é a marcação azul transitória excessiva ao retornar da última parada offline, mais o rótulo visual de disponibilidade offline. Ambos estão diagnosticados; nenhuma correção foi implementada. Aguardar autorização explícita.

**Atualização de 26/11/2026, 13:52 -03:00 — APK release 1.0.0+3 gerado, validado e aguardando homologação física da carga 780:**

- **Correção limitada aos artefatos reconstruíveis:** a árvore inicialmente autorizada `build\app\intermediates\merged_native_libs\release\mergeReleaseNativeLibs\out` foi validada como interna a `build` e ficou sem itens `ReadOnly`. A varredura comprovou o mesmo atributo em outros artefatos temporários do próprio `build`; conforme autorização condicional, o atributo `ReadOnly` foi removido exclusivamente de toda a árvore `E:\Jorginho\AppMotorista\AppMotorista\build`, com zero itens restantes. Nenhuma fonte, configuração, banco, API, Agente, ParmaGestor, App Malhas, backup ou APK homologado foi alterado.
- **Build release aprovado:** `flutter build apk --release` concluiu `√ Built build\app\outputs\flutter-apk\app-release.apk (61.5MB)` em 101,7 s. Defines aplicados: `API_BASE_URL=https://motorista.parmatech.com.br`, `API_ENV=homologacao`, `API_TIMEOUT_SECONDS=20`, `MOTORISTA_READ_ONLY=false`. Assim, o APK é operacional em homologação, não somente leitura.
- **Artefato novo:** `E:\Jorginho\AppMotorista\AppMotorista\build\app\outputs\flutter-apk\app-release.apk`; 64.491.488 bytes; compilado em `26/11/2026 13:51:36 -03:00`; SHA-256 `A59914F6B185B1EF92238ACFDF3A6B940A9B23E385C4C1E2EA11910CEB350B03`.
- **Metadados Android verificados:** `aapt` confirmou package `br.com.parmasoft.app_motorista`, `versionName=1.0.0`, `versionCode=3`, `minSdk=24`, `targetSdk=36`. Portanto corresponde a `1.0.0+3` e é superior ao APK homologado `1.0.0+2`.
- **Compatibilidade de atualização comprovada:** `apksigner verify --print-certs` devolveu no APK novo e no APK `1.0.0+2` preservado o mesmo certificado `C=US, O=Android, CN=Android Debug`, SHA-256 `1a58367bccab491a3b756b818bdb0ca9eb3c2934ecd1171c930993fd7f80f7f0`. Como package ID e certificado coincidem e `versionCode` passou de 2 para 3, o Android deve aceitar atualização sobre o APK atual sem desinstalar; dados locais (SQLite/sessão/outbox) são preservados pela atualização, salvo ação manual externa de limpeza de dados.
- **Linha de base aceita:** conforme autorização, manter o registro histórico de 184 com a ressalva de metodologia não comprovada; a linha de base verificável atual é de 110 casos visíveis distintos, sem skips, todos aprovados, além dos dois novos casos reativos. `flutter analyze` permanece sem issues.
- **Agente preservado:** durante o build, a árvore exclusiva `CMD 19472 → PowerShell 19260` continuou ativa. As últimas rodadas terminaram `exit=0`, `SEM_ALTERACAO`, sem retorno pendente ou erro.
- **Roteiro de homologação física — carga 780:** (1) no Samsung S20, manter dados do aplicativo e instalar este APK **sobre** o 1.0.0+2, sem desinstalar/limpar armazenamento; (2) com Internet, abrir a carga 780 e aguardar o snapshot/local offline; (3) coletar uma etiqueta inédita online e confirmar imediatamente, ao voltar sem pull-to-refresh, item → pedido → parada → viagem atualizados; (4) ativar modo avião, coletar outra etiqueta inédita e repetir a navegação de retorno, confirmando azul imediato em todos os ancestrais; (5) ainda offline, testar releitura da mesma etiqueta e confirmar bloqueio sem alteração de contadores; (6) restaurar Internet sem pull-to-refresh e observar a transição azul → amarelo automática em item/pedido/parada/viagem; (7) se houver rejeição/conflito disponível em ambiente controlado, confirmar isolamento das outras ocorrências; (8) registrar hora, carga, parada, pedido, etiqueta, `operation_guid`/`occurrence_guid` e evidência visual para conciliação read-only posterior. Não realizar limpeza de dados, logout explícito ou retorno manual por GUID.
- **STATUS/ÚLTIMO PONTO:** APK `1.0.0+3` está pronto e não instalado; aguardar exclusivamente a homologação física da carga 780 no Samsung S20 antes de considerar a atualização reativa definitivamente aprovada.

**Atualização de 26/11/2026, 13:36 -03:00 — geração autorizada do APK +3 bloqueada por atributo somente leitura em artefato Gradle, sem novo APK:**

- **Build solicitado com configuração correta:** foi iniciado `flutter build apk --release` com `API_BASE_URL=https://motorista.parmatech.com.br`, `API_ENV=homologacao`, `API_TIMEOUT_SECONDS=20` e `MOTORISTA_READ_ONLY=false`. A saída verbosa confirma que o kernel recebeu literalmente esses quatro defines e recompilou `trip_state_controller.dart`. O package configurado permanece `br.com.parmasoft.app_motorista`; `pubspec.yaml` permanece preparado em `1.0.0+3`.
- **Resultado comprovado do Gradle:** o build independente retornou `BUILD FAILED in 5s`, tarefa `:app:mergeReleaseNativeLibs`, com `java.nio.file.AccessDeniedException` em `E:\Jorginho\AppMotorista\AppMotorista\build\app\intermediates\merged_native_libs\release\mergeReleaseNativeLibs\out\lib\arm64-v8a`. A inspeção somente leitura confirmou que esse diretório e itens abaixo possuem atributo Windows `ReadOnly`; o ACL permite `Modify`, logo o atributo é a causa imediata observável.
- **Preservações:** não houve modificação de fonte, API, banco, Agente, ParmaGestor ou App Malhas. Não foi alterado nenhum atributo além da árvore de testes autorizada anteriormente. O APK de saída atual ainda é o antigo `1.0.0+2`, 64.491.484 bytes, datado de 25/11/2026 16:28:47 -03:00; o APK homologado separado e todos os backups permanecem intactos. Não existe APK `1.0.0+3` a validar/instalar.
- **Próxima autorização necessária:** permitir remover exclusivamente o atributo `ReadOnly` da árvore de artefato reconstruível `build\app\intermediates\merged_native_libs\release\mergeReleaseNativeLibs\out` (incluindo arquivos/subdiretórios), ou orientar uma alternativa. Não executar nova compilação até essa autorização.

**Atualização de 26/11/2026, 13:26 -03:00 — auditoria read-only da divergência 184 × 136 concluída; nenhuma regressão de testes pela implementação reativa:**

- **Evidência histórica encontrada:** as únicas evidências originais localizadas para a marca de 184 estão no próprio documento mestre, preservadas literalmente no backup pré-UI de 26/11, linhas históricas 68 e 77: comando declarado `flutter test -r json`, evento terminal declarado `{"success":true,"type":"done"}` e `TEST_EXIT=0`. Não há log JSON/console original, relatório de testes, filtro, shard ou lista de casos arquivado fora dessas anotações. Portanto o êxito histórico é documentado, mas sua contagem não é auditável por evidência primária preservada.
- **Metodologia atual verificável:** o comando atual foi `flutter test --reporter silent --file-reporter json:<arquivo temporário>`. O relatório JSON tem `done.success=true`, zero eventos `error`, zero testes `skipped`, 26 eventos ocultos de carregamento e **110 casos de teste visíveis/diferentes**, mais 26 carregamentos = **136 `testStart`**. O número 136 não é quantidade de casos distintos: ele inclui um evento oculto de carregamento por arquivo. A contagem por declarações estáticas é 109 porque alguns testes são materializados dinamicamente; o resultado JSON é a medida executada mais confiável.
- **Inventário pré-UI × atual, extraído em diretório temporário independente:** o backup preventivo `APP_MOTORISTA_FONTES_2026-11-26.rar` foi validado pelo SHA-256 `B5936D0D…F781D2` e dele foram extraídos somente `AppMotorista/test` e o tutorial para `C:\Users\Jorge Parma\AppData\Local\Temp\appmotorista-test-audit-20261126`. Pré-UI: 25 arquivos `*_test.dart`, 107 declarações estáticas. Atual: 26 arquivos, 109 declarações. Os 25 arquivos comuns possuem SHA-256 idêntico, sem qualquer caso removido, substituído ou alterado. A única adição é `test/viagens/trip_state_controller_test.dart`, com 2 casos: isolamento por motorista e descarte de resposta antiga. Não há `@Skip`, `skip:` ou `.skip(` no pré-UI nem no atual; o relatório atual confirma zero skips.
- **Inventário dos 110 casos visíveis atuais por arquivo:** 1 `app_initialization`; 5 `homologation_config`; 2 `login_widget`; 2 `mobile_bootstrap`; 10 `session_controller`; 5 `admin_configuration`; 1 `auth_repository`; 2 `app_database`; 2 `fallback_session_storage`; 4 `outbox_local_store`; 9 `outbox_sync_controller`; 8 `delivery_local_store`; 3 `delivery_navigation`; 4 `delivery_progress`; 3 `delivery_repository`; 9 `delivery_scanner_controller`; 3 `hardware_barcode_buffer`; 1 `offline_navigation`; 3 `order_scanner`; 3 `trip_completion_navigation`; 4 `trip_local_store`; 2 `trip_models`; 2 `trip_sort`; **2 `trip_state_controller` novos**; 6 `trips_offline_delivery_service`; 14 `trips_offline_service`. Os 26 carregamentos ocultos completam os 136 eventos JSON.
- **Git e backup de 25/11:** o único commit-base disponível é `9f699964`; ele possui 21 arquivos de testes e não representa o worktree homologado, que sempre permaneceu não versionado. O patch do backup pré-UI preserva a diferença do worktree e a comparação direta acima é a prova relevante. O RAR homologado de 25/11 tem SHA-256 conferido (`20231991…9B50F4`) igual ao `SHA256SUMS.txt`, porém é RAR5 AES e `UnRAR/Rar` encerra com `Programa abortado` sem a credencial de abertura; seu conteúdo não pôde ser listado ou extraído. Assim, não se afirma comparação de conteúdo desse backup sem evidência acessível.
- **Conclusão comprovada:** a implementação reativa preservou integralmente a suíte pré-UI e acrescentou dois casos; ela não é a causa de uma redução de 184 para 136. Com `pubspec.lock` idêntico entre pré-UI e atual, 107 declarações pré-UI e 108 casos visíveis inferíveis antes dos dois novos casos, a marca histórica de **184 não pode corresponder a 184 testes distintos da versão preservada**. A explicação mais sustentada é contagem histórica incorreta de eventos/saída JSON ou evidência de uma árvore diferente não preservada; não há base para aceitar 184 como linha de base verificável. Nenhuma fonte, teste, backup, APK, API, banco, Agente, ParmaGestor ou App Malhas foi modificado nesta auditoria.
- **STATUS/ÚLTIMO PONTO:** 136 eventos atuais/110 casos visíveis passaram; a suíte pré-UI foi preservada byte a byte e ampliada por 2 testes. APK continua proibido até nova autorização explícita diante da correção documental da linha de base.

**Atualização de 26/11/2026, 11:00 -03:00 — artefato de testes liberado; suíte e análise aprovadas; divergência documental de quantidade impede gerar APK sem orientação:**

- **Ação autorizada, estritamente delimitada:** foi confirmado o caminho absoluto `E:\Jorginho\AppMotorista\AppMotorista\build\unit_test_assets`. O atributo Windows `ReadOnly` foi removido somente dessa pasta e de seus arquivos/subdiretórios; a verificação retornou zero itens `ReadOnly` remanescentes. Nenhuma outra pasta teve atributo alterado, nada foi apagado e o Flutter recriou normalmente o artefato de teste.
- **Suíte completa comprovada:** `flutter test --reporter silent --file-reporter json:...` terminou com evento JSON terminal `{"success":true,"type":"done","time":28209}` e sem eventos `error`. A nova cobertura `test/viagens/trip_state_controller_test.dart` também foi executada isoladamente com `2/2 All tests passed!`, comprovando isolamento por motorista e descarte de resposta fora de ordem. `flutter analyze` final: `No issues found! (ran in 3.4s)`.
- **Limite objetivo de comprovação:** o relatório JSON da suíte completa registrou `TEST_STARTS=136`, não 184. A contagem por declaração de testes no worktree atual é 109; alguns casos geram eventos adicionais durante a execução. Assim, embora todos os **136 testes efetivamente descobertos/executados** tenham passado, não é possível confirmar a alegação de “184 testes anteriores” a partir do código e da execução atuais. Não houve falha de teste, mas há divergência entre o requisito/histórico e a linha de base presente no workspace.
- **APK ainda não gerado por prudência:** em respeito à condição de gerar `1.0.0+3` somente após aprovação integral exigida, não foi iniciado build release enquanto a divergência 184 × 136 não for esclarecida. O APK `1.0.0+2` homologado e o backup preventivo permanecem intactos. Agente, API, bancos, ParmaGestor e App Malhas não foram alterados nem interrompidos.
- **STATUS/ÚLTIMO PONTO:** análise estática e todos os testes atualmente descobertos foram aprovados; falta somente decisão explícita sobre a divergência documental de contagem antes de gerar o APK release e seguir para a homologação física no Samsung S20.

**Atualização de 26/11/2026, 10:50 -03:00 — ambiente Flutter recuperado; análise aprovada; suíte bloqueada por atributo somente leitura em artefato de build:**

- **Causa do bloqueio anterior comprovada:** seis cadeias travadas, criadas pelas próprias tentativas locais de `dart format`, `flutter analyze` e `flutter --version`, ficaram aguardando a aquisição de `E:\src\Flutter\bin\cache\flutter.bat.lock`. O SDK está fora do workspace e o bootstrap precisa gravar no cache; a execução sandboxada não concluía essa etapa. O Dart SDK direto respondeu normalmente. Após encerrar exclusivamente aquelas cadeias identificadas e executar Flutter com acesso autorizado ao seu cache, `flutter --version` concluiu com código 0: Flutter `3.38.5`, Dart `3.10.4`, revisão `f6ff1529fd`.
- **Preservação e processos:** o worktree salvo foi conferido antes da intervenção; não houve reinício do Windows ou VS Code e nenhum processo do Agente foi encerrado. O daemon Flutter, Language Server, tooling daemon e DevTools do VS Code foram reiniciados de forma pontual, sem fechar a IDE ou alterar fontes. A árvore do Agente continua exclusiva e ativa (`CMD 19472` → `PowerShell 19260`). O backup preventivo e o APK `1.0.0+2` homologado permanecem intocados.
- **Formatação e análise:** os nove arquivos Flutter modificados/nova cobertura foram formatados com `dart format`. `flutter analyze` foi executado com êxito: `No issues found! (ran in 4.5s)`.
- **Impedimento novo, ainda sem alteração corretiva:** a execução de `flutter test` não iniciou a suíte porque o Flutter não conseguiu apagar `build\unit_test_assets`: `The flutter tool cannot access the file or directory.` A inspeção somente leitura comprovou que esse diretório de artefato reconstruível, criado em 25/11, e seus subdiretórios `fonts`/`shaders` têm atributo Windows `ReadOnly`; o ACL do usuário ainda possui `Modify` e não há processo de teste/Gradle do App Motorista que o retenha. Nenhum arquivo foi removido, nem o atributo foi alterado. É necessária autorização específica para remover o atributo `ReadOnly` e deixar o Flutter recriar somente esse artefato de build; depois disso, repetir analyze/testes e somente com aprovação gerar o APK `1.0.0+3`.
- **STATUS/ÚLTIMO PONTO:** a implementação reativa continua aguardando aprovação integral da suíte, geração do APK release e homologação física no Samsung S20. Não a considerar definitivamente aprovada antes dessas evidências.

**Atualização de 26/11/2026, 10:38 -03:00 — implementação local da propagação reativa concluída; validação Flutter/APK bloqueada por processos Dart externos:**

- **Implementação restrita ao App Motorista:** foi criado `lib/viagens/services/trip_state_controller.dart`, uma projeção observável em memória, escopada por `storageScope` (servidor), motorista e manifesto. O SQLite continua sendo a única fonte persistente da verdade: o controller somente relê/publica o manifesto afetado depois de `registerRead`, `finishAccepted`, `finishRejected` ou gravação de snapshot terem concluído sua transação local. Eventos concorrentes recebem token monotônico por manifesto, impedindo que uma leitura assíncrona antiga sobrescreva uma projeção mais recente; mudança de motorista não publica nem expõe estado do escopo anterior.
- **Fluxo reativo integrado:** `TripsService` publica o estado local confirmado depois da coleta, do ACK, de rejeição/conflito e de snapshots reconciliados. `OutboxSyncController` publica o mesmo manifesto somente após a transação de reconciliação. `TripsScreen`, `TripDetailScreen` e `StopScreen` observam a mesma projeção; itens continuam no controlador de coleta. Assim a cadeia itens → pedido → parada → viagem é derivada de ocorrências SQLite já confirmadas, sem depender de retorno de `Navigator`, temporizador, pull-to-refresh ou consulta HTTP para refletir uma coleta. O pull-to-refresh permanece complementar.
- **Cores e isolamento preservados por desenho:** a projeção usa as situações já existentes e as mesmas funções de cor/ordenação. Enquanto há outbox no manifesto, pedido/parada/viagem concluídos permanecem azuis; o ACK remove a pendência no SQLite e a publicação seguinte os torna amarelos. Rejeição e conflito republicam somente o manifesto alterado, sem afetar ocorrências alheias. Não foram reconstruídos scanner, outbox, persistência, GUIDs ou idempotência.
- **Arquivos alterados nesta implementação:** `pubspec.yaml` (versão preparada para `1.0.0+3`), `lib/main.dart`, `lib/app.dart`, `lib/viagens/services/trip_state_controller.dart`, `lib/viagens/services/trips_service.dart`, `lib/sync/services/outbox_sync_controller.dart`, `lib/viagens/screens/trips_screen.dart`, `trip_detail_screen.dart`, `stop_screen.dart` e o novo teste `test/viagens/trip_state_controller_test.dart` (isolamento de motorista e descarte de resposta fora de ordem). Não houve alteração de API, migration, estrutura de banco, Agente Motorista, ParmaGestor, App Malhas ou deploy.
- **Validação ainda não comprovada:** tentativas de `flutter --version`, `flutter analyze --no-pub` e da execução de testes não retornaram no terminal. Em leitura elevada, os quatro processos `dart.exe` existentes desde 07:54 -03 foram identificados como Language Server, tooling daemon, DevTools e daemon Flutter do VS Code (PIDs 20572, 20636, 20940 e 21244). Como pertencem ao ambiente de desenvolvimento e não ao Agente, não foram encerrados sem autorização específica. Portanto não é possível declarar `flutter analyze`, a suíte completa nem os 184 testes aprovados. Pelo mesmo motivo, **nenhum APK `1.0.0+3` foi gerado e o APK `1.0.0+2` homologado permanece intocado**. Antes da homologação física, é necessário liberar/reiniciar com segurança o ambiente Flutter/VS Code, executar analyze + suíte completa, gerar e conferir o APK release +3 e então instalar somente o novo artefato.
- **STATUS/ÚLTIMO PONTO:** a correção reativa está implementada localmente e aguarda validação automatizada, geração de APK e homologação física no Samsung S20. Não a considerar definitivamente aprovada antes dessas evidências. O backup preventivo `APP_MOTORISTA_PRE_UI_2026-11-26_102128` continua sendo o ponto de retorno verificável.

**Atualização de 26/11/2026, 10:21 -03:00 — backup preventivo pré-alteração visual criado e validado:**

- **Novo backup independente, sem sobrescrever o homologado anterior:** `E:\BACKUPS_APP_MOTORISTA\APP_MOTORISTA_PRE_UI_2026-11-26_102128\APP_MOTORISTA_FONTES_2026-11-26.rar`; 817.328 bytes; SHA-256 `B5936D0D238ACA31DF13B2377A55B3E867CE01002759819AEC0F5E5C67F781D2`. O teste WinRAR/RAR retornou código 0 e `Tudo OK`. O backup anterior de 25/11 (`APP_MOTORISTA_HOMOLOGADO_2026-11-25_142455`) foi preservado sem alteração.
- **Conteúdo preservado:** fontes, testes, documentação atual — inclusive este tutorial com as homologações físicas de 26/11 até a auditoria visual — e arquivos não versionados dos componentes `AgenteMotoristaGramDecor`, `ApiMotorista`, `ApiMotoristaNuvem` e `AppMotorista`. Foram excluídos somente artefatos reconstruíveis (build geral, caches Flutter/Gradle/Python, venvs, logs e SQLite ativo) e `ApiMotorista\.env`, por ser configuração sensível e não fonte. O teste da lista do RAR confirmou `AppMotorista\Documentacao\TUTORIAL_APP_MOTORISTA.md` e a ausência do `.env` sensível.
- **APK homologado separado:** `E:\BACKUPS_APP_MOTORISTA\APP_MOTORISTA_PRE_UI_2026-11-26_102128\APK_APP_MOTORISTA_1.0.0+2_HOMOLOGADO.apk`; 64.491.484 bytes; SHA-256 `028E02A64C0A74E030E2EA0D7F6C10C98EEF487E09A4E95C06DF068FFFABF4F3`, igual ao APK 1.0.0+2 homologado no S20.
- **Ponto de recuperação Git:** base `HEAD=9f699964a1b62b04cea349a03ce48ef4d11dd1a9`; `GIT_STATUS_APP_MOTORISTA.txt` preserva o status do escopo e `GIT_WORKTREE_PATCH_APP_MOTORISTA.patch` (293.837 bytes; SHA-256 `CA0F7E968A2DEEC2E4944E05946283973EAA2D8A072157981E062AE964391AC0`) preserva a diferença binária dos arquivos versionados. Os arquivos não rastreados são preservados no RAR; assim o ponto recupera tanto o Git quanto o worktree atual.
- **Integridade adicional:** `SHA256SUMS.txt` no mesmo diretório contém os hashes do RAR, APK e três artefatos Git. Para restaurar em caso de regressão: (1) não apagar a árvore atual; parar apenas processos que usem os arquivos após autorização; (2) conferir `Get-FileHash -Algorithm SHA256` contra `SHA256SUMS.txt`; (3) extrair o RAR em diretório novo e vazio; (4) comparar/aplicar o patch com `git apply --check GIT_WORKTREE_PATCH_APP_MOTORISTA.patch` e depois `git apply` somente na árvore de recuperação, se necessário; (5) usar o APK separado para reinstalação sobre o S20 sem limpar dados; (6) validar testes e iniciar o Agente normal somente após conferência humana. Nenhuma restauração foi executada nesta etapa.
- **Escopo preservado:** não foram modificados fontes funcionais, bancos, API, APK existente, Agente/BAT, ParmaGestor ou App Malhas. A alteração visual continua pendente de autorização.

**Atualização de 26/11/2026, 10:08 -03:00 — carga 779 logisticamente concluída; pendência de propagação visual Flutter identificada (somente auditoria/proposta):**

- **Conciliação logística final da carga 779 — comprovada por leitura:** PostgreSQL DigitalOcean possui 11 operações `ACEITA`, 11 `operation_guid` e 11 `occurrence_guid` distintos, todas `APPLIED`, uma tentativa, `ENTREGA_REGISTRADA`, `replay=false`, sem `PENDING`/`CLAIMED`. As confirmações derivadas são 1 na parada 2007/pedido 23386, 1 na parada 2008/pedido 23346 e 9 na parada 2009/pedido 23170. SQLite do Agente contém as mesmas 11 operações em `ACKED`, todas sem erro. Firebird possui as três combinações logísticas em `E` (1 + 1 + 9 ocorrências), pedidos/paradas concluídos, 11 operações de auditoria com o par técnico idempotente esperado (tentativa canônica `S` e resultado `N`, ambos `REPLAY='N'`), manifesto `L` e status comercial da carga `CARG_STATUS='A'` preservado. Não há pendência, duplicidade ou reaplicação logística.
- **Agente normal:** a única árvore BAT/PowerShell do Agente segue ativa; as últimas rodadas observadas, em intervalo aproximado de 30 s, concluíram `exit=0`, `SEM_ALTERACAO` e sem erros.
- **Sintoma visual físico:** depois da última coleta da carga 779, a tela de itens já mostrava os nove itens amarelos, mas o cartão do pedido/parada e, em seguida, a carga na tela superior ficaram cinza até pull-to-refresh cerca de 15 s depois. O requisito é atualizar essas telas imediatamente com o dado local já confirmado, sem temporizador ou nova consulta.
- **Causa arquitetural confirmada em fonte:** não existe uma projeção de UI única e observável para a viagem. `DeliveryScannerController` mantém cópias mutáveis de pedido/ocorrências; `StopScreen` mantém outra cópia em `_stop`; `TripDetailScreen` e `TripsScreen` mantêm `Future`/snapshots independentes. `DeliveryLocalStore.registerRead()` atualiza atomicamente SQLite (`local_occurrence`, outbox, pedido/parada derivados e sync da viagem), mas `TripsService.registerRead()` não emite `notifyListeners()` após essa mutação. A propagação atual depende de resultados de `Navigator` e de `_loadTrip()`/`_reload()` assíncronos; estes chamam `TripsService.get/list()`, que preferem HTTP quando não há outbox pendente. Portanto a tela superior pode renderizar um snapshot remoto ou `Future` anterior até a próxima recarga. A sincronização automática só notifica `OutboxSyncController` após reconciliação; ela não é um canal de alteração local imediato.
- **Hierarquia e fontes de estado mapeadas:** `TripsScreen` (lista/carga; `TripsService.list`, `FutureBuilder`) → `TripDetailScreen` (viagem/paradas; `TripsService.get`, `FutureBuilder`) → `StopScreen` (pedidos; `_stop`) → `OrderScreen` (itens; `DeliveryScannerController`). Persistência canônica local: `TripLocalStore`/`DeliveryLocalStore`/`OutboxLocalStore` no SQLite. Rede: `TripsRepository`. Sincronização: `OutboxSyncController`. As cores são derivadas em `delivery_progress.dart` de status `E`; o erro não está na regra de cor, mas na entrega tardia do snapshot correto à tela consumidora.
- **Impacto offline e outros pontos:** o mesmo risco existe em qualquer coleta offline, pois o SQLite muda antes do retorno à Nuvem; e após o ACK automático, pois a tela pode esperar a recarga dirigida pelo evento de sync. Também afeta pedido→parada→viagem e a lista de viagens, não apenas a carga 779. Os testes atuais cobrem navegação final, cores e evento de sync isoladamente, mas não cobrem a sequência física de coleta offline + retorno manual entre telas + atualização imediata de todos os ancestrais sem HTTP/pull-to-refresh.
- **Proposta de implementação futura — não executada:** introduzir uma única `TripStateController`/store observável, escopada por motorista/manifesto, cuja fonte seja o snapshot SQLite. Após cada transação local (`registerRead`, `finishAccepted`, `finishRejected`, snapshot remoto reconciliado), publicar somente o manifesto afetado em memória; as quatro telas observam essa projeção com `ListenableBuilder`/selector e derivam pedido, parada e carga diretamente das ocorrências. Resultados de `Navigator` ficam apenas para navegação/diálogos, não para transportar estado nem forçar HTTP. `OutboxSyncController` deve publicar o mesmo evento após reconciliação, fazendo o store reler apenas o manifesto local alterado. Assim a coleta offline atualiza imediatamente todos os ancestrais, o ACK troca azul→amarelo automaticamente, e a consulta remota continua apenas para sincronização/snapshot, não para corrigir a UI.
- **Arquivos envolvidos e testes necessários antes de implantar:** `lib/viagens/services/trips_service.dart`, `local/delivery_local_store.dart`, `local/trip_local_store.dart`, `services/delivery_scanner_controller.dart`, `screens/order_screen.dart`, `stop_screen.dart`, `trip_detail_screen.dart`, `trips_screen.dart`, `sync/services/outbox_sync_controller.dart`, `main.dart` e `app.dart`; adicionar testes de widget para propagação imediata itens→pedido→parada→carga offline, retorno manual e automático, ACK sem HTTP adicional, rejeição/conflito que desfaz projeção, persistência após reboot e ausência de regressão de cores/duplicidade. Não houve alteração de fonte, banco, API, APK, configuração, migration ou App Malhas; aguardar autorização antes de implementar.

**Atualização de 26/11/2026, 09:58 -03:00 — bloqueio físico de duplicidade offline homologado no Samsung S20:**

- **Prova física concluída:** com o S20 totalmente offline, uma etiqueta inédita da carga 779/parada 2009/pedido 23170 (Minas Chair Decor Ltda.) foi aceita e permaneceu aguardando sincronização. A releitura da etiqueta já coletada foi bloqueada no App com a mensagem `Todas as ocorrências desta etiqueta já foram recepcionadas no Pedido.` Os contadores visuais permaneceram em 2 entregues e 7 pendentes. Após restabelecer a Internet, a sincronização ocorreu automaticamente; os produtos 8901 e 1000842 foram visualmente conferidos como entregues, em amarelo.
- **Nova operação offline, comprovada em PostgreSQL:** `operation_guid=7c505d87-2939-40ff-bfda-43ee907fd0a7`; `occurrence_guid=88784e02-2d9d-4e8a-88a8-f1e7003dedb4`; código `C02317010008420130000`. Criada em `2026-11-26 12:56:05.547077+00` (09:56:05 -03) com `ACEITA/LEITURA_CONFIRMADA`; está `APPLIED`, tentativa 1, `returned_at=12:56:31.146612+00`, resultado `ACEITA/ENTREGA_REGISTRADA`, `replay=false`.
- **Agente e retorno automático:** o SQLite contém a mesma operação em `ACKED`, recebida/aplicada às 12:56:32Z e ACKed às 12:56:33Z, sem erro. O log da rodada normal de 09:56:33 -03 registra `ENTREGA_REGISTRADA`, `replay=0`, `pendentes_pedido=7`; as rodadas posteriores continuam saudáveis, sem erro. A única árvore normal do BAT/PowerShell permanece ativa.
- **Firebird e idempotência:** em leitura, carga 779 preserva manifesto `L` e status comercial `CARG_STATUS='A'`; pedido 23170/parada 2009 possui exatamente 2 ocorrências `E` e 7 `P`. A nova operação possui somente tentativa canônica `S` e resultado técnico `N`, ambas `ENTREGA_REGISTRADA`, `REPLAY='N'`. PostgreSQL contém exatamente duas operações, duas ocorrências e duas confirmações distintas para o pedido — as duas leituras legítimas. Não existe operação, entrega ou reaplicação adicional atribuível à releitura bloqueada.
- **Preservações:** GUIDs originais de operação/ocorrência/manifesto foram preservados nos três lados. Nenhuma fonte, configuração, banco, API, migration, APK ou App Malhas foi alterado; o Agente permanece em funcionamento normal.

**Atualização de 26/11/2026, 09:11 -03:00 — recuperação automática do Agente homologada; Agente permanece em execução:**

- **Inicialização normal autorizada:** o BAT `E:\Jorginho\AppMotorista\AgenteMotoristaGramDecor\INICIAR_AGENTE_MOTORISTA.bat` foi iniciado sem parâmetros de GUID/carga e sem retorno manual. Há uma única árvore exclusiva ativa: CMD/BAT PID 19472 e seu filho PowerShell PID 19260, executando o PS1 normal com intervalo de 30 s; nenhuma segunda instância ou Python residual foi observada.
- **Recuperação comprovada na primeira rodada:** às 09:09:34 -03, a rodada normal recebeu a operação pendente `B0DA680C-ACCA-416D-A9E3-BCC6A9F17ACF`, ocorrência `A87B3A31-755D-440E-8AFA-AD1D37AEFA24`, pedido 23170, e retornou `ACEITA/ENTREGA_REGISTRADA`, `replay=0`, `pendentes_pedido=8` e `pendentes_parada=8`. As rodadas seguintes de 09:10:07 e 09:10:39 concluíram sem erro, confirmando continuidade normal.
- **PostgreSQL DigitalOcean — somente leitura:** a mesma chave original passou de `PENDING` para `APPLIED`, com uma tentativa; `returned_at=2026-11-26 12:09:33.027478+00` (09:09:33 -03), resultado `ACEITA/ENTREGA_REGISTRADA`, `replay=false`. Há exatamente uma linha em `delivery_read_operation` e uma confirmação derivada para uma ocorrência distinta; não há duplicidade.
- **SQLite do Agente — somente leitura:** a operação está `ACKED`, recebida, aplicada e ACKed às `2026-11-26T12:09:34+00:00` (09:09:34 -03), sem `last_error`. O payload preserva literalmente `operation_guid`, `expected_occurrence_guid`, manifesto, parada e pedido originais; o resultado Firebird também devolve os mesmos GUIDs, com `replay=0`.
- **Firebird — somente leitura:** carga 779 mantém manifesto `L` e status comercial `CARG_STATUS='A'`. No pedido 23170/parada 2009 há exatamente uma ocorrência `E` e oito `P`. A auditoria da operação possui somente o par técnico idempotente esperado: tentativa 1 canônica `S` e tentativa 2 de resultado `N`, ambas `ENTREGA_REGISTRADA`, `REPLAY='N'`; não houve reaplicação logística.
- **Restrições preservadas:** nenhuma fonte, configuração, banco, migration, API, APK ou App Malhas foi alterado. O Agente deve permanecer em funcionamento até nova orientação.

**Atualização de 26/11/2026, 09:04 -03:00 — leitura online com Agente parado; auditoria read-only concluída:**

- **Coleta física relatada:** no Samsung S20, com Internet ligada e Agente Motorista completamente parado, foi lida etiqueta inédita da carga 779, parada 2009, pedido 23170, cliente Minas Chair Decor Ltda. O App exibiu `Leitura confirmada`; a etiqueta foi para o fim da fila com fundo amarelo.
- **PostgreSQL DigitalOcean — operação nova comprovada:** `operation_guid=b0da680c-acca-416d-a9e3-bcc6a9f17acf`; `occurrence_guid=a87b3a31-755d-440e-8afa-ad1d37aefa24`; manifesto `283ED7CA-C6BE-4216-87C6-0B8EDA37E289`, empresa 10, carga 779, parada 2009, pedido 23170. Criada em `2026-11-26 12:03:07.149959+00` (09:03:07 -03), com leitura `ACEITA`/`LEITURA_CONFIRMADA`.
- **Retorno deliberadamente não aplicado:** a mesma operação está `return_state='PENDING'`, `return_attempt_count=0`, sem `claimed_instance_guid`, `claim_expires_at`, `returned_at` ou resultado de retorno. Portanto não houve claim, ACK nem chamada de retorno Firebird nesta etapa.
- **Projeção derivada e idempotência:** `delivery_confirmation_projection` contém exatamente uma confirmação para a nova chave `(operation_guid, occurrence_guid)`, no mesmo horário da leitura; as contagens são 1 confirmação, 1 ocorrência distinta e 1 operação distinta. A projeção técnica possui nove ocorrências do pedido em `P`; a sobreposição derivada confirma uma entregue e oito pendentes. Não há duplicidade de operação, ocorrência ou confirmação.
- **Firebird e estado comercial preservados:** em transação somente leitura, o manifesto segue `L`, `TB_CARGA.CARG_STATUS='A'` e as nove ocorrências Firebird da parada 2009/pedido 23170 permanecem `P`. Isso confirma que a leitura na Nuvem não foi retornada ao Firebird enquanto o Agente está parado.
- **Agente permanece parado:** não existe processo CMD/BAT, PowerShell ou Python correspondente ao Agente Motorista GramDecor. Não reiniciar o Agente até autorização explícita. Nenhuma fonte, banco, configuração, API, migration, APK ou App Malhas foi alterado.

**Atualização de 26/11/2026, 09:00 -03:00 — Agente Motorista interrompido controladamente para homologação de recuperação:**

- **Pré-condições em leitura:** a última rodada do Agente terminou com êxito às 08:58:11 -03 e entrou em `WAIT` de 30 s; não havia retorno na rodada. PostgreSQL DigitalOcean, em transação `READ ONLY`/`ROLLBACK`, confirmou zero operações `PENDING` ou `CLAIMED` para a carga 779 e as duas já recebidas permanecem `APPLIED`, tentativa 1. SQLite do Agente: `integrity_check=ok`, 42 registros do inbox em `ACKED` e zero `pending_snapshot`.
- **Árvore encerrada com segurança, entre rodadas:** foram identificados exclusivamente o CMD/BAT PID 21452 (`INICIAR_AGENTE_MOTORISTA.bat`) e seu filho PowerShell PID 17452 (`INICIAR_AGENTE_MOTORISTA.ps1 -IntervalSeconds 30`). O PowerShell foi encerrado durante `WAIT`; em seguida, o CMD/BAT exclusivo foi encerrado para impedir que permanecesse em `pause`. Nenhum processo do VS Code, Flutter, Gradle, outro projeto ou serviço foi interrompido.
- **Parada completa e sem reinício automático:** após mais de um intervalo normal, não existe processo com linha de comando do BAT, PS1 ou Python do Agente. O log diário manteve como última alteração 08:58:11 -03 e sua última linha é `WAIT seconds=30`; nenhuma rodada nova foi registrada.
- **Dependências preservadas:** `https://motorista.parmatech.com.br/api/v1/health` respondeu HTTP 200 com `{"contrato":1,"servico":"api-motorista-nuvem","status":"ok"}`. Firebird, em transação somente leitura, confirmou que carga 779/parada 2009/pedido 23170 permanece com exatamente nove ocorrências `P`.
- **Próximo passo autorizado ao motorista:** com o Agente completamente parado, o usuário pode coletar uma etiqueta inédita no Samsung S20 com Internet ligada. Não reiniciar o Agente até nova autorização explícita. Nenhuma fonte, configuração, banco, migration, API, APK ou App Malhas foi alterado nesta etapa.

**Atualização de 26/11/2026, 08:43 -03:00 — homologação física offline no Samsung S20 e auditoria read-only concluídas:**

- **Prova física realizada:** APK `1.0.0+2` instalado sobre o aparelho; em modo avião, com Wi-Fi e dados desligados, foram coletadas duas etiquetas inéditas e concluídas duas paradas em azul. Após reinicialização completa ainda offline, sessão, viagem e primeira coleta permaneceram preservadas; a segunda coleta offline também foi concluída. Às 08:35 ambas aguardavam sincronização; com a Internet restabelecida, às 08:36 ambas passaram automaticamente para amarelo, sem ação manual.
- **Carga/manifesto e clientes, confirmados por Firebird read-only:** empresa 10, carga **779**, manifesto `283ED7CA-C6BE-4216-87C6-0B8EDA37E289`, liberado (`L`) e com status comercial `TB_CARGA.CARG_STATUS='A'` preservado. Rodrigo Moreira, Ubá/MG: parada 2007, pedido 23386. Edson Gaspar de Almeida, São Geraldo/MG: parada 2008, pedido 23346.
- **Operação 1 — conciliação comprovada:** `operation_guid=0eeac139-52ec-46ca-bb43-2f79cbfe29a0`; `occurrence_guid=cf23db55-ceb0-4126-818d-0b8d33945013`. PostgreSQL DigitalOcean, em `BEGIN TRANSACTION READ ONLY`/`ROLLBACK`: leitura criada em 08:36:13 -03, `APPLIED`, uma tentativa, `returned_at=08:36:35.396562 -03`, retorno `ACEITA/ENTREGA_REGISTRADA`, `replay=false`. SQLite do Agente: recebida 11:36:36Z (08:36:36 -03), aplicada e ACKed 11:36:37Z (08:36:37 -03), sem erro. Firebird: ocorrência/parada/pedido `E`; auditoria canônica de tentativa 1 `S` e registro de resultado tentativa 2 `N`, ambos `ENTREGA_REGISTRADA`, `REPLAY='N'`, carimbados 08:36:37.066 -03.
- **Operação 2 — conciliação comprovada:** `operation_guid=c4a31cac-be25-4713-adba-2d8ec0076dde`; `occurrence_guid=6f3ad559-0aac-4917-8949-078279ef80b0`. PostgreSQL DigitalOcean: leitura criada em 08:36:13 -03, `APPLIED`, uma tentativa, `returned_at=08:36:35.600490 -03`, retorno `ACEITA/ENTREGA_REGISTRADA`, `replay=false`. SQLite: recebida, aplicada e ACKed em 11:36:37Z (08:36:37 -03), sem erro. Firebird: ocorrência/parada/pedido `E`; tentativa 1 `S` e resultado tentativa 2 `N`, ambos `ENTREGA_REGISTRADA`, `REPLAY='N'`, 08:36:37.294 -03.
- **Idempotência e pendência:** a consulta PostgreSQL da carga 779 devolveu exatamente essas duas linhas aceitas, uma por `operation_guid`, ambas `APPLIED`; a auditoria Firebird mostra somente o par técnico esperado por operação, com `REPLAY='N'`. Não há evidência de duplicidade ou reaplicação logística. A terceira parada permanece pendente: parada 2009, cliente Minas Chair Decor Ltda., pedido 23170, nove ocorrências `P`, parada/pedido `P`; não há terceira operação recebida para a carga 779 na consulta PostgreSQL.
- **Continuidade do Agente:** o log `agente-manifestos-20261126.log` registrou o retorno das duas operações às 08:36:37, sem erros, e continuou com rodadas `SEM_ALTERACAO` bem-sucedidas a cada ~30 s até 08:43. Nenhum Agente/BAT foi reiniciado ou interrompido; nenhuma operação foi reenviada.
- **Escopo desta auditoria:** somente leitura em SQLite/log local, Firebird (transação somente leitura com rollback) e PostgreSQL DigitalOcean (transação `READ ONLY` com `ROLLBACK`). Não foram alterados fontes, bancos, API, migrations, deploy, APK, configurações ou App Malhas. Aguardar autorização para a próxima etapa.

**Encerramento de 25/11/2026, 16:35 -03:00 — consolidação documental; retomada definida para 26/11/2026:**

- **Homologação funcional online concluída:** empresa 10/GramDecor operou publicação automática Firebird → Nuvem e retorno automático Nuvem → ParmaGestor, sem carga/GUID manual. A carga 778 foi publicada automaticamente; as cargas 776, 777 e 778 ficaram conciliadas com **14 entregas aplicadas e 14 retornos confirmados**. Firebird, SQLite do Agente e PostgreSQL foram auditados: 776 = 4/4, 777 = 7/7, 778 = 3/3; GUIDs individuais conferidos sem divergência, máximo de uma tentativa, operações canônicas Firebird `ENTREGA_REGISTRADA`/`REPLAY=N`, nenhuma operação pendente ou reivindicada nessas cargas. `CARG_STATUS` comercial foi preservado.
- **Correções e preservações homologadas:** a projeção de cliente passou a usar `COALESCE(NULLIF(TRIM(CLI_FANTASIA_APELIDO), ''), CLI_RSOCIAL_NOME)`, corrigindo o caso de fantasia vazia sem alterar cadastro, entrega, GUID, hash, revisão ou idempotência. O mecanismo de publicação/revisão, lease/fencing, outbox SQLite, retorno canônico e regras logísticas permanecem preservados.
- **Backup homologado:** RAR5 AES-256 validado em `E:\BACKUPS_APP_MOTORISTA\APP_MOTORISTA_HOMOLOGADO_2026-11-25_142455\APP_MOTORISTA_HOMOLOGADO_2026-11-25.rar`; tamanho 170.522.638 bytes; SHA-256 `20231991F8DFBFCB578AEDB3586676A65DB12D77101BB51CE31271F0509B50F4`; teste WinRAR concluído com código 0. O backup não foi modificado posteriormente.
- **Segurança da API Nuvem:** autorização persistente Agente × empresa foi implementada apenas localmente, com default-deny em claim/ACK, isolamento tenant/empresa e **28/28 testes Python aprovados**. Migration e deploy continuam proibidos/pendentes; falta validação em PostgreSQL isolado antes de qualquer autorização de implantação.
- **Offline — diagnóstico e implementação:** a falha física anterior revelou snapshot não baixado e possível invisibilidade de sessão/cache legados por escopo. Foram implementados pré-download automático de viagens, snapshot transacional por manifesto, indicador de disponibilidade offline, recuperação segura da sessão criptografada exclusiva do endpoint GramDecor e retomada da outbox após resposta real da API. `flutter analyze` aprovou sem issues; `flutter test -r json` aprovou **184 testes**, `TEST_EXIT=0`. Isso comprova a lógica local, mas **não substitui a homologação física offline**.
- **Novo APK pronto, ainda não instalado:** `E:\Jorginho\AppMotorista\AppMotorista\build\app\outputs\flutter-apk\app-release.apk`; versão `1.0.0+2` (`versionCode=2`), pacote `br.com.parmasoft.app_motorista`, compilado em 25/11/2026 16:28:47 -03:00, 64.491.484 bytes, SHA-256 `028E02A64C0A74E030E2EA0D7F6C10C98EEF487E09A4E95C06DF068FFFABF4F3`. Assinatura verificada: `C=US, O=Android, CN=Android Debug`, SHA-256 do certificado `1a58367bccab491a3b756b818bdb0ca9eb3c2934ecd1171c930993fd7f80f7f0`.
- **PONTO EXATO PARA RETOMADA — 26/11/2026:** (1) instalar o APK sobre a versão existente no Samsung S20, sem desinstalar/limpar dados; (2) abrir com internet e confirmar pré-download das viagens; (3) homologar modo avião; (4) testar coleta, duplicidade, fechamento/reabertura e reinicialização do aparelho; (5) restaurar Internet e confirmar sincronização automática até o ParmaGestor; (6) validar reinicialização do Agente; (7) validar segurança da API em PostgreSQL isolado antes de deploy; (8) preparar demonstração à GramDecor.
- **STATUS/ÚLTIMO PONTO:** funcionamento offline é requisito obrigatório para liberação operacional. O APK está pronto, porém a instalação e a homologação física offline no S20 **ainda não ocorreram** e não podem ser consideradas concluídas. Nenhuma alteração, deploy, migration, compilação, interrupção do Agente/BAT ou ação no App Malhas foi realizada neste encerramento.

**Atualização de 25/11/2026, 16:29 -03:00 — validação integral e APK de homologação offline gerado; aguardando instalação física:**

- **Processos auditados, sem interrupção indevida:** Java `13596` é o Gradle Server do VS Code; Dart `22108` é o Language Server, `19972` o tooling daemon, `20856` DevTools e `10992` o daemon Flutter. Todos foram iniciados pelo VS Code/Flutter IDE, não possuem linha de comando de build/teste do App Motorista e permaneceram ativos. Somente artefatos/processos iniciados pelos builds desta etapa foram encerrados quando necessários; Agente/BAT não foram tocados.
- **Falha transitória de testes resolvida sem dados funcionais:** Flutter encontrou colisão em `build/native_assets/windows/sqlite3.dll`. Após conferir que era exclusivamente artefato reconstruível de teste, foi removido apenas esse diretório; nenhum SQLite do aplicativo, APK homologado, backup, banco externo ou dado do motorista foi alterado.
- **Validação final:** `flutter analyze` retornou `No issues found`; `flutter test -r json` terminou com `{"success":true,"type":"done"}` e `TEST_EXIT=0`, com **184 testes aprovados**. A cobertura preserva regressões de coleta offline, bloqueio de duplicidade, persistência/reabertura da outbox, replay idempotente, recuperação de `sending`, UUID/payload V2, GUID canônico, snapshots e estados de pedido/parada/carga. Os novos testes cobrem pré-download e a recuperação segura de sessão legada.
- **Isolamento e sessão:** a compatibilidade de sessão é restrita literalmente ao endpoint canônico `https://motorista.parmatech.com.br`; somente lê a chave criptografada legada se a chave isolada estiver vazia, grava a sessão recuperada no escopo atual e apaga ambas em logout explícito. Não há senha, associação automática de SQLite legados, cruzamento de endpoint/motorista ou descarte de outbox/coletas pendentes.
- **APK novo, não instalado:** `E:\Jorginho\AppMotorista\AppMotorista\build\app\outputs\flutter-apk\app-release.apk`, compilado às **16:28:47 -03:00**, 64.491.484 bytes, SHA-256 `028E02A64C0A74E030E2EA0D7F6C10C98EEF487E09A4E95C06DF068FFFABF4F3`. `aapt` confirmou pacote `br.com.parmasoft.app_motorista`, `versionName=1.0.0`, `versionCode=2`; `apksigner verify --print-certs` confirmou certificado `C=US, O=Android, CN=Android Debug`, SHA-256 `1a58367bccab491a3b756b818bdb0ca9eb3c2934ecd1171c930993fd7f80f7f0`, compatível com o modelo de assinatura do release homologado. O build usou os fontes que contêm pré-download, estados visuais, sessão compatível e sonda de reconexão; seu hash/tamanho diferem do APK anterior. Nenhuma instalação ou teste físico foi executado.
- **STATUS/ÚLTIMO PONTO:** correção offline validada localmente e APK `1.0.0+2` pronto para atualização do Samsung S20. Próxima etapa, somente mediante autorização: instalar preservando dados, abrir online até todos os cartões mostrarem `Disponível offline`, ativar modo avião, abrir/fechar/reabrir, coletar etiqueta inédita, validar duplicidade, reiniciar o aparelho e restaurar conectividade para reconciliação. Não fazer logout explícito durante a prova offline.

**Atualização de 25/11/2026, 16:20 -03:00 — correção offline implementada localmente; APK ainda pendente de build:**

- **Implementado no Flutter, sem tocar no Agente, Firebird, PostgreSQL, API Nuvem, App Malhas ou no APK instalado:** a lista online inicia o download em segundo plano do detalhe completo de cada viagem retornada para o motorista. Cada manifesto é persistido por `TripLocalStore.replaceSnapshot()` em uma única transação SQLite; uma falha preserva o último snapshot válido. A lista passou a exibir discretamente `Disponível offline`, `Aguardando download` ou `Falha no download`, calculando disponibilidade somente a partir do snapshot local completo do motorista/manifesto.
- **Sessão e isolamento:** a sessão continua em `flutter_secure_storage`, sem senha. Para o único endpoint canônico de homologação (`https://motorista.parmatech.com.br`), a chave isolada atual pode recuperar uma sessão legada criptografada e a grava na chave atual; logout explícito apaga as duas chaves. Nenhum outro endpoint usa essa compatibilidade. Não foi criada migração/cópia automática de bancos legados: dados SQLite existentes permanecem inalterados e isolados por endpoint/motorista.
- **Retomada automática:** quando houver pendência na outbox em retry, uma sonda do endpoint `/api/v1/health` (não a simples presença de Wi-Fi) acorda o retry quando a API volta a responder. A execução ainda é serializada por `OutboxSyncController`; UUID, payload V2, GUID de ocorrência, retry/backoff, replay e idempotência não foram modificados.
- **Validação observável:** `flutter analyze` concluiu com `No issues found`. Os testes direcionados de pré-download, snapshot, sessão legada e outbox terminaram em `All tests passed` (`TARGETED_TEST_OK`). A execução da suíte completa percorreu os testes até os cenários offline finais sem erro exibido, mas a saída consolidada de encerramento não foi devolvida pelo terminal; portanto não registrar como aprovação integral até repetição confirmada.
- **APK:** dois builds release locais foram iniciados com os defines de homologação, mas processos Gradle/Dart antigos, externos a esta etapa, impediram a finalização e o artefato anterior não foi substituído. Os processos iniciados por estes builds foram encerrados; os processos antigos não foram tocados. O APK atual continua sendo o homologado anterior (`24/11/2026 16:22:59`, 64.491.244 bytes, SHA-256 `98232FE073DFBB6B9EE6E47367F73A14845FB9CA9F29A60BEF658A255BBB8031`) e **não deve ser instalado como se contivesse a correção**.
- **Arquivos desta etapa:** `lib/main.dart`, `lib/core/config/app_config.dart`, `lib/storage/app_database.dart`, `lib/storage/fallback_session_storage.dart`, `lib/viagens/models/trip_summary.dart`, `lib/viagens/local/trip_local_store.dart`, `lib/viagens/services/trips_service.dart`, `lib/viagens/screens/trips_screen.dart`, `lib/sync/local/outbox_local_store.dart`, `lib/sync/services/outbox_sync_controller.dart`, testes SQLite/sessão/offline e este tutorial.
- **STATUS/ÚLTIMO PONTO:** a correção está preparada e analisada localmente, mas o novo APK e a homologação física no S20 continuam pendentes. Antes de instalar: liberar/identificar os processos Gradle/Dart antigos, repetir `flutter test`, gerar um APK novo, conferir tamanho/SHA-256 e só então executar o roteiro em modo avião. Aguardar autorização antes de instalar no S20 ou iniciar qualquer operação real.

**Atualização de 25/11/2026, 15:35 -03:00 — incidente físico offline no Samsung S20, auditoria investigativa somente leitura:**

- **Falha observada:** em modo avião, ao tocar a carga, o S20 exibiu `Viagem indisponível. Sem conexão — esta viagem precisa ser baixada antes de ser utilizada offline.` Após sair do app e tentar autenticar novamente, exibiu `Sem conexão com o servidor. Verifique sua internet.` Nenhum dado local, SQLite, outbox, API, Firebird, Nuvem, Agente ou APK foi alterado nesta investigação.
- **Evidência histórica corrigida:** não foi localizada evidência documental nem no Git de uma homologação física offline completa do S20. Pelo contrário, `ESTADO_ATUAL.md`, `DIARIO_TECNICO.md`, `ULTIMO_PONTO.md` e o tutorial anterior registravam explicitamente que offline possuía testes automatizados, mas modo avião, reinício físico e retorno de rede no aparelho ainda estavam pendentes. As leituras comprovadas das cargas 776/777/778 foram homologações online ponta a ponta; elas não comprovam o modo avião. O Git possui somente o commit-base de setembro; as evoluções posteriores do Flutter estão no worktree sujo, portanto não oferece uma sequência confiável de commits para afirmar outra homologação física.
- **Causa direta da primeira mensagem — confirmada no código:** `TripsService.get()` só grava `local_trip`/paradas/pedidos/ocorrências após obter com sucesso o **detalhe** remoto e concluir `TripLocalStore.replaceSnapshot()` (`trips_service.dart`). A lista de cargas não grava o detalhe. Em modo avião, a mesma função consulta o SQLite; se não encontrar a chave `(driver_guid, manifest_guid)`, lança exatamente `OfflineTripUnavailableException` com a mensagem vista. Logo, visualizar a carga na lista online não é suficiente; é indispensável que a tela do detalhe tenha terminado de abrir online e a transação SQLite tenha sido concluída.
- **Regressão provável e prioritária — fortemente sustentada, ainda sem inspeção do S20:** a alteração recente de configuração administrativa introduziu escopo por endpoint. Antes, o cache era `app_motorista.db` e a sessão de homologação usava `motorista_homologacao_session_v1`; agora `main.dart` abre `app_motorista_<storageScope>.db` e `AppConfig.sessionStorageKey` acrescenta `_<storageScope>`. Não existe migration/leitura de compatibilidade do banco ou da chave legados. Assim, após instalar APK que contém essa alteração, snapshots e sessão anteriores podem continuar fisicamente preservados, mas ficam invisíveis para o novo escopo. Isso explica conjuntamente uma viagem não encontrada no cache e o retorno ao login sem internet. A confirmação final requer apenas leitura autorizada do armazenamento do aparelho; ela não foi feita.
- **Sessão e encerramento:** o fechamento normal do app não chama `logout`; `SessionController.restore()` preserva sessão vencida se a renovação falhar por comunicação. Login novo naturalmente exige rede e não deve armazenar senha. O logout explícito limpa somente a chave de sessão do escopo atual, não executa `deleteDatabase`. Também não há limpeza do SQLite por perda de conexão. `replaceSnapshot()` apaga/substitui somente o mesmo manifesto dentro de uma transação; falha durante a gravação reverte ao snapshot anterior. Portanto o problema não aponta para exclusão automática durante modo avião, mas para inexistência do snapshot no escopo atualmente aberto ou para a sessão legada não migrada.
- **V2/projeção/idempotência:** `occurrence_guid` V2, projeção Nuvem e correções canônicas não participam da escolha nem da abertura do SQLite offline. A outbox persiste `operation_guid`, `occurrence_guid` e JSON original; não será recriada, apagada ou alterada na correção proposta.
- **Proposta objetiva para correção definitiva (NÃO implementada):**
  1. Criar migração local única e não destrutiva do armazenamento legado para o escopo do endpoint canônico GramDecor: copiar snapshot/outbox por transação somente se o SQLite novo estiver vazio, validar schema/integridade e manter a cópia legada intacta até validação posterior. Nunca migrar cache legado para endpoint diferente.
  2. Migrar a sessão legada de homologação apenas quando o endpoint ativo for exatamente o canônico; gravar primeiro na chave nova e manter segurança `flutter_secure_storage`, sem senha, token em log ou acesso entre endpoints.
  3. Ao listar viagens online, baixar automaticamente e em segundo plano o detalhe de todas as viagens pendentes atribuídas ao motorista, com commit atômico por manifesto. Falha de uma viagem não pode apagar nem bloquear snapshots já completos.
  4. Exibir na lista o estado **Disponível offline** somente quando existir snapshot completo e válido para o motorista/manifesto; manter **Aguardando sincronização** para outbox pendente.
  5. Preservar logout explícito como encerramento de sessão; advertir se houver pendências. Fechamento/reinício do app não deve limpar sessão, cache ou outbox. Acrescentar monitor de conectividade apenas para acordar a outbox quando houver rede, mantendo retry/backoff e replay existentes.
  6. Cobrir migration legada, sessão sem rede, pré-download, cache por endpoint, reapertura/reboot simulado, operação pendente e replay idempotente; depois homologar no S20 antes de qualquer produção.
- **STATUS/ÚLTIMO PONTO:** a falha física demonstrou que o requisito operacional offline não pode ser considerado homologado. A principal correção necessária é compatibilizar/migrar armazenamento legado e garantir pré-download verificável do detalhe; nenhuma implementação foi iniciada. Aguardar autorização antes de alterar fontes, gerar APK ou realizar leitura do armazenamento do S20.

**Atualização de 25/11/2026, 15:22 -03:00 — auditoria offline do Flutter, somente leitura:**

- **Escopo preservado:** foram lidos exclusivamente fontes/testes do Flutter e este documento. Não houve alteração de código, geração de APK, execução do app/testes, modificação de banco, acesso à DigitalOcean, interrupção do BAT/Agente ou alteração no App Malhas. A implementação de segurança da API Nuvem permanece apenas preparada localmente, sem deploy ou migration aplicada.
- **Evidência de base:** `pubspec.yaml` usa `sqflite`; `AppDatabase` mantém SQLite versionado com `local_trip`, `local_stop`, `local_order`, `local_occurrence` e `outbox_operation`. O documento já registra `flutter analyze` sem issues e **105 testes Flutter aprovados** no release homologado (`app-release.apk`, SHA-256 `98232FE073DFBB6B9EE6E47367F73A14845FB9CA9F29A60BEF658A255BBB8031`). Nesta auditoria somente leitura esses testes não foram reexecutados.

| Requisito | Classificação | Evidência e limite |
|---|---|---|
| 1. Abrir viagens sincronizadas sem internet | **IMPLEMENTADO E COMPROVADO POR TESTES.** | `TripsService` usa `TripLocalStore` após falha de comunicação; `trips_offline_service_test.dart` cobre lista/detalhe salvos e `offline_navigation_widget_test.dart` navega até ocorrências. |
| 2. Clientes, pedidos, produtos e etiquetas locais | **PARCIALMENTE IMPLEMENTADO.** | Cliente, endereço/cidade, pedidos, ocorrência, código, quantidade, tipo, rolo e `product_id` ficam no SQLite. Não há catálogo/nome de produto: a tela exibe `Produto {id}`. |
| 3. Coletar etiquetas sem conexão | **IMPLEMENTADO E COMPROVADO POR TESTES.** | `DeliveryLocalStore.registerRead` atualiza a ocorrência e cria a outbox na mesma transação; retorno local é `ACEITA_LOCAL`. |
| 4. Bloquear duplicidade offline | **IMPLEMENTADO E COMPROVADO POR TESTES.** | Consome somente ocorrências `P`; bloqueia excesso de código C e releitura de rolo R. Testes cobrem `MULTIPLICIDADE_ESGOTADA`, `ROLO_JA_RECEPCIONADO` e escopo errado. |
| 5. Persistir coletas pendentes no SQLite | **IMPLEMENTADO E COMPROVADO POR TESTES.** | Outbox guarda UUID, payload V2, ocorrência, estado, tentativas e erro; teste fecha/reabre mantendo UUID/payload. |
| 6. Fechar/reabrir o app offline | **IMPLEMENTADO E COMPROVADO POR TESTES.** | Snapshot/outbox são reabertos em SQLite e `sending` interrompido volta a `pending`; ainda falta homologação física no Android. |
| 7. Reiniciar o celular sem perder coletas | **IMPLEMENTADO, MAS AINDA NÃO HOMOLOGADO.** | Persistência SQLite e recuperação após reabertura suportam o caso, porém não há evidência física de reboot no S20. |
| 8. Autenticação/sessão sem internet | **IMPLEMENTADO, MAS AINDA NÃO HOMOLOGADO.** | Sessão fica em `flutter_secure_storage`; em refresh vencido com falha de comunicação ela é preservada e o app permanece autenticado. Login novo exige internet; persistência real do secure storage no S20 não foi testada neste ciclo. |
| 9. Sincronização ao voltar a conexão | **PARCIALMENTE IMPLEMENTADO.** | A outbox tenta ao iniciar, ao criar coleta, no retorno ao primeiro plano e por retry/backoff. Não há listener de conectividade para disparar imediatamente no exato retorno da rede; poderá ocorrer na próxima tentativa ou ao reabrir/resumir o app. |
| 10. Recuperar falhas de sincronização | **IMPLEMENTADO E COMPROVADO POR TESTES.** | Falha temporária vira `retry`; resposta perdida reenvia o mesmo UUID/payload; `sending` interrompido é recuperado; 4xx terminal reverte a mutação local com estado explícito. |
| 11. Preservar GUIDs/idempotência | **IMPLEMENTADO E COMPROVADO POR TESTES.** | UUID/payload V2 são persistidos uma vez, chave primária impede duplicata e replay usa a mesma identidade; GUID de ocorrência é comparado canonicamente. |
| 12. Atualizar viagem/parada/pedido offline | **IMPLEMENTADO E COMPROVADO POR TESTES.** | A transação local altera ocorrência, pedido/parada e resumo; teste cobre conclusão parcial/total e estados após reabertura. |
| 13. Indicar coletas aguardando sincronização | **IMPLEMENTADO E COMPROVADO POR TESTES.** | Há banner `Sem conexão — usando dados salvos`, retorno `Aguardando sincronização`, sinal azul em carga/parada/pedido e tela de diagnóstico da outbox. |

- **APK do S20:** pela evidência registrada do release de homologação e pelos fontes que o originaram, o APK instalado **deve permitir o teste físico completo em modo avião**, desde que a viagem pendente seja aberta online antes de desconectar e a sessão já exista. Isso ainda não é prova física de que o binário atualmente instalado é exatamente o SHA registrado, nem substitui a homologação de reboot/rede.
- **Risco funcional principal:** o aplicativo não baixa uma viagem inédita offline e não faz login novo offline. A recuperação de conectividade não é instantânea por evento de rede; para forçar tentativa segura, retornar o app ao primeiro plano ou aguardar o retry. Não limpar dados do aplicativo, não trocar endpoint e não desinstalar enquanto houver pendências.
- **Roteiro físico proposto, aguardando autorização:** usar carga/manifesto de teste ainda pendente; online, confirmar sessão e abrir o detalhe para gravar snapshot; ativar modo avião; fechar/abrir o app e conferir banner + cliente/pedidos/etiquetas; coletar uma etiqueta, confirmar `Aguardando sincronização` e bloquear a repetição; fechar/abrir novamente e reiniciar o S20 sem limpar dados; desligar modo avião, trazer o app ao primeiro plano e aguardar sincronização; confirmar que a pendência some e que a mesma operação não foi duplicada. Usar sempre etiquetas inéditas e registrar carga, ocorrência e `operation_guid` para a reconciliação posterior.
- **ÚLTIMO PONTO:** offline lógico está implementado; falta homologação física controlada no Samsung S20, especialmente reboot, secure storage Android e retomada real da rede. Aguardar autorização antes de qualquer teste operacional.

**Atualização de 25/11/2026, 15:10 -03:00 — autorização persistente Agente × empresa implementada somente no workspace local (não implantada):**

- **STATUS:** a proteção foi implementada e testada exclusivamente em ambiente local descartável. Não houve deploy, migration na DigitalOcean, modificação de PostgreSQL/Firebird real, reinício de serviço, interrupção do BAT/Agente, APK ou alteração no App Malhas. O backup homologado de 14:39 permanece imutável.
- **Modelo persistente/default deny:** a migration `ApiMotoristaNuvem/migrations/versions/20261125_0005_agent_company_access.py` cria `agent_credential_company_access`, com chave `(agent_credential_id, company_id)`, FK para a credencial técnica, flag `active` e data de criação. Não existir vínculo ativo significa não haver escopo autorizado. A credencial autentica o tenant; o vínculo pertence àquela credencial, portanto não pode conceder empresa de outro tenant.
- **Claim/ACK protegidos no servidor:** `claim_delivery_returns` agora exige pelo menos um vínculo ativo e cruza `delivery_read_operation` + `manifest_projection` + vínculo ativo da credencial. A empresa vem da projeção de manifesto já persistida na Nuvem, nunca de um identificador enviado pelo Agente. Sem vínculo, claim/ACK retornam `EMPRESA_NAO_AUTORIZADA` (403) e não criam lease/tentativa. Com escopo, mas para operação de outra empresa, ACK retorna `OPERACAO_NAO_ENCONTRADA` (404), sem alterar seu estado; claim não a devolve. Lease, fencing, GUID, hash, contagem de tentativas, retorno terminal e replay idempotente permanecem inalterados.
- **Demais endpoints do Agente auditados/endurecidos:** publicação de snapshot verifica que `origem.empresa` está no escopo persistido; sincronização de identidades de motorista verifica todas as empresas antes de qualquer escrita, evitando aplicação parcial. O acquire inicial de lease não contém empresa e não possui projeção para manifesto ainda inédito; ele permanece isolado por tenant e fencing. Um Agente sem escopo pode, no pior caso, obter lease temporário de manifesto desconhecido, mas não consegue publicar nem gravar projeções; esse limite deve ser considerado ao evoluir futuramente o contrato de acquire para uma identidade de manifesto verificável pelo servidor.
- **Compatibilidade:** os contratos HTTP do Agente atual não mudaram: claim continua recebendo somente instância/operação opcional e ACK continua recebendo a operação já reivindicada. Depois de provisionado o vínculo da credencial GramDecor à empresa 10, a publicação e o retorno automáticos continuam sem carga, manifesto ou GUID manual. As 14 entregas homologadas em `APPLIED` não são mutadas pela migration nem pela nova lógica.
- **Testes locais observáveis:** `python -m compileall -q app tests migrations` concluiu sem erro; `python -m unittest tests.test_api tests.test_canonical tests.test_events tests.test_mobile_login -v` concluiu **28/28**. Cobertos: empresa autorizada, claim e ACK de empresa fora do escopo, credencial sem empresa (negação por padrão), separação entre tenants, replay idempotente de ACK, compatibilidade do contrato normal, hash/revisão/fencing existentes, leituras V2 e sincronização de identidades. A integração PostgreSQL permanece preparada com o novo vínculo na fixture, mas não foi executada porque não há PostgreSQL descartável configurado nesta máquina.
- **Implantação futura segura (NÃO executar sem autorização):** (1) em SSH, registrar a revisão atual com `alembic current` e, em transação somente leitura, localizar uma única credencial ativa `GRAMDECOR`/`agent_guid`; (2) aplicar `alembic upgrade 20261125_0005`; (3) ainda antes de recarregar a API, inserir/ativar exatamente o vínculo da credencial conferida para empresa `10` usando `INSERT ... ON CONFLICT ... DO UPDATE`; (4) conferir em leitura que há uma única linha ativa; (5) publicar o código e reiniciar apenas o serviço da API; (6) executar smoke tests de snapshot/claim/ACK e monitorar. Durante eventual intervalo sem vínculo, operações pendentes permanecem pendentes; não são reivindicadas nem perdidas. Rollback: retornar o binário anterior antes de `alembic downgrade 20260925_0004`; a queda da tabela remove somente os escopos novos, jamais entregas, snapshots ou confirmações. Reaplicação exige provisionar novamente o vínculo.
- **SQL de provisionamento futuro, após conferência humana da credencial (NÃO executado):**

```sql
BEGIN;
-- Conferir antes que esta consulta devolve exatamente uma credencial ativa.
SELECT ac.id, ac.agent_guid, t.external_id AS tenant, ac.active
FROM agent_credential ac
JOIN tenant t ON t.id = ac.tenant_id
WHERE t.external_id = 'GRAMDECOR'
  AND ac.agent_guid = '<AGENT_GUID_GRAMDECOR_CONFERIDO>'
  AND ac.active IS TRUE;

INSERT INTO agent_credential_company_access
    (agent_credential_id, company_id, active)
SELECT ac.id, 10, TRUE
FROM agent_credential ac
JOIN tenant t ON t.id = ac.tenant_id
WHERE t.external_id = 'GRAMDECOR'
  AND ac.agent_guid = '<AGENT_GUID_GRAMDECOR_CONFERIDO>'
  AND ac.active IS TRUE
ON CONFLICT (agent_credential_id, company_id)
DO UPDATE SET active = EXCLUDED.active
RETURNING agent_credential_id, company_id, active, created_at;

-- Confirmar uma e somente uma linha ativa antes do COMMIT.
COMMIT;
```

- **Arquivos locais alterados:** `ApiMotoristaNuvem/app/tables.py`, `app/service.py`, `app/provisioning.py`, `tests/test_api.py`, `tests/test_mobile_login.py`, `tests/test_postgresql_integration.py` e a migration `20261125_0005_agent_company_access.py`; nenhum arquivo do Agente ativo foi alterado.
- **ÚLTIMO PONTO:** endurecimento de autorização preparado e validado localmente; nenhuma mudança está em funcionamento na Nuvem. Aguardar autorização antes de aplicar migration, criar o vínculo GramDecor/empresa 10, implantar a API ou reiniciar serviços.

**Atualização de 25/11/2026, 14:39 -03:00 — backup compacto homologado executado:**

- **Arquivo criado:** `E:\BACKUPS_APP_MOTORISTA\APP_MOTORISTA_HOMOLOGADO_2026-11-25_142455\APP_MOTORISTA_HOMOLOGADO_2026-11-25.rar`, RAR5 com compressão máxima, AES-256 e nomes de arquivos cifrados. A senha foi informada diretamente no WinRAR e não foi registrada em comando, script, log ou documento.
- **Conteúdo/restauração:** 2.842 arquivos-fonte selecionados, inclusive não versionados, documentação, BAT/PS1, migrations, scripts, dependências/lockfiles, APK `app_motorista.apk` (64.491.244 bytes), exportação Git limitada ao App Motorista e configurações protegidas cifradas. O SQLite do Agente foi capturado por backup online e passou em `integrity_check` antes de entrar no arquivo.
- **Exclusões comprovadamente reconstruíveis:** caches/artefatos Flutter-Dart-Gradle, ambientes virtuais Python, `__pycache__`, `.pyc` e caches de testes. Firebird, PostgreSQL, DigitalOcean, ParmaGestor e outros projetos ficaram fora do arquivo.
- **Validação final:** teste de integridade WinRAR concluído com código 0. Tamanho final: 170.522.638 bytes. SHA-256: `20231991F8DFBFCB578AEDB3586676A65DB12D77101BB51CE31271F0509B50F4`, também registrado em `E:\BACKUPS_APP_MOTORISTA\APP_MOTORISTA_HOMOLOGADO_2026-11-25_142455\SHA256SUMS.txt`. Por ser hash do próprio RAR, esse valor fica fora do arquivo para evitar dependência circular.
- **ÚLTIMO PONTO:** versão homologada preservada em arquivo compacto; nenhuma fonte original foi apagada e o Agente não foi interrompido. Aguardar autorização antes de avançar na segurança da API.

**Atualização de 25/11/2026, 14:24 -03:00 — plano compacto de backup, execução bloqueada por criptografia:**

- **Espaço confirmado:** E: possui 17.06 GB livres. O workspace App Motorista mede aproximadamente 2.15 GB; os principais itens reconstruíveis são `AppMotorista/.dart_tool` (590.8 MB), `AppMotorista/build` (899.7 MB), `AppMotorista/android/.gradle` (13.2 MB), `.venv` do Agente (26.5 MB), `venv` da API local (28.9 MB) e `.venv-wsl-pg18` da API Nuvem local (70.8 MB). Esses itens serão excluídos, preservando fontes, `pubspec.lock`, `requirements.txt`, `alembic.ini`, wrappers Gradle, BAT/PS1, migrations, scripts e documentação.
- **APK:** nenhum APK/AAB foi localizado no workspace atual; portanto não há artefato homologado local para incluir até que seja localizado fora dele.
- **Git:** o repositório Git tem raiz `E:\Jorginho` e contém projetos fora do App Motorista; não será copiado integralmente sem decisão específica. O backup compacto deverá preservar o histórico do App Motorista por exportação/arquivo Git restrito aos seus caminhos, mais o estado sujo atual (fontes versionados e não versionados).
- **Bloqueio de segurança:** não foi localizado `7z`, `rar` ou compactador com criptografia. O `tar` nativo do Windows não cifra o conteúdo. Como o backup precisa conter credenciais, não será criado ZIP/TAR simples nem arquivo de configuração desprotegido. Para executar é necessário fornecer uma senha de recuperação para arquivo AES, um certificado de criptografia, ou autorizar a instalação/uso de 7-Zip.
- **Quando desbloqueado:** criar um único arquivo em `E:\BACKUPS_APP_MOTORISTA\APP_MOTORISTA_HOMOLOGADO_2026-11-25`, sem cópia intermediária integral; gerar backup online do SQLite diretamente em área temporária mínima, incluir configurações cifradas, testar a integridade do arquivo e registrar tamanho/`SHA-256`/exclusões. Firebird, PostgreSQL, DigitalOcean e ParmaGestor continuam explicitamente fora deste backup compacto.
- **ÚLTIMO PONTO:** há espaço suficiente e as exclusões são seguras, mas a execução aguarda mecanismo de criptografia para não expor credenciais. Nenhum arquivo original foi apagado ou modificado.

**Atualização de 25/11/2026, 14:24 -03:00 — plano de backup restaurável da versão homologada, aguardando execução:**

- **STATUS:** novas implementações suspensas. Nenhum backup, dump, cópia de banco, hash novo ou alteração operacional foi executado nesta etapa; o BAT permanece em execução.
- **Separação obrigatória de versões:** o backup terá dois grupos: (A) snapshot local homologado — Flutter, Agente, API local, SQLite, logs, documentação, scripts/migrations e fontes ParmaGestor disponíveis — e (B) snapshot efetivamente implantado na DigitalOcean — código/API Nuvem, unidade de serviço, ambiente protegido e dump de `motorista_nuvem`. O workspace local está sujo; portanto não pode ser declarado cópia exata da implantação remota sem a coleta no servidor.
- **Bancos consistentes:** Firebird de homologação será preservado por `gbak` online, nunca por cópia de `DADOS.FDB` ativo; PostgreSQL por `pg_dump` custom em transação consistente; SQLite do Agente por backup online SQLite (`Connection.backup`/`.backup`), seguido de `integrity_check`. O plano inclui verificação de restauração em destinos temporários, somente após autorização.
- **Configurações e segredos:** `agent-token.env`, `agent-firebird.env`, `.env` local e ambiente da API Nuvem serão arquivados separadamente, cifrados e com ACL restritiva; nunca entrarão no repositório, arquivo de hash público ou documentação.
- **Lacunas inventariadas:** não há APK/AAB localizável no workspace atual; deve ser localizado o APK homologado original antes da execução. Os cinco scripts IBExpert aplicados manualmente e o caminho/fonte do atualizador ParmaGestor também não estão presentes no workspace; devem ser fornecidos/confirmados para um backup completo. Fontes ParmaGestor conhecidos: `E:\PARMASOFT_INTEGRACAO\ParmaDistribuidora\Source\View\Mov\UManCargaViagem.pas` e `UMovCarga.pas`.
- **Destino proposto:** pasta nova e imutável por execução, por exemplo `E:\BACKUPS_APP_MOTORISTA\20261125-142455_homologado`, com manifesto, tamanhos e `SHA256SUMS.txt` gerados ao final. Não sobrescrever backups anteriores.
- **ÚLTIMO PONTO:** plano preparado; aguardar autorização explícita antes de criar a pasta, acessar a DigitalOcean, executar `gbak`/`pg_dump`/backup SQLite ou copiar configurações protegidas.

**Atualização de 25/11/2026, 14:13 -03:00 — conciliação individual concluída e fallback de nome de cliente corrigido:**

- **Conciliação individual — comprovada:** comparação entre CSV exportado do IBExpert e consulta PostgreSQL da DigitalOcean confirmou as 14 chaves `(carga, operation_guid, occurrence_guid)`: 776 = 4/4, 777 = 7/7 e 778 = 3/3, sem divergência. Todas estão `APPLIED` na Nuvem, com no máximo uma tentativa; no Firebird todas as operações canônicas são `ENTREGA_REGISTRADA`, `REPLAY='N'`.
- **Correção autorizada:** `AgenteMotoristaGramDecor/agent/read_source.py` e `ApiMotorista/app/viagens/service.py` passaram a usar `COALESCE(NULLIF(TRIM(CL.CLI_FANTASIA_APELIDO), ''), CL.CLI_RSOCIAL_NOME)` para o nome exibido da parada. A regra usa fantasia preenchido; para `NULL`, vazio ou somente espaços usa razão social. Não altera cadastro de cliente, estrutura Firebird, regras de entrega, GUIDs, hashes de retorno, idempotência ou confirmações existentes.
- **Validação local:** 32 testes do Agente e 26 testes da API local aprovados. Os novos testes cobrem fantasia preenchido, nulo, vazio e apenas espaços; compilação Python aprovada.
- **Efeito observado sem reinício/deploy:** como o BAT já inicia um processo Python novo a cada rodada, a carga 778 foi republicada uma única vez às 14:12:32 com revisão 5, aceita pela Nuvem, refletindo a alteração de conteúdo do snapshot. As rodadas posteriores voltaram a `SEM_ALTERACAO`. Não houve retorno, procedimento Firebird, alteração de banco, APK, serviço ou App Malhas.
- **Pendências restantes:** autorização servidor-side por empresa no claim/ACK; localizar os scripts Firebird manuais originais e o atualizador oficial do ParmaGestor antes de integrar migrations. A conciliação individual foi concluída; o fallback de nome está publicado no snapshot, aguardando apenas eventual validação visual futura.
- **ÚLTIMO PONTO:** homologação permanece íntegra após a correção de projeção. Aguardar autorização para qualquer nova implementação, validação física adicional ou preparação de produção.

**Atualização de 25/11/2026, 13:59 -03:00 — auditoria e proposta pós-homologação, sem alteração operacional:**

- **Verificação documental:** a reconciliação final PostgreSQL está registrada imediatamente abaixo: 14 entregas `APPLIED`/retornadas — 4 da 776, 7 da 777 e 3 da 778 — sem `PENDING` ou `CLAIMED`, com as duas rejeições históricas da 776 preservadas.
- **Conciliação individual preparada:** as consultas somente leitura Firebird e PostgreSQL devem comparar a chave `(carga, operation_guid, occurrence_guid)` das 14 aceitações e produzir exatamente o mesmo conjunto, além de conferir estado `APPLIED`, `returned_at` e resultado `ENTREGA_REGISTRADA`. A execução e a comparação permanecem pendentes de autorização operacional.
- **Nome de cliente — causa comprovada:** `AgenteMotoristaGramDecor/agent/read_source.py` e `ApiMotorista/app/viagens/service.py` montam `cliente.nome` por `COALESCE(CLI_FANTASIA_APELIDO, CLI_RSOCIAL_NOME)`. Para a parada 2004/carga 778, `CLI_FANTASIA_APELIDO=''` e a razão social é `ROBERT ARQUETE RODRIGUES`; string vazia não é `NULL`, portanto o nome vazio é publicado. Proposta mínima futura: substituir somente a expressão de projeção por `COALESCE(NULLIF(TRIM(CLI_FANTASIA_APELIDO), ''), CLI_RSOCIAL_NOME)`, nos dois leitores que constroem snapshot. Não alterar o cadastro, GUIDs, hashes, revisões, retorno ou idempotência.
- **Scripts Firebird manuais inventariados:** a documentação registra `00_PRE_VERIFICACAO_SOMENTE_LEITURA.sql`, `01_TB_CARGA_MANIFESTO_NUVEM.sql`, `02_CHAVES_INDICES_E_EXCEPTION.sql`, `03_SP_APL_ENTREGA_NUVEM.sql` e `04_VALIDACAO_POSTERIOR_SOMENTE_LEITURA.sql`. Os artefatos originais não estão presentes neste workspace; somente o envelope não executável `AgenteMotoristaGramDecor/firebird/20260925_0001_sp_apl_entrega_nuvem.sql` foi localizado. Antes de integrar ao atualizador oficial do ParmaGestor, obter os cinco scripts efetivamente aplicados e o caminho/fonte do atualizador para conferir versões, idempotência e ordem. Por classificação nominal, `00`/`04` são validações e não migrations; `01`/`02`/`03` são os candidatos a migração controlada.
- **ÚLTIMO PONTO:** auditoria/proposta concluída sem tocar no BAT em execução, no Agente, bancos, API, APK ou App Malhas. Aguardar autorização para executar a conciliação individual ou implementar qualquer correção.

**Atualização de 25/11/2026, 10:30 -03:00 — reconciliação PostgreSQL final comprovada:**

- **STATUS:** homologação funcional automática ponta a ponta aprovada para a empresa 10 no ambiente de homologação. O BAT normal permanece em execução; esta atualização alterou exclusivamente este documento.
- **Nuvem/PostgreSQL — comprovado por transação `READ ONLY` encerrada com `ROLLBACK`:** carga 776 = 4 `APPLIED`, 4 GUIDs de operação distintos, 4 ocorrências distintas, 4 retornados e máximo de 1 tentativa; 777 = 7/7/7/7, máximo de 1 tentativa; 778 = 3/3/3/3, máximo de 1 tentativa. Não existe `PENDING` nem `CLAIMED` nas três cargas.
- **Conciliação final:** Firebird e PostgreSQL totalizam exatamente 14 entregas aplicadas e 14 retornos confirmados: 4 (776), 7 (777) e 3 (778). As duas operações históricas `REJECTED` da 776 permanecem preservadas, sem efeito sobre as 14 aceitações.
- **Pendências mantidas, sem implementação:** (1) comparação individual dos GUIDs entre Firebird, SQLite e PostgreSQL; (2) autorização definitiva servidor-side por empresa no claim e ACK; (3) fallback para razão social quando o nome fantasia do cliente estiver vazio.
- **ÚLTIMO PONTO:** ciclo automático Firebird → Nuvem → S20 → Nuvem → Firebird homologado e reconciliado. Aguardar autorização explícita para qualquer alteração, endurecimento de segurança ou preparação de produção.

**Atualização de 25/11/2026, 10:25 -03:00 — homologação funcional automática bem-sucedida e auditoria final local read-only:**

- **STATUS:** o BAT normal permanece em execução contínua, sem intervenção desta auditoria. A homologação confirmou publicação automática, leituras pelo Samsung S20, retorno automático Firebird e atualização logística no ParmaGestor. Não houve alteração de código, configuração, banco, procedure, deploy, APK, serviço ou App Malhas nesta auditoria.
- **Firebird homologação — comprovado por transação read-only:** 776 possui 4/4 ocorrências `E`, 777 possui 7/7 e 778 possui 3/3; os manifestos seguem `L` e `TB_CARGA.CARG_STATUS` permanece `A` nas três cargas. Pedidos/paradas: 776 = 3/3 `E`, 777 = 2/2 `E`, 778 = 3/3 `E`. Os vínculos manifesto → ocorrência → pedido → parada foram conferidos por carga.
- **Retornos canônicos Firebird — comprovado:** existem 28 registros em `TB_CARGA_MANIFESTO_NUVEM` para as 14 operações aceitas dessas cargas: 14 GUIDs de operação distintos, cada um com as duas linhas técnicas esperadas (tentativas 1/2, marcas `S`/`N`), `ENTREGA_REGISTRADA` e sem indicação de reaplicação logística. Isso inclui as 4 operações já reconciliadas da 776, as 7 aplicadas automaticamente da 777 e as 3 da 778.
- **Agente — comprovado localmente:** o log mostra o lote das 7 operações da 777 às 10:12:38–10:12:39 e as três operações da 778 às 10:16:21, 10:19:00 e 10:20:04, todas `ACEITA`/`ENTREGA_REGISTRADA`, sem `erros`. O SQLite técnico possui as 7 operações da 777 e as 3 da 778 em `ACKED`, com `applied_at` e `acked_at` preenchidos, sem `last_error`, e `pending_snapshot=0`. As rodadas posteriores permanecem em `SEM_ALTERACAO` para os três manifestos, sem republicação desnecessária.
- **Continuidade:** o log confirmou rodadas completas sucessivas em aproximadamente 30 segundos de espera, com mutex e processo normal ainda ativos. A ordem persistida do fluxo continua sendo Firebird/commit → `APPLIED` SQLite → ACK; a auditoria de estado local confirma o término em ACK, mas a precedência temporal subsegundo commit/ACK não é observável por uma consulta de leitura isolada.
- **Nuvem/PostgreSQL — situação nesta auditoria, posteriormente superada pela atualização das 10:30:** não houve acesso PostgreSQL naquele momento. A reconciliação posterior confirmou as 14 operações `APPLIED`/retornadas e a preservação das rejeitadas históricas.
- **Pendência de qualidade visual — Ubá:** parada 2004 da carga 778, cliente 5844, cidade `UBA`/MG: `CLI_FANTASIA_APELIDO=''` e `CLI_RSOCIAL_NOME='ROBERT ARQUETE RODRIGUES'`. O publicador usa `COALESCE(fantasia, razao)`, que preserva a string vazia por ela não ser `NULL`; daí o nome em branco no aplicativo. Nenhuma correção foi aplicada.
- **Riscos/pendências antes de produção:** implementar futuramente autorização servidor-side agente × empresa no claim e no ACK; confirmar PostgreSQL após esta rodada; revisar o fallback de nome de cliente vazio; definir critérios operacionais de elegibilidade/cancelamento e plano de observabilidade/alertas para produção.
- **ÚLTIMO PONTO:** homologação funcional da empresa 10 aprovada no Firebird de homologação. Manter o BAT em execução e aguardar autorização explícita para qualquer correção, mudança de API ou preparação de produção.

**Atualização de 25/11/2026, 09:58 -03:00 — automação bidirecional preparada localmente (não iniciada):**

- **STATUS:** o Agente normal está preparado para publicar e retornar automaticamente em rodadas de 30 segundos para `MOTORISTA_ALLOWED_SCOPES=10`. Nenhum BAT, Agente, claim, ACK, publicação, procedure Firebird ou conexão com os ambientes reais foi executado nesta atualização.
- **Publicação Firebird → Nuvem:** foi removido do fluxo o uso da linha de base por empresa. Em cada rodada, todos os manifestos liberados (`CARGM_STATUS='L'`, data de liberação, motorista e vínculo de empresa ativos) do escopo autorizado são reavaliados. O snapshot só é enviado quando o hash/revisão indicar mudança; manifesto já sincronizado retorna `SEM_ALTERACAO`. Os registros históricos de baseline continuam intactos no SQLite, porém não são mais consultados como bloqueio.
- **Retorno Nuvem → Firebird:** o inicializador normal passa a habilitar retorno automático sem `operation_guid`; mantém o modo `--return-only --operation-guid <UUID>` exclusivamente para manutenção/homologação unitária. A sequência permanece claim → inbox SQLite → procedure/commit Firebird → `APPLIED` local → ACK. A validação canônica de UUID continua somente para comparação, preservando os literais originais de operação, payload e hash.
- **Isolamento dos fluxos:** erro de publicação é registrado em `erros` e não impede o retorno daquela rodada; erro de retorno não impede a publicação. O código retorna saída não-zero em caso de erro, para evidência no log, mas o laço PowerShell permanece ativo e tenta nova rodada após 30 segundos. Mutex, logs rotativos e encerramento por Ctrl+C foram preservados.
- **Escopo e independência comercial/logística:** a origem continua filtrada pelo manifesto liberado e pelo vínculo ativo da empresa, não por `TB_CARGA.CARG_STATUS`; portanto `A`/`F` não decide elegibilidade logística. Não há `UPDATE TB_CARGA` no retorno.
- **Testes locais:** 31 testes unitários aprovados. Foram incluídos cenários de descoberta de manifesto pré-existente sem baseline, não republicação por hash, publicação pendente inelegível descartada, independência publicação/retorno quando uma das direções falha e bloqueio de pendência SQLite de empresa fora do escopo. Não houve acesso a Firebird, PostgreSQL ou Nuvem nos testes.
- **Risco operacional a resolver antes do primeiro BAT:** o endpoint atual de `claim` não recebe filtro de empresa. O Agente valida a empresa autorizada antes de gravar no Firebird, mas uma confirmação de outra empresa eventualmente devolvida pelo servidor já teria sido reivindicada. Para a homologação atual, confirmar previamente que o tenant GramDecor não possui retornos pendentes de empresa diferente de 10; para a operação multiempresa definitiva, será necessária autorização específica para acrescentar o filtro de empresa no contrato da API de claim.
- **PRÓXIMO PONTO:** aguardar autorização explícita para iniciar `AgenteMotoristaGramDecor\INICIAR_AGENTE_MOTORISTA.bat`. No cenário homologado informado, espera-se publicar 778 e retornar as sete operações pendentes de 777; 776 deve permanecer reconciliada, sem nova aplicação.

- **STATUS:** reconciliação Nuvem/Firebird avançou por leitura em 25/11/2026; não há Agente conectado, publicação, claim, ACK, retorno Firebird, deploy ou teste físico em execução.
- **Situação atual:** delivery_read V2 está implantado na API Nuvem, com normalização canônica de `occurrence_guid` e projeção persistente derivada do ledger. A carga 777 está validada em leitura: sete aceitações distintas e projeções automáticas, sem reconstrução manual.
- **Última atividade concluída:** auditoria read-only confirmou que `CARG_STATUS='A'` correlaciona com carga ainda não faturada e `F` com `CARG_DT_FATURAMENTO` preenchida; o retorno existente não atualiza `TB_CARGA.CARG_STATUS`. A entrega logística reside em ocorrências, pedidos e paradas do manifesto.
- **Evidência:** `flutter analyze` sem issues; `flutter test` com **105 testes aprovados**; APK `app-release.apk` de 64.491.244 bytes e SHA-256 `98232FE073DFBB6B9EE6E47367F73A14845FB9CA9F29A60BEF658A255BBB8031`, compilado com `API_BASE_URL=https://motorista.parmatech.com.br`, `API_ENV=homologacao`, timeout 20 e `MOTORISTA_READ_ONLY=false`.
- **Evidência principal:** Firebird read-only: 776 possui 4 ocorrências `E`, 3 pedidos/paradas `E` e 4 operações canônicas aceitas pela `SP_APL_ENTREGA_NUVEM`; 777 possui 7 ocorrências `P` e 2 paradas/pedidos pendentes; 778 está `L` com 3 ocorrências `P`. As cargas 775–778 permanecem `CARG_STATUS='A'`, sem faturamento.
- **Reconciliação Nuvem comprovada:** consulta PostgreSQL de produção em transação `READ ONLY`/`ROLLBACK` retornou 11 operações aceitas: 776 com 4 `APPLIED`, 4 ACKs e máximo 1 tentativa; 777 com 7 `PENDING`, zero ACK e zero tentativa. A 776 está reconciliada e não deve ser reaplicada.
- **Pré-validação da primeira 777:** operação `f9918d75-771d-4074-bc2c-623ae1d6fd08` corresponde à ocorrência V2 `e5860fc5-dcfa-4e05-bfb1-24e21a88e2ce`; no Firebird é a ocorrência 5336, status `P`, manifesto 273/`DA4…75B` `L`, carga 777, parada 2000, pedido 23591 e código `C02359100023603600000`. Não há aplicação anterior para esse GUID de operação.
- **Modo unitário de homologação:** `--return-only --operation-guid <UUID>` não constrói o publicador de snapshots, exige UUID válido, exige retorno explicitamente habilitado somente no processo controlado, filtra a empresa allowlisted e recusa claim com operação diferente, empresa diferente ou mais de uma operação. Pendências SQLite de outra operação são ignoradas.
- **Proteções preservadas:** UUID de ocorrência canônico para comparação; literal original de operação/payload/hash preservado; claim → inbox → Firebird/commit → APPLIED → ACK; mutex comum aos modos normal e unitário. A partir da atualização acima, o retorno normal é habilitado somente pelo inicializador local, ainda não executado.
- **Evidência anterior complementada:** os 28 testes anteriores foram ampliados para 31, com `py_compile` e análise sintática PowerShell aprovados. A cobertura inclui return-only sem publicação, UUID ausente/inválido/divergente, operação/empresa fora do escopo, múltiplas operações reclamadas, pendência não autorizada, falhas/replay, independência entre os dois fluxos e ausência de `UPDATE TB_CARGA` no Agente.
- **ÚLTIMO PONTO DE PARADA anterior, superado:** a correspondência integral da primeira operação 777 foi aprovada por leitura. Nesta etapa foi expressamente autorizado não gerar backup novo; a próxima ação permanece condicionada à autorização explícita para iniciar o fluxo automático.
- **Bloqueios/restrições atuais:** não executar claim/ACK, `SP_APL_ENTREGA_NUVEM`, reenvio de operações antigas ou qualquer teste físico antes da autorização. Não usar dados de produção para testes destrutivos.

### Próximas etapas — pendentes, não realizadas

1. Autorizar a execução do BAT automático na cópia Firebird de homologação.
2. Acompanhar publicação da 778 e retorno das sete confirmações pendentes da 777.
3. Executar as consultas pós-validação Firebird/Nuvem e a tela Acompanhamento.
4. Confirmar que a 776 permanece reconciliada e que não houve duplicidade.

**Atualização histórica de 25/11/2026 — prioridade retorno e independência comercial/logística:** a linha de base temporal da descoberta foi suspensa para revisão. A elegibilidade definitiva deverá vir do manifesto e de seu estado logístico, nunca exclusivamente de `TB_CARGA.CARG_STATUS`: cargas faturadas (`F`) podem continuar pendentes de entrega. Naquele momento o retorno continuava desabilitado; nenhuma operação de Nuvem/Firebase/Firebird foi executada naquela auditoria.

## Índice resumido

1. [Resumo executivo](#1-resumo-executivo)
2. [Arquitetura e limites](#2-arquitetura-e-limites)
3. [Ambientes, caminhos e componentes](#3-ambientes-caminhos-e-componentes)
4. [Fluxo de leitura V2 e projeção autoritativa](#4-fluxo-de-leitura-v2-e-projeção-autoritativa)
5. [Flutter, S20 e offline](#5-flutter-s20-e-offline)
6. [Agente, Firebird e IBExpert](#6-agente-firebird-e-ibexpert)
7. [PostgreSQL, migrations e reconstrução](#7-postgresql-migrations-e-reconstrução)
8. [Homologação, testes e evidências](#8-homologação-testes-e-evidências)
9. [Deploy, backup e rollback](#9-deploy-backup-e-rollback)
10. [Solução de problemas](#10-solução-de-problemas)
11. [Histórico detalhado](#11-histórico-detalhado)
12. [Pendências, riscos e regras operacionais](#12-pendências-riscos-e-regras-operacionais)
13. [Fontes incorporadas e divergências históricas](#13-fontes-incorporadas-e-divergências-históricas)
14. [Metodologia de desenvolvimento e homologação](#14-metodologia-de-desenvolvimento-e-homologação)
15. [Operação manual contínua do agente](#15-operação-manual-contínua-do-agente)

## 1. Resumo executivo

O App Motorista funciona como Flutter/S20 → API Motorista Nuvem/PostgreSQL → agente controlado → Firebird. A carga GramDecor 776 (empresa 10, motorista Paulo, transportador 22) foi publicada e exibida no S20. Em 23/11/2026, quatro leituras V2 foram aceitas no ledger: uma do pedido 22014, uma do 23318 e duas do 23327.

O contrato V2 inicialmente falhava porque a Nuvem aceitava somente V1; depois, porque a API comparava UUID minúsculo com GUID publicado em maiúsculo. Ambos foram corrigidos e implantados. A migration `20261123_0005` adicionou a projeção derivada persistente `delivery_confirmation_projection`; ela preserva o snapshot Firebird bruto e fornece à viagem o estado efetivo calculado a partir do ledger.

Confirmado em produção para 776: quatro confirmações, zero duplicidades, três pedidos e três paradas efetivamente `E`. As duas recusas antigas `OCORRENCIA_NAO_ENCONTRADA` não participam da projeção. Retorno ao Firebird não foi implantado nem habilitado.

## 2. Arquitetura e limites

```text
Flutter/S20 --HTTPS--> API Nuvem + PostgreSQL <--HTTPS--> Agente controlado --SELECT--> Firebird homologação
```

- **Flutter:** sessão, viagem cacheada, scanner/leitor, SQLite/outbox e replay preservando GUIDs.
- **API Nuvem:** snapshots, autenticação, ledger `delivery_read_operation`, projeção derivada e health.
- **Agente:** publica snapshots V1 a partir do Firebird em escopo explícito; não é serviço contínuo autorizado.
- **Firebird:** origem do snapshot. O retorno de entregas é bloqueado.

Status técnicos confirmados: `P` pendente e `E` entregue. Pedido/parada tornam-se `E` somente se todas as suas ocorrências efetivas forem `E`. O V2 não inventa encerramento manual de manifesto nem novos códigos de status.

## 3. Ambientes, caminhos e componentes

| Componente | Caminho/ambiente | Situação |
|---|---|---|
| Flutter | `E:\Jorginho\AppMotorista\AppMotorista` | Outbox V2 implementada; offline físico no S20 pendente |
| API local legada | `E:\Jorginho\AppMotorista\ApiMotorista` | Legada/substituída para o S20 atual; usa Firebird local |
| API Nuvem | `/opt/api-motorista-nuvem` | Produção implantada; serviço `api-motorista-nuvem.service` |
| API Nuvem fonte | `E:\Jorginho\AppMotorista\ApiMotoristaNuvem` | Workspace pode estar defasado/sujo; não é prova de produção |
| PostgreSQL local | WSL `Ubuntu-24.04`, PG 18/main, `motorista_nuvem_test` | Homologação isolada |
| Agente | `E:\Jorginho\AppMotorista\AgenteMotoristaGramDecor` | Automação bidirecional preparada; aguardando autorização para iniciar |
| Firebird homologação | `E:\Dados Clientes\GramDecor\DADOS.FDB` | Estrutura de manifesto instalada; retorno não homologado |

Produção: `https://motorista.parmatech.com.br`, Gunicorn em `127.0.0.1:8091`, ambiente em `/etc/api-motorista-nuvem.env`. Não colocar credenciais neste tutorial ou em logs.

## 4. Fluxo de leitura V2 e projeção autoritativa

### Contratos

Endpoint: `POST /api/v1/motorista/viagens/{manifesto_guid}/paradas/{parada}/pedidos/{pedido}/leituras`.

- V1 é aceito apenas como replay legado compatível; novas operações sem `occurrence_guid` são recusadas com `OCORRENCIA_GUID_OBRIGATORIA`.
- V2 inclui `operacao_guid`, `occurrence_guid`, `codigo`, `data_hora_aparelho` e `fuso_minutos`.
- `occurrence_guid` é UUID obrigatório e entra no hash da requisição.
- A API valida viagem, parada, pedido, código, ocorrência e autorização antes de aceitar.
- Idempotência: chave `(tenant_id, operation_guid)`. Mesmo payload retorna replay; payload diferente retorna conflito.

### Normalização canônica

O `contracts.py` normaliza UUID; `service.py` usa `UUID` nos dois lados da comparação. Isso corrige a divergência entre GUID publicado em maiúsculas e payload do S20 em minúsculas. Não substituir por comparação frouxa de texto.

### Projeção derivada

Migration `20261123_0005_delivery_confirmation_projection.py` criou:

- `delivery_confirmation_projection`;
- unicidade `(tenant_id, manifest_guid, occurrence_guid)`;
- unicidade `(tenant_id, operation_guid)`.

Na mesma transação do ledger aceito, a confirmação derivada é persistida. `get_trip` aplica a sobreposição derivada ao `detail_json` bruto; portanto refresh Firebird em `P` não reverte uma confirmação Nuvem. `rebuild_delivery_confirmation_projection` limpa e repovoa a projeção de um manifesto a partir de ledger com `resultado=ACEITA`, ignorando recusas e preservando somente a primeira aceitação por ocorrência.

## 5. Flutter, S20 e offline

O scanner encaminha texto bruto com `trim().toUpperCase()`; não existe parser posicional da etiqueta. Exemplo confirmado: `C02201400086350800000` é tratado como código opaco e corresponde a pedido 22014/produto 8635/quantidade 80 na projeção.

Arquivos principais:

- `lib/viagens/screens/camera_scanner_screen.dart`;
- `lib/viagens/local/delivery_local_store.dart`;
- `lib/viagens/repositories/trips_repository.dart`;
- `lib/sync/services/outbox_sync_controller.dart`.

SQLite preserva snapshot e payload V2. Em perda de rede, a operação fica pendente; após perda de resposta, o mesmo `operacao_guid` deve ser repetido. O código recupera `sending` interrompido como `pending`. Isso possui testes automatizados; teste físico em modo avião, reinício e retorno de rede no S20 ainda é pendência.

Para a próxima validação, usar carga nova e não recriar GUIDs. Confirmar uma linha aceita no ledger, confirmação derivada única e estado efetivo no GET da viagem.

## 6. Agente, Firebird e IBExpert

O agente requer `MOTORISTA_ALLOWED_SCOPES`; vazio bloqueia publicação. Nesta homologação, o inicializador força somente a empresa `10`, sem carga fixa. Ele obtém lease/fencing, calcula hash semântico, persiste estado técnico SQLite e reutiliza identidade em retry.

O agente lê Firebird por transações curtas read-only e publica snapshots HTTPS. O inicializador normal habilita o retorno somente no processo do Agente, preservando a procedure e a sequência idempotente; não acioná-lo antes da autorização operacional.

Scripts Firebird preparados em `E:\Jorginho\AppMotorista\SQL_IBEXPERT_MANIFESTO_NUVEM_2026-11-23`:

1. `00_PRE_VERIFICACAO_SOMENTE_LEITURA.sql`;
2. `01_TB_CARGA_MANIFESTO_NUVEM.sql`;
3. `02_CHAVES_INDICES_E_EXCEPTION.sql`;
4. `03_SP_APL_ENTREGA_NUVEM.sql`;
5. `04_VALIDACAO_POSTERIOR_SOMENTE_LEITURA.sql`.

Eles foram preparados para Firebird 2.5.9/IBExpert, começando em cópia descartável. O corpo da procedure veio do pacote original; o envelope em `AgenteMotoristaGramDecor/firebird/20260925_0001_sp_apl_entrega_nuvem.sql` não é migration executável.

**Risco documentado:** `AgenteMotoristaGramDecor/INICIAR_AGENTE_MOTORISTA.ps1` força `MOTORISTA_DELIVERY_RETURN_ENABLED=true` para o fluxo automático autorizado em código. Não executá-lo antes da autorização operacional específica; o endpoint de claim ainda não filtra empresa no servidor.

## 7. PostgreSQL, migrations e reconstrução

### Homologação local

- WSL: `Ubuntu-24.04`, PostgreSQL 18/main, porta 5432.
- Banco exclusivo: `motorista_nuvem_test`.
- Backup pré-projeção: `/var/backups/app-motorista-homologacao/motorista_nuvem_test_pre_confirmation_projection_20261123.dump`.
- SHA-256: `9ed7bcb8e73a4a5ceef33816ca6f376ef29562c52a1cf76be1a07a19abc7dabb`.
- Migration local final: `20261123_0005`; fixtures removidas por `TRUNCATE tenant RESTART IDENTITY CASCADE`.

### Produção

- Alembic atual: `20261123_0005 (head)`.
- Backup de deploy: `/root/backup-api-motorista-projection-20261123T183100Z`.
- Inclui código anterior, ambiente e dump PostgreSQL pré-0005; hashes registrados em `SHA256SUMS`.

Reconstrução de 776 foi limitada ao manifesto `697AE01E-5C7A-4780-BB4F-221C1DFFB56F`. Procedimento futuro: confirmar contagem/uniqueness do ledger primeiro; chamar a rotina dentro de transação; validar projeção e visão efetiva; nunca alterar ledger ou snapshot bruto.

## 8. Homologação, testes e evidências

No PostgreSQL local, `tests.test_postgresql_integration` aprovou **13 testes**. Cobertura confirmada: ocorrência exata, UUID válido/inválido e caixa, V1/replay, conflito, rollback, unicidade, duas etiquetas no pedido, refresh em `P`, reconstrução idempotente, perda de resposta/replay, recusas excluídas e concorrência real com duas conexões/operações distintas.

Na concorrência, exatamente uma operação recebeu `ACEITA/LEITURA_CONFIRMADA`, a outra `OCORRENCIA_JA_ENTREGUE`, ambas sem HTTP 500/deadlock e com uma confirmação persistida.

Evidência de produção 776:

| Pedido | Produto | Parada | Occurrence GUID | Estado efetivo |
|---:|---:|---:|---|---|
| 22014 | 8635 | 1997 | `74DDEA91-1913-4877-A53B-AAD5DC74281F` | E |
| 23318 | 8945 | 1998 | `6A645BA4-43E7-4E22-8627-D7A8BD294EE8` | E |
| 23327 | 8896 | 1999 | `0A75BE00-FCA0-4222-A040-A176FE070621` | E |
| 23327 | 8909 | 1999 | `23B44588-F1C6-43ED-81AD-329B86559F67` | E |

Há duas recusas históricas da etiqueta 22014: `2c7eb37e-07e2-44e6-945b-f15ea3481da3` e `5e0cfe68-679a-4a45-91ff-4236ab3a53eb`; ambas `OCORRENCIA_NAO_ENCONTRADA`, anteriores à correção canônica. Não reenviar.

## 9. Deploy, backup e rollback

Deploy efetivado em 23/11/2026. Hashes finais:

- `app/service.py`: `1fa4d1f28bbe7968b1e39722a29bc1012b454a31518dc7fb128fb52f59e26c6b`;
- `app/tables.py`: `b6e2b2894c476426d9646e0365f7d5721fb93293dd3f71dc4bea3fddb3bbd906`;
- migration: `bd952bf103305415357e1e28df6207c5cfb5e9ae15ac16383a768de0c3c219f9`.

Sequência segura para mudança futura: backup verificável; hashes da base; migration; cópia/patch mínimo; `py_compile`/import; restart exclusivo; health local e público; leitura do ledger/projeção; documentação imediata.

Rollback de código: restaurar `service.py` e `tables.py` do backup de janela e reiniciar somente `api-motorista-nuvem.service`. Se a migration já existir e o rollback for de código, manter a tabela nova inerte; não executar restauração PostgreSQL destrutiva automática. Nenhuma alteração de código deve sobrescrever revisão de produção sem hash compatível.

## 10. Solução de problemas

| Sintoma | Causa comprovada / ação segura |
|---|---|
| `campos nao permitidos: occurrence_guid` | Nuvem V1 antiga. Correção V2 foi implantada; não remover GUID do Flutter. |
| `Ocorrencia nao pertence a esta viagem` | Comparação de UUID sensível a caixa. Corrigida por normalização canônica. |
| Snapshot mostra `P` após leitura | Esperado no `detail_json` bruto; consultar visão efetiva com projeção derivada. |
| Operação repetida | Reutilizar mesmo `operation_guid`; não escanear de novo para “resolver”. |
| Nova operação para ocorrência `E` | Deve retornar recusa terminal `OCORRENCIA_JA_ENTREGUE`. |
| Viagem/acompanhar Firebird SQL -204 | Estrutura ausente foi tratada pelos scripts IBExpert; validar sempre em cópia antes de novo DDL. |
| Health indisponível logo após restart | Aguardar boot curto e consultar journal; rollback somente se health/worker falharem persistentemente. |

## 11. Histórico detalhado

### 25/11/2026 — primeira operação 777 validada por leitura cruzada

- PostgreSQL read-only confirmou para `f9918d75-771d-4074-bc2c-623ae1d6fd08`: tenant 1/`GRAMDECOR`, empresa 10, carga 777, parada 2000, pedido 23591, resultado `ACEITA`, `return_state=PENDING`, zero tentativa, ACK nulo, contrato de retorno 1 e hash presente. O GUID de ocorrência foi corretamente obtido de `request_json`: `e5860fc5-dcfa-4e05-bfb1-24e21a88e2ce`.
- Firebird read-only no destino configurado `E:\DADOS CLIENTES\GRAMDECOR\DADOS.FDB` confirmou a forma canônica maiúscula do mesmo GUID: ocorrência 5336 `P`, manifesto 273/`DA4EC803-9B42-4ABC-B070-F7E35D79C75B` `L`, carga 777, parada 2000, pedido 23591, código `C02359100023603600000`, parada/pedido `P` e status comercial `A` preservado. Não existe linha com a `operation_guid` selecionada em `TB_CARGA_MANIFESTO_NUVEM` ou `TB_CARGA_MANIFESTO_OPERACAO`.
- A assinatura instalada de `SP_APL_ENTREGA_NUVEM` confirmou os quinze parâmetros de entrada do contrato 1, inclusive ocorrência, operação, versão e hash; é compatível com o payload V2 retornado pela Nuvem. Não foi chamada.
- Existem cópias recuperáveis históricas (`DADOS antes Merge.FDB`, 19/11/2026, e `DADOS.FBK`, 04/11/2026), mas não foi criado backup novo imediatamente anterior à futura gravação. Um backup novo, verificável e autorizado continua pré-requisito antes do retorno real.

### Validações pós-retorno unitário — somente leitura

Após execução autorizada, no Firebird confirmar a mesma linha acima com `CARGMO_STATUS='E'`; consultar também:

```sql
SELECT CARGMN_OPERACAO_GUID, CARGMN_TENTATIVA, CARGMN_CANONICO,
       CARGMN_OCORRENCIA_GUID, CARGMN_RESULTADO, CARGMN_CODIGO_RESPOSTA,
       CARGMN_REPLAY, CARGMN_DH_SERVIDOR
  FROM TB_CARGA_MANIFESTO_NUVEM
 WHERE CARGMN_OPERACAO_GUID = 'F9918D75-771D-4074-BC2C-623AE1D6FD08'
 ORDER BY CARGMN_TENTATIVA;
```

No PostgreSQL, em transação `READ ONLY`, confirmar `return_state='APPLIED'`, `return_attempt_count=1`, `returned_at` e `return_result_json` preenchidos para a mesma `operation_guid`.

### 25/11/2026 — reconciliação PostgreSQL read-only: 776 aplicada; 777 pendente

- Consulta executada manualmente na DigitalOcean com transação `READ ONLY` e `ROLLBACK`: 11 operações `ACEITA` foram confirmadas. A 776 possui 4 linhas `APPLIED`, 4 ACKs e máximo de uma tentativa; a 777 possui 7 linhas `PENDING`, sem ACK e sem tentativa. A 776 está reconciliada entre Nuvem e Firebird e foi excluída da homologação de retorno.
- A operação escolhida para pré-validação da 777 é `f9918d75-771d-4074-bc2c-623ae1d6fd08`. A primeira consulta usou `response_json ->> 'occurrence_guid'`, que veio nulo; o contrato V2 persiste o GUID de origem em `request_json ->> 'occurrence_guid'`. A consulta complementar foi preparada abaixo.
- O destino configurado e já auditado do Agente é `E:\Dados Clientes\GramDecor\DADOS.FDB`, a cópia Firebird de homologação autorizada. Nenhuma chamada, escrita ou publicação foi realizada nesta atualização.

### Pré-validação complementar da operação 777 — somente leitura

No PostgreSQL da DigitalOcean, dentro de `BEGIN TRANSACTION READ ONLY`, executar:

```sql
SELECT t.id AS tenant_id,
       t.external_id AS tenant,
       mp.company_id AS empresa,
       mp.load_number AS carga,
       d.operation_guid,
       d.manifest_guid,
       d.stop_id AS parada,
       d.order_id AS pedido,
       d.request_json ->> 'occurrence_guid' AS occurrence_guid_v2,
       d.request_json ->> 'codigo' AS codigo,
       d.request_json AS request_payload_v2,
       d.request_hash,
       d.return_contract_version,
       d.return_payload_hash,
       d.response_json ->> 'resultado' AS resultado_leitura,
       d.return_state,
       d.return_attempt_count,
       d.claimed_instance_guid,
       d.claim_expires_at,
       d.return_result_json,
       d.returned_at
  FROM delivery_read_operation d
  JOIN tenant t ON t.id = d.tenant_id
  JOIN manifest_projection mp
    ON mp.tenant_id = d.tenant_id
   AND mp.manifest_guid = d.manifest_guid
 WHERE d.operation_guid = 'f9918d75-771d-4074-bc2c-623ae1d6fd08'::uuid;
```

O resultado só é elegível se houver uma linha com empresa 10, carga 777, resultado `ACEITA`, estado `PENDING`, nenhuma tentativa/ACK, GUID V2 UUID válido e `return_payload_hash` presente.

No Firebird de homologação, substituindo `<OCCURRENCE_GUID_V2>` pelo valor da consulta anterior, executar somente leitura:

```sql
SELECT M.CARGM_EMPRESA,
       M.CARGM_CARGA,
       M.CARGM_GUID AS MANIFEST_GUID,
       M.CARGM_STATUS AS MANIFEST_STATUS,
       O.CARGMO_GUID AS OCCURRENCE_GUID,
       O.CARGMO_STATUS AS OCCURRENCE_STATUS,
       O.CARGMO_PARADA,
       O.CARGMO_PEDIDO,
       O.CARGMO_CODIGO,
       P.CARGPA_STATUS AS STOP_STATUS,
       PP.CARGPAP_STATUS AS ORDER_STATUS,
       C.CARG_STATUS AS COMMERCIAL_STATUS
  FROM TB_CARGA_MANIFESTO M
  JOIN TB_CARGA_MANIFESTO_OCORRENCIA O
    ON O.CARGMO_EMPRESA = M.CARGM_EMPRESA
   AND O.CARGMO_MANIFESTO = M.CARGM_ID
  JOIN TB_CARGA_PARADA P
    ON P.CARGPA_EMPRESA = M.CARGM_EMPRESA
   AND P.CARGPA_CARGA = M.CARGM_CARGA
   AND P.CARGPA_ID = O.CARGMO_PARADA
  JOIN TB_CARGA_PARADA_PEDIDO PP
    ON PP.CARGPAP_EMPRESA = M.CARGM_EMPRESA
   AND PP.CARGPAP_CARGA = M.CARGM_CARGA
   AND PP.CARGPAP_PARADA = O.CARGMO_PARADA
   AND PP.CARGPAP_PEDIDO = O.CARGMO_PEDIDO
  JOIN TB_CARGA C
    ON C.CARG_EMPRESA = M.CARGM_EMPRESA
   AND C.CARG_ID = M.CARGM_CARGA
 WHERE M.CARGM_EMPRESA = 10
   AND M.CARGM_CARGA = 777
   AND M.CARGM_GUID = 'DA4EC803-9B42-4ABC-B070-F7E35D79C75B'
   AND O.CARGMO_GUID = UPPER('<OCCURRENCE_GUID_V2>');
```

Exigir uma única linha com manifesto `L`, ocorrência/parada/pedido `P`, GUID/código/parada/pedido coincidentes com a Nuvem. `COMMERCIAL_STATUS` é apenas evidência e não bloqueia retorno.

### 25/11/2026 — modo return-only unitário, sem publicação, implementado localmente

- `main.py` agora aceita somente a combinação `--return-only --operation-guid <UUID>`. Sem os dois parâmetros, ou com UUID inválido, encerra com código 2 antes de carregar configuração operacional. Nesse modo não cria `FirebirdSnapshotSource` nem `SnapshotSynchronizer`; portanto não publica snapshots, inclusive a carga 778.
- `INICIAR_AGENTE_MOTORISTA.ps1 -ReturnOnly -OperationGuid <UUID>` é uma rodada única, não um loop. Após validar o UUID, ele habilita retorno somente no processo filho e fixa a mesma operação no ambiente. O inicializador normal e o BAT não passam esses parâmetros e seguem forçando retorno `false`.
- `DeliveryReturnSynchronizer` exige que o claim unitário retorne no máximo uma operação, cujo UUID canônico seja exatamente o selecionado e cuja empresa esteja no escopo permitido. Somente a pendência SQLite da operação selecionada é aplicada/ACKed; outras permanecem intocadas.
- O mesmo mutex `Local\Parmasoft.AgenteMotoristaGramDecor.Manifestos` cobre normal e unitário. Teste em processos separados recusou a segunda instância com código 2.
- Resultado local: 28 testes unitários e `py_compile` aprovados; recusas de CLI sem GUID e GUID inválido retornaram código 2. Nenhum serviço real, claim, ACK, procedure ou publicação foi chamado.

### Procedimento futuro — uma operação da carga 777, somente após autorização explícita

1. Executar as consultas PostgreSQL read-only abaixo e escolher uma linha com `carga=777`, `leitura_resultado=ACEITA`, `return_state=PENDING`, GUID de ocorrência presente e sem divergência com Firebird.
2. Conferir no Firebird, somente leitura, que o manifesto é `L`, a ocorrência exata é `P`, a parada/pedido pertencem ao manifesto e `CARG_STATUS` não será critério de retorno.
3. Registrar o `operation_guid` selecionado e executar **uma única vez** no diretório do Agente:

```powershell
& .\INICIAR_AGENTE_MOTORISTA.ps1 -ReturnOnly -OperationGuid '<OPERATION_GUID_CONFIRMADA>'
```

4. Conferir o log diário. Em seguida, executar novamente as consultas read-only Nuvem/Firebird: a operação deve estar `APPLIED`, a ocorrência `E`, sem nova operação/carga; `CARG_STATUS` deve permanecer inalterado.
5. Conferir a tela Acompanhamento do ParmaGestor. Se houver erro ou divergência, parar: não executar outra operação e não usar o modo normal.

O comando acima é documentação para execução futura autorizada; não foi executado nesta etapa.

### 25/11/2026 — correção local UUID do retorno e testes de recuperação

- `agent/return_sync.py` passou a validar `occurrence_guid` dos dois lados com `UUID`, eliminando a divergência entre a forma minúscula V2 e a forma maiúscula devolvida pelo Firebird. A normalização é somente de comparação; não reescreve `operation_guid`, JSON persistido, hash ou metadados de idempotência.
- `operation_guid` também é validado como UUID, porém seu literal persistido é preservado para lookup no inbox SQLite e ACK. Não há outra comparação textual de GUID no fluxo de retorno.
- Testes isolados cobriram falha antes do commit Firebird, após o commit antes de `APPLIED`, após `APPLIED` antes do ACK, reinício e replay, conflito, ACK terminal não repetido e GUID inválido/divergente. Resultado: 24 testes aprovados e `py_compile` aprovado, sem rede ou Firebird real.
- O inicializador normal continua forçando `MOTORISTA_DELIVERY_RETURN_ENABLED=false`; não foram executados claim, ACK, retorno real, publicação da 778 ou alterações na Nuvem, PostgreSQL, Flutter, Firebird e ParmaGestor.
- Bloqueio adicional identificado: o `main.py` atual publica snapshots antes de chamar o sincronizador de retorno. A homologação unitária da 777 requer, em mudança futura autorizada, modo return-only que exija uma `operation_guid`, não publique snapshots e não processe retorno global.
- Fontes ParmaGestor foram localizados e apenas lidos em `E:\PARMASOFT_INTEGRACAO\ParmaDistribuidora\Source\View\Mov\UManCargaViagem.pas` e `UMovCarga.pas`. A tela Acompanhamento usa `CARGPA_STATUS`, `CARGPAP_STATUS` e contagens de `CARGMO_STATUS` (`P`/`E`), além de exibir o último retorno canônico; não depende de `CARG_STATUS` para concluir logisticamente uma parada.
- Reconciliação 776: as quatro aplicações Firebird ocorreram em 23/11/2026 entre 15:53:46.248 e 15:53:46.767 (horário do servidor Firebird), pelo mecanismo `SP_APL_ENTREGA_NUVEM`: cada `operation_guid` possui registro canônico `S` de tentativa 1 e registro de resultado `N` de tentativa 2, ambos `ENTREGA_REGISTRADA`. Isso prova a aplicação procedural no Firebird, mas não prova por si só o `return_state` atual na Nuvem.

### Consultas PostgreSQL de produção — somente leitura, preparar antes da homologação

No servidor da API, após obter autorização operacional, carregar o ambiente sem exibir o conteúdo e abrir transação read-only. O nome da variável é `DATABASE_URL` conforme `ApiMotoristaNuvem/app/config.py`.

```bash
sudo -s
set -a
. /etc/api-motorista-nuvem.env
set +a
export PSQL_DATABASE_URL="${DATABASE_URL/postgresql+psycopg/postgresql}"
psql "$PSQL_DATABASE_URL" -v ON_ERROR_STOP=1
```

No `psql`, executar apenas:

```sql
BEGIN TRANSACTION READ ONLY;

SELECT d.operation_guid,
       d.response_json ->> 'occurrence_guid' AS occurrence_guid,
       d.manifest_guid,
       mp.load_number AS carga,
       d.response_json ->> 'resultado' AS leitura_resultado,
       d.return_state,
       d.return_attempt_count,
       d.claimed_instance_guid,
       d.claim_expires_at,
       d.return_result_json,
       d.returned_at,
       d.created_at
  FROM delivery_read_operation d
  JOIN manifest_projection mp
    ON mp.tenant_id = d.tenant_id
   AND mp.manifest_guid = d.manifest_guid
 WHERE mp.company_id = 10
   AND mp.load_number IN (776, 777)
   AND d.response_json ->> 'resultado' = 'ACEITA'
 ORDER BY mp.load_number, d.created_at, d.operation_guid;

ROLLBACK;
```

O modelo atual preserva contador, titular/expiração do último claim, resultado/horário final e operação imutável; não possui uma tabela de histórico de cada tentativa de claim. Não criar essa tabela nesta etapa.

### 25/11/2026 — auditoria somente leitura do retorno Nuvem → Firebird; prioridade alterada

- Firebird de homologação foi consultado exclusivamente com transação read-only. Não foram executados `claim`, `ACK`, `SP_APL_ENTREGA_NUVEM`, DDL, DML, publicação ou inicialização do Agente.
- `TB_CARGA`: 775–778 estão em `A`, com `CARG_DT_FATURAMENTO` nulo; a amostra da empresa 10 tem 761 cargas `F`, todas com faturamento preenchido. A evidência confirma fortemente `A` como aberta/não faturada e `F` como faturada, sem afirmar que esse campo represente entrega. A procedure de retorno não escreve em `TB_CARGA`.
- `TB_CARGA_MANIFESTO`: 776 (manifesto 272) e 777 (273) estão `L`; 778 (274) também está `L`. Não há manifesto da 775. O manifesto contém datas próprias de geração, liberação, conclusão e cancelamento, separadas da carga comercial.
- Estado logístico observado: 776 tem 4 ocorrências `E`, 3 pedidos/paradas `E` e quatro operações canônicas aceitas registradas em `TB_CARGA_MANIFESTO_NUVEM` (mais quatro registros de resultado); 777 tem 7 ocorrências `P` e 2 pedidos/paradas `P`; 778 tem 3 ocorrências e 3 paradas/pedidos `P`.
- `SP_APL_ENTREGA_NUVEM` existente valida empresa, manifesto `L`, motorista/vínculo ativos, parada/pedido, GUID exato, código e estado `P`; altera somente `TB_CARGA_MANIFESTO_OCORRENCIA`, `TB_CARGA_PARADA_PEDIDO` e `TB_CARGA_PARADA`, com auditoria idempotente em `TB_CARGA_MANIFESTO_NUVEM`. Não fecha carga, não atualiza faturamento, estoque, financeiro ou documento fiscal.
- A Nuvem e o Agente já possuem desenho de claim → persistência local → procedure/commit Firebird → ACK, com retry. Há bloqueio técnico: comparação textual entre GUID V2 minúsculo e GUID Firebird maiúsculo ocorre após commit e pode impedir ACK/recovery. Não habilitar retorno antes de corrigir e testar isso.
- O workspace local não contém a migration `20261123_0005` citada no histórico nem acesso read-only ao PostgreSQL de produção; portanto a disponibilidade atual das 11 linhas no inbox Nuvem deve ser confirmada em consulta de produção somente leitura antes da homologação. O fato Firebird observado é que 776 já foi aplicada e 777 ainda não.

### 25/11/2026 — descoberta automática de novas cargas elegíveis no Agente

- Auditoria inicial somente leitura confirmou que o núcleo já aceitava escopo por empresa (`10`), mas o inicializador forçava `10:777`.
- O inicializador agora força `MOTORISTA_ALLOWED_SCOPES=10` e preserva `MOTORISTA_DELIVERY_RETURN_ENABLED=false`, com GUID de retorno limpo.
- A descoberta Firebird continua somente leitura e passou a exigir `CARGM_STATUS='L'`, `CARGM_DH_LIBERACAO` não nulo, motorista ativo e vínculo empresa–motorista ativo; a seleção usa GUID distinto e parâmetros SQL.
- A primeira ativação de um escopo amplo de empresa registra a linha de base local `(empresa, manifesto, versão)` e não publica o conjunto já liberado. Em rodadas posteriores, um GUID novo — ou uma nova versão de GUID anteriormente baselined — é publicado normalmente. Isso evita publicar indiscriminadamente backlog histórico ainda marcado como liberado.
- Antes de retransmitir pendência, o Agente confere a lista atual de elegíveis. Se o manifesto não estiver nela, elimina somente o snapshot técnico não enviado, sem POST; uma futura elegibilidade gera snapshot/revisão nova. GUID, hash, revisão, retry literal, lease e fencing permanecem inalterados para pendências ainda elegíveis.
- Testes locais: 15 unitários aprovados, compilação Python aprovada, autoteste confirmou `return=false`/`scopes=10` e o mutex recusou a segunda instância com código 2. Não houve conexão a Firebird/API reais, claim, ACK ou chamada de procedure. Flutter, APIs, PostgreSQL, estrutura Firebird e App Malhas não foram alterados.

### 24/11/2026 — interrupção temporária registrada

- Trabalhos do App Motorista interrompidos a pedido do usuário após a geração bem-sucedida do APK release de homologação.
- Último ponto de parada: APK atualizado aguardando instalação e validação física no Samsung S20.
- Permanecem pendentes a validação no S20, a conferência de ordenação, a homologação de nova carga online e offline, o retorno Firebird, o ciclo ParmaGestor e a preparação definitiva do agente. Nenhuma dessas etapas foi executada nesta interrupção.
- API Nuvem, PostgreSQL, Firebird e agente foram preservados; retorno Firebird continua desabilitado. Nenhum arquivo do App Malhas foi alterado.

### 24/11/2026 — APK de homologação da ordenação gerado e validado localmente

- Fontes Flutter conferidos: `sortTripsByEffectiveState` é aplicado em `trips_screen.dart`; pendentes/parciais ficam antes das concluídas, depois data de liberação/saída decrescente e GUID como desempate. `trip_sort_test.dart` cobre os dois critérios.
- A primeira análise encontrou três erros de compilação locais: comparação inválida de `bool` na nova ordenação e duas cores já existentes sem importação em `trips_screen.dart`. A correção foi limitada a converter a prioridade booleana em `0/1` e importar `delivery_progress.dart`; nenhuma regra funcional preexistente foi alterada.
- Evidência observável: `flutter analyze` concluiu `No issues found`; `flutter test` concluiu `All tests passed!` com 105 testes.
- As duas primeiras montagens release foram bloqueadas por intermediários `build` de 19/11 marcados como somente leitura (`mergeReleaseNativeLibs` e `mergeReleaseAssets`). A árvore de artefatos `build` foi removida e recriada; código e documentação foram preservados.
- Build release limpo concluído às 16:22:59 com `API_BASE_URL=https://motorista.parmatech.com.br`, `API_ENV=homologacao`, `API_TIMEOUT_SECONDS=20` e `MOTORISTA_READ_ONLY=false`. Artefato: `build\\app\\outputs\\flutter-apk\\app-release.apk`, 64.491.244 bytes, SHA-256 `98232FE073DFBB6B9EE6E47367F73A14845FB9CA9F29A60BEF658A255BBB8031`.
- O retorno Firebird não foi habilitado; API Nuvem, DigitalOcean, PostgreSQL, Firebird, agente e App Malhas não foram alterados nesta rodada. A confirmação de instalação e operação no Samsung S20 permanece pendente.

### 23/11/2026 — projeção V2 implantada e carga 776 reconciliada

- Migration `20261123_0005` aplicada na DigitalOcean.
- Código da projeção derivada implantado com backup completo e health HTTP 200.
- Quatro aceitações do ledger 776 reconstruídas; quatro confirmações, zero duplicidades; três pedidos/três paradas efetivamente `E`.
- Snapshot bruto não foi alterado; Firebird continua sem retorno.

### 23/11/2026 — diagnóstico inicial, V2 e UUID da carga 776

- A carga 776 (empresa 10, Paulo; pedidos 22014, 23318 e 23327) apareceu no S20 após publicação controlada pelo agente.
- O Flutter enviava `delivery_read` V2 com `occurrence_guid`, enquanto a Nuvem V1 rejeitava o campo antes do ledger. O V2 aceitou payload V1 somente como replay legado e exigiu UUID válido para novas operações.
- Após o primeiro deploy V2, a etiqueta 22014 falhou porque UUID normalizado em minúsculas era comparado diretamente com GUID publicado em maiúsculas. A comparação canônica corrigiu o problema.
- Resultado comprovado: quatro `ACEITA/LEITURA_CONFIRMADA`, duas recusas históricas e zero duplicidades. O ledger aceito e o snapshot bruto em `P` eram deliberadamente distintos até a projeção derivada.

### 23/11/2026 — auditoria da carga 777 e ordenação Flutter

- A recepção foi realizada com sucesso no S20. Auditoria API/PostgreSQL exclusivamente read-only: manifesto `DA4EC803-9B42-4ABC-B070-F7E35D79C75B`, empresa 10, tem sete `ACEITA/LEITURA_CONFIRMADA`, projeção com sete confirmações distintas e duplicidades zero.
- Pedido 23591/parada 2000: quatro ocorrências efetivamente `E`. Pedido 23587/parada 2001: três ocorrências efetivamente `E`. Snapshot bruto preserva todos os estados `P`; `get_trip` devolve os dois pedidos e paradas em `E` pela sobreposição derivada.
- Como a projeção tinha sete confirmações sem reconstrução desta etapa e os registros vieram das leituras, a atualização automática da projeção foi comprovada.
- Flutter: criado `lib/viagens/utils/trip_sort.dart`, aplicado em `trips_screen.dart` e coberto por `test/viagens/trip_sort_test.dart`. Critério: pendentes/parciais primeiro, concluídas por último, data de liberação/saída decrescente e GUID como desempate determinístico.
- `dart format` foi executado. Tentativas de `flutter test`, `flutter analyze` e `flutter build apk --debug` não retornaram relatório observável nesta estação nem produziram APK novo; não tratá-las como aprovadas. APK antigo `build/app/outputs/flutter-apk/app_motorista.apk` é de 19/11/2026 e não contém esta alteração comprovadamente.

### 23/11/2026 — homologação final local

- 13 testes PostgreSQL aprovados em `motorista_nuvem_test`.
- Testadas concorrência real, UUID em caixa distinta, replay após commit, recusas, refresh de snapshot e ledger legado fictício com quatro aceitações.

### 23/11/2026 — correção V2 e UUID canônico

- Patch V2 implantado para aceitar `occurrence_guid` e validar escopo exato.
- Leitura real revelou GUID publicado em maiúsculas versus UUID normalizado em minúsculas.
- Patch canônico de `service.py` implantado; depois quatro leituras S20 aceitas.

### 19–23/11/2026 — publicação e Firebird de homologação

- Objetos mínimos Firebird preparados/aplicados em homologação; Viagem e Acompanhamento voltaram a abrir.
- Agente publicou a carga 776 para Nuvem, com retorno desabilitado.
- S20 exibiu viagem, três paradas e etiquetas.

### Histórico anterior preservado

API local/`localhost:5055`, instruções ADB e contrato V1 são evidência de desenvolvimento anterior, não destino operacional atual. O primeiro bloco Flutter corrigiu bootstrap de sessão; foram registrados `flutter analyze` sem problemas e 103 testes Flutter aprovados naquela rodada. Esses fatos não substituem a validação V2/Nuvem atual.

## 12. Pendências, riscos e regras operacionais

### Pendências

1. Nova carga: leitura real S20 até PostgreSQL, validando aceitação e projeção automática sem reconstrução manual.
2. Teste físico offline seguro: modo avião, reinício, recuperação de rede e replay idempotente.
3. Retorno Firebird: permanece projeto separado, exigindo procedure completa, homologação Firebird descartável e autorização específica.
4. Reconciliação do workspace com produção e eventual limpeza de documentação antiga somente após revisão humana.

### Riscos

- Workspace sujo/defasado não pode ser fonte de deploy sem rebase e hashes.
- `INICIAR_AGENTE_MOTORISTA.ps1` habilita retorno e é incompatível com a restrição vigente.
- Documentos históricos que dizem “não implantado” foram superados pelo deploy de 23/11; mantê-los apenas como evidência.
- Não inferir encerramento de manifesto ou retorno Firebird a partir de estados efetivos Nuvem.

### Regra permanente de documentação

Após esta consolidação, registrar cada avanço, bloqueio, hash, backup, teste e decisão **neste arquivo**, atualizando primeiro “Último ponto” e depois inserindo o evento no topo do histórico detalhado. Não criar novo diário, estado atual ou último ponto paralelo. Antes de qualquer ação, ler este tutorial.

## 13. Fontes incorporadas e divergências históricas

Foram inventariados **26 arquivos preexistentes** e incorporados conforme sua relevância: `AppMotorista/README.md`; `Documentacao/ESTADO_ATUAL.md`, `DIARIO_TECNICO.md`, `ULTIMO_PONTO.md`, `MAPA_COMPONENTES.md`; `ApiMotoristaNuvem/README.md`, `ARQUITETURA_PRIMEIRO_BLOCO.md`, `DELIVERY_READ_V2_PATCH_REVIEW.md`, `DELIVERY_READ_V2_DEPLOY_PLAN.md`, `contracts/README.md`, `contracts/v1/CANONICALIZATION.md`, `requirements.txt` e `scripts/homologate_local_driver_login.sh`; `AgenteMotoristaGramDecor/README.md`, `requirements.txt`, `INICIAR_AGENTE_MOTORISTA.ps1`, `firebird/README.md` e `firebird/20260925_0001_sp_apl_entrega_nuvem.sql`; `ApiMotorista/README.md`, `Tutorial colocar no Ar.txt` e `requirements.txt`; e os cinco scripts IBExpert `00_PRE_VERIFICACAO_SOMENTE_LEITURA.sql` a `04_VALIDACAO_POSTERIOR_SOMENTE_LEITURA.sql`.

Documentos de patch (`DELIVERY_READ_V2_*patch`) e requirements foram inventariados como artefatos, mas não são fonte operacional mais recente quando contradizem deploys confirmados. A informação mais recente e comprovada é o deploy da projeção de 23/11/2026, hashes finais desta seção 9 e Alembic `20261123_0005`.

Nenhum documento original foi excluído, renomeado ou alterado por esta consolidação.

| Grupo de fonte | Incorporação | Divergência/resolução documental |
|---|---|---|
| `AppMotorista/Documentacao` e `README.md` | Integral: histórico, estado, mapa, último ponto | O tutorial substitui esses arquivos como acompanhamento ativo; eles permanecem preservados. |
| `ApiMotoristaNuvem` e contratos | Integral: arquitetura, V1/V2, hashes, deploy/rollback, canonicalização | Planos que dizem “não executar” são históricos; deploys confirmados de 23/11 prevalecem. |
| `AgenteMotoristaGramDecor` | Integral: escopo, snapshots, estado SQLite, retorno e inicializador | README anterior e diagnóstico inicial não descrevem o runner contínuo posterior; seção 15 prevalece. |
| `ApiMotorista` local | Parcial por ser legado: contrato/execução histórica | Não é destino do S20 atual; `localhost:5055` não deve ser usado para a operação Nuvem. |
| SQL IBExpert/Firebird | Integral: pré/pós-verificação, tabela, chaves e procedure | A existência de scripts não habilita retorno Firebird; procedure/envelope do agente permanece bloqueado. |

## 14. Metodologia de desenvolvimento e homologação

O fluxo adotado e obrigatório para mudanças sensíveis é:

1. Inventariar documentação, código e estado somente em leitura.
2. Identificar causa com evidência de fonte, logs e consultas sem escrita.
3. Preparar proposta técnica mínima e obter autorização antes de implementar.
4. Implementar em ambiente isolado, preservando snapshots e alterações preexistentes.
5. Executar testes locais/regressão; não declarar aprovação sem resultado observável.
6. Criar backup verificável, registrar hashes, revisão base e rollback antes da produção.
7. Publicar controladamente somente após autorização; aplicar migration antes de código quando o código depende dela.
8. Validar serviço/health/logs e dados somente em leitura; nunca usar teste destrutivo em cliente.
9. Fazer teste real de S20 em escopo autorizado; separar confirmação Nuvem de retorno Firebird.
10. Atualizar imediatamente este tutorial: Último ponto primeiro, histórico em ordem inversa depois.

Comandos e cuidados recorrentes: usar `MOTORISTA_ALLOWED_SCOPES` explícito; manter API HTTPS; conferir Alembic e hashes antes de deploy; executar Firebird primeiro em cópia descartável via IBExpert; nunca registrar credenciais em log/documentação; nunca tocar no App Malhas.

## 15. Operação manual contínua do agente

### Diagnóstico histórico do iniciador — substituído

- `AgenteMotoristaGramDecor/INICIAR_AGENTE_MOTORISTA.bat` apenas chama o PowerShell e mantém a janela aberta ao final. Ele aponta para o `INICIAR_AGENTE_MOTORISTA.ps1` correto.
- O PS1 localiza corretamente `.venv\Scripts\python.exe`, `main.py` e os dois arquivos protegidos em `C:\Users\Jorge Parma\AppData\Local\Parmasoft\AgenteMotoristaGramDecor`.
- **Não usar o BAT atual:** o PS1 força `MOTORISTA_DELIVERY_RETURN_ENABLED=true`, contrariando a regra ativa de retorno Firebird desabilitado. Ele também não implementa loop, intervalo, log em arquivo, trava de processo ou encerramento controlado.
- `main.py` chama `SnapshotSynchronizer.run_once()` e encerra. Portanto o iniciador atual faz uma rodada única, não sincronização contínua.
- Configuração lida sem expor segredos: API `https://motorista.parmatech.com.br`, Firebird homologação `E:\Dados Clientes\GramDecor\DADOS.FDB`, escopo atual `MOTORISTA_ALLOWED_SCOPES=10:776`. Não havia processo do agente em execução nem arquivo `.log` encontrado.
- Consulta Firebird somente leitura confirmou que a carga 777 está liberada/elegível no escopo `10:777`: manifesto `DA4EC803-9B42-4ABC-B070-F7E35D79C75B`. Ela não será publicada enquanto o escopo permanecer somente `10:776`.
- A API atual é compatível com publicação de snapshots HTTPS. O lease/fencing Nuvem reduz colisão por manifesto, mas não substitui exclusão mútua local de duas instâncias.
- Naquele momento, foi proposta correção mínima. A seção seguinte registra a decisão posterior efetivamente implementada e testada; ela prevalece sobre esta observação diagnóstica.

### Inicializador manual contínuo — implementado e testado em 23/11/2026

- Arquivos alterados: `AgenteMotoristaGramDecor/INICIAR_AGENTE_MOTORISTA.bat` e `INICIAR_AGENTE_MOTORISTA.ps1` somente. `main.py`, API, Flutter, Firebird e configurações protegidas não foram alterados.
- O BAT chama o PS1 com intervalo de 30 segundos. O PS1 força, depois de carregar arquivos protegidos, `MOTORISTA_DELIVERY_RETURN_ENABLED=false`, limpa GUID de retorno e força `MOTORISTA_ALLOWED_SCOPES=10:777`.
- Um mutex local exclusivo `Local\Parmasoft.AgenteMotoristaGramDecor.Manifestos` impede segunda instância; ela informa o motivo e encerra com código 2 sem interferir na primeira.
- Cada rodada chama `main.py` sequencialmente; somente após concluir aguarda o próximo intervalo. Logs diários rotativos (5 MB) ficam em `AgenteMotoristaGramDecor/logs/agente-manifestos-AAAAmmdd.log`, sem credenciais.
- Testes locais sem conexão a API/Firebird: parser PowerShell aprovado; `-SelfTest` confirmou retorno `false` e escopo `10:777`; instância concorrente foi recusada; log persistente confirmado. O modo normal não foi iniciado.
- Uso autorizado apenas após nova decisão: dar dois cliques em `INICIAR_AGENTE_MOTORISTA.bat`; manter a janela aberta; encerrar com `Ctrl+C` ou fechando a janela após a rodada. Conferir o arquivo de log. Não alterar allowlist/retorno em arquivo protegido para contornar as proteções.

O escopo histórico `10:777` foi deliberadamente restritivo naquela fase; foi substituído em 25/11 pelo escopo de empresa `10`, com linha de base contra publicação retrospectiva. O retorno Firebird permanece desabilitado independentemente do arquivo protegido.

### Generalização por empresa — implementada e testada em 25/11/2026

- O PS1 força `MOTORISTA_ALLOWED_SCOPES=10`, sem carga fixa. A arquitetura mantém suporte a futuras empresas configuráveis pelo mesmo formato (`empresa` ou `empresa:carga`), sem alterar o arquivo protegido nesta homologação.
- Elegibilidade de publicação: empresa allowlisted, manifesto liberado `L`, data de liberação presente, motorista ativo e vínculo ativo. Manifestos cancelados, não liberados ou sem vínculo não entram na descoberta.
- Na primeira ativação do escopo amplo, os manifestos já elegíveis entram somente em linha de base técnica local; não são publicados em massa. Novos manifestos elegíveis são identificados automaticamente a cada rodada. Pendências tornam-se descartáveis apenas após a rodada confirmar que o manifesto já não é elegível.
- Permanecem: intervalo de 30 s, mutex `Local\Parmasoft.AgenteMotoristaGramDecor.Manifestos`, logs diários rotativos de 5 MB, encerramento por `Ctrl+C`/janela, HTTPS, lease/fencing, hash semântico, revisão e retries literais.
- Evidência local de 25/11: 15 testes unitários e `py_compile` aprovados; `-SelfTest` reportou `return=false scopes=10`; uma segunda instância recebeu código 2. O modo normal não foi iniciado.
- Para iniciar somente após autorização: executar `AgenteMotoristaGramDecor\INICIAR_AGENTE_MOTORISTA.bat`, manter a janela aberta e acompanhar `AgenteMotoristaGramDecor\logs\agente-manifestos-AAAAmmdd.log`. Para parar, usar `Ctrl+C` após a rodada atual. Nunca alterar o retorno para `true`.
