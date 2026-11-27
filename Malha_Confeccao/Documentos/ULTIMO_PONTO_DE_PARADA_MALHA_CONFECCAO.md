# Último ponto de parada — App de Malhas Confecção

## Ponto de retomada vigente — 28/10/2026

Consultar primeiro [CONSOLIDACAO_MALHAS_2026-10-28.md](CONSOLIDACAO_MALHAS_2026-10-28.md).

- Fluxo externo comprovado pelo pedido 26; auditoria **APROVADA COM RESSALVAS** pela ausência de UUID remoto direto no Firebird.
- Backup automatizado validado para integridade e extração; compilação restaurada pendente por bloqueio/ausência de saída Flutter/Dart.
- Offline-first aprovado conceitualmente, mas não implementado.

**Próxima ação única:** retomar o diagnóstico técnico de login offline, SQLite e sincronização de catálogo. Não modificar Flutter, API, Agente, bancos, Firebird, Delphi ou o BAT de backup antes de autorização expressa para implementação.

O histórico abaixo permanece preservado.

**Data:** 23/10/2026  
**Natureza:** documentação e planejamento; nenhuma implementação foi realizada neste marco.

## Situação ao parar

O App de Malhas está avançado no fluxo local: catálogo autenticado, cliente oficial/provisório, pedido local SQLite, carrinho, preços cadastrados, prazo, gerencial e Meus Pedidos/Meus Clientes. A correção da API local para disponibilizar `preco_unitario` foi validada tecnicamente; a homologação atual no Samsung ainda é necessária antes de declarar o preço corrigido em produção de campo.

A auditoria do ParmaGestor identificou a recepção tradicional e definiu a direção arquitetural: **recepção independente para Malhas, com reaproveitamento somente da infraestrutura técnica e visual existente**. Não reutilizar diretamente as tabelas nem o fluxo comercial da recepção tradicional.

## Não fazer na retomada automática

- Não enviar nem sincronizar pedidos.
- Não criar ou executar DDL, scripts Firebird ou migrações.
- Não converter pedidos em Pedido de Venda.
- Não alterar API, Flutter, SQLite, Delphi ou os projetos de referência sem nova autorização.

## Próxima ação única recomendada

Preparar, **somente para revisão**, a proposta de DDL versionado para Firebird 2.5 das quatro tabelas exclusivas da recepção de Malhas:

1. `TB_MALHA_PEDIDO_RECEBIDO`
2. `TB_MALHA_PEDIDO_RECEBIDO_ITEM`
3. `TB_MALHA_CLIENTE_PROVISORIO_RECEBIDO`
4. `TB_MALHA_PEDIDO_EVENTO`

Essa proposta deve conter chaves, índices, geradores/triggers quando necessários e a restrição de idempotência, mas não deve ser executada. Antes de qualquer implantação consolidada, comparar o banco-alvo no IBExpert Database Comparer.

## Pré-condição operacional paralela

Antes de ampliar o uso comercial do aplicativo, instalar o APK debug atual no Samsung e homologar preço, subtotal, total, prazo/previsão e o bloqueio de preço indisponível, conforme [CORRECAO_PRECOS_E_LAYOUT_20261023.md](CORRECAO_PRECOS_E_LAYOUT_20261023.md).

## Referências

- [STATUS_MALHA_CONFECCAO.md](STATUS_MALHA_CONFECCAO.md)
- [CONSOLIDACAO_DESENVOLVIMENTO_20261023.md](CONSOLIDACAO_DESENVOLVIMENTO_20261023.md)
- `E:\PARMASOFT_INTEGRACAO\Documentos\ARQUITETURA_RECEPCAO_MALHAS_20261023.md`
- `E:\PARMASOFT_INTEGRACAO\Documentos\PROXIMAS_ETAPAS_RECEPCAO_MALHAS_20261023.md`

---

# Último ponto de parada — 24/10/2026, encerramento noturno

Este acréscimo preserva os pontos de parada anteriores.

## Estado confirmado

- API Malhas Nuvem implementada somente localmente.
- PostgreSQL descartável local funcionando, com migrations `20261024_0001` e `20261024_0002` aplicadas.
- Agente Malhas com publicação de catálogo implementada e validada em testes locais.
- Testes PostgreSQL de catálogo aprovados; autenticação técnica, isolamento por empresa e reenvio idempotente validados.
- Pedido original preservado: R$ 13,90 permanece R$ 13,90 após atualização posterior do catálogo para R$ 15,00.
- Nenhuma implantação de Malhas na DigitalOcean; Motorista permanece intocado.

## Próxima etapa única

Planejar e implementar **localmente** o recebimento de pedidos pelo Agente Malhas, com `claim/ack`, idempotência no destino e recuperação de falhas. Antes de implementar, examinar os contratos existentes e preparar proposta mínima, sem refazer ou auditar as quatro tabelas Firebird.

Não iniciar esta etapa automaticamente.

---

# Último ponto de parada — 25/10/2026

Foram implementados localmente endpoints técnicos de claim/ack e a recepção transacional no Agente Malhas para as tabelas Firebird existentes. Não houve migration PostgreSQL, alteração de Firebird, Delphi, Flutter, Motorista ou implantação DigitalOcean. Os testes unitários locais aprovaram reserva, expiração, ack idempotente, isolamento de empresa e preservação de R$ 13,90. A escrita real no Firebird de testes e a observação no painel Delphi permanecem pendentes, porque a conexão local de testes não foi configurada.

## Próxima ação única

Configurar o ambiente Firebird local de testes do Agente e executar um pedido ponta a ponta; confirmar no painel Delphi sem modificar sua implementação.

---

# Homologação local — Etapa 4.1 — 25/10/2026

A verificação encontrou PostgreSQL disponível em `127.0.0.1:5432`, mas não encontrou no ambiente atual a URL de testes `MALHAS_POSTGRES_TEST_URL` nem as configurações do ApiMalhasNuvem/AgenteMalhas. O acesso administrativo WSL ao PostgreSQL requer credencial não disponibilizada. O único `.env` local encontrado pertence ao projeto legado e aponta para banco Tekno Prime, que não foi utilizado.

Os serviços Firebird 2.5 e 5.0 estão ativos, porém não há configuração que identifique com segurança o banco de testes da Confecção; a porta 3050 não estava escutando no contexto da verificação. Os testes PostgreSQL, a escrita Firebird controlada, o reenvio e a conferência Delphi não foram executados. Nenhum banco ou estrutura foi alterado.

## Próxima ação única

Configurar no ambiente as credenciais já autorizadas de `MALHAS_POSTGRES_TEST_URL` e `MALHAS_AGENT_*`/`FB_*`, apontando explicitamente ao Firebird de testes da Confecção; em seguida executar a homologação ponta a ponta.

---

# Recuperação de configurações — Etapa 4.2 — 25/10/2026

O PostgreSQL foi recuperado sem recriação: WSL `Ubuntu-24.04`, usuário Linux `postgres`, socket Unix, banco `malhas_nuvem_teste`, Alembic `20261024_0002` e virtualenv existente `ApiMalhasNuvem/.venv-wsl-tests`. Os dois testes PostgreSQL existentes foram executados e aprovados.

Não há token técnico recuperável: a tabela armazena somente digest e o banco contém apenas empresas/credenciais de testes anteriores, não uma configuração identificada da Confecção. O Agente continua aguardando variáveis `MALHAS_AGENT_*` e `FB_*` autorizadas.

O Firebird escuta em `0.0.0.0:3050`. O banco `E:\Dados Clientes\GramDecor\DADOS.FDB` é o candidato documentado como teste validado; Tekno Prime está excluído e Fabri Tecidos é somente referência comentada. Nenhuma conexão ou escrita Firebird foi feita nesta etapa.

## Próxima ação única

O responsável deve indicar qual banco Firebird candidato é o banco de testes autorizado da Confecção e fornecer/configurar o token técnico existente, ou autorizar seu provisionamento. Depois disso, retomar a homologação ponta a ponta.

---

# Correção do banco Firebird — 25/10/2026

O destino correto e exclusivo para a homologação da Confecção é `E:\Dados Clientes\Tekno Prime\DADOS.FDB`. A conexão existente foi confirmada em modo somente leitura, por `127.0.0.1:3050`, charset `ISO8859_1` e driver `fdb` 2.x. O processo Firebird está escutando na porta 3050.

Foram confirmadas, sem alteração, as tabelas `TB_MALHA_PEDIDO_RECEBIDO`, `TB_MALHA_PEDIDO_RECEBIDO_ITEM`, `TB_MALHA_CLIENTE_PROV_REC` e `TB_MALHA_PEDIDO_EVENTO`. A tabela de cliente provisório usa a abreviação `TB_MALHA_CLIENTE_PROV_REC`, pois o nome longo excederia o limite de 31 caracteres do Firebird 2.5. Os metadados são compatíveis com o contrato de recepção implementado.

Não houve gravação. A única pendência para iniciar o pedido fictício controlado é configurar a credencial Bearer técnica já existente do Agente e as variáveis `MALHAS_AGENT_*`; não gerar token novo sem autorização.

## Próxima ação única

Fornecer/configurar o token técnico exclusivo já provisionado do Agente Malhas e os valores de empresa correspondentes; então executar a homologação de recepção no Tekno Prime.

---

# Homologação local — Etapa 4.3 — 25/10/2026

Foi criada, exclusivamente no PostgreSQL local de testes, uma credencial técnica do Agente para a empresa 1 — Tekno Prime. O banco recebeu somente o digest HMAC; token e segredo não foram registrados em documentos ou Git. A autenticação técnica foi confirmada por claim vazio na API local WSL.

O Agente publicou snapshots e processou um pedido fictício identificado por `HOMOLOGACAO ETAPA 4.3 - PEDIDO FICTICIO`. Ele foi gravado no Tekno Prime com cabeçalho, item e evento, preservando empresa, vendedor, pagamento, prazo, previsão, gerencial, observação e R$ 13,90. Após nova execução, a contagem no Firebird permaneceu em um registro; a API confirmou `RECEBIDO_PARMAGESTOR`.

Foram corrigidos somente filtros da projeção técnica para ignorar clientes sem vendedor e vendedores sem login/senha de tablet, dados que não atendiam ao contrato existente. Firebird, Delphi, Flutter, Motorista e estruturas não foram alterados.

O painel Delphi não foi aberto; o pedido está em `TB_MALHA_PEDIDO_RECEBIDO` com status `RECEBIDO`, pronto para conferência visual manual.

## Próxima ação única

Abrir o painel Delphi de recepção no Tekno Prime e localizar o pedido fictício por sua observação de homologação, sem alterar seu código.

---

# Preparação DigitalOcean — Etapa 5 — 25/10/2026

Foi concluída auditoria somente leitura do droplet `parmasoft-cotacao`. Há 13 GB livres e 2,9 GiB de memória disponível. PostgreSQL 18, Nginx e Certbot estão ativos; PostgreSQL está restrito a localhost. A porta 8092 estava livre. Não existem banco/role, serviço, diretório, hostname, vhost, certificado ou logs da Malhas.

O responsável confirmou a visualização do pedido fictício no painel Delphi em 25/10/2026: um pedido recebido/aguardando análise, vendedor 4, cliente de homologação, total R$ 13,90 e situação `RECEBIDO`.

O Motorista permanece isolado: `api-motorista-nuvem.service`, `/opt/api-motorista-nuvem`, ambiente próprio, banco/role `motorista_nuvem`, e porta `127.0.0.1:8091`. Nenhum desses recursos foi alterado. O backup Motorista é local, diário, custom `pg_dump`, com retenção de sete dias; não foi comprovada cópia externa ou restauração.

A API Malhas está funcional localmente, mas antes de publicação exige Gunicorn, logs/erro sanitizado, ambiente protegido, systemd e recursos remotos exclusivos. O Flutter não está apto ao teste externo: usa base local e endpoints/recibos legados incompatíveis com `ApiMalhasNuvem`; também não implementa renovação de sessão, outbox online ou status remoto no contrato atual.

## Próxima ação única

Definir e autorizar o hostname DNS exclusivo para a API Malhas. Depois disso, preparar — mas não publicar ainda — o plano de banco, serviço e HTTPS isolados.

---

# Domínio e HTTPS — Etapa 5.1 — 25/10/2026

O domínio aprovado é `malhas.parmatech.com.br`. A zona `parmatech.com.br` usa nameservers Embradic (`dns1`–`dns4.embradic.net`). O subdomínio Malhas ainda não resolve; o Motorista continua resolvendo para `165.227.77.226`, IP confirmado por SSH como o droplet `parmasoft-cotacao`.

O registro necessário, ainda não criado, é `A malhas.parmatech.com.br → 165.227.77.226`. O documento histórico do Motorista solicitado não foi localizado. Não houve alteração DNS ou remota.

Foram preparados localmente os templates de Gunicorn/systemd, ambiente protegido, Nginx, backup e rollback em `ApiMalhasNuvem/deploy/`. Gunicorn foi incluído nas dependências e a resposta 500 da API foi sanitizada; os testes locais da API passaram. Não existe publicação Malhas no droplet.

## Próxima ação única

Solicitar ao administrador da zona Embradic a criação do registro DNS A `malhas.parmatech.com.br → 165.227.77.226`; após propagação, pedir autorização explícita para criar os recursos isolados no droplet.

---

# Integração Flutter/API Nuvem — Etapa 6 — 25/10/2026

Foram alinhados os contratos mínimos: catálogo autenticado (clientes, produtos e pagamentos), login com empresa, pedido em `/api/v1/pedidos`, recibo Nuvem, tokens em armazenamento seguro, renovação de sessão e registro do UUID/identificador remoto no SQLite. O envio usa valores monetários em escala decimal, preservando conteúdo original e consultando o status remoto após timeout.

Não houve migration PostgreSQL, alteração Firebird, Delphi, Motorista, DNS ou implantação externa. A API aprovou 11 testes locais. A validação Flutter não foi concluída: processos Dart preexistentes impediram retorno de `flutter analyze`/`flutter test` nesta sessão; não foi gerado APK.

## Próxima ação única

Executar `flutter analyze` e `flutter test` em ambiente Flutter disponível e corrigir os resultados antes de gerar APK debug ou iniciar teste Samsung.

## Regras para a retomada

- Trabalhar exclusivamente no projeto Malhas; Motorista somente como referência em leitura.
- Não recriar as quatro tabelas Firebird nem alterar pedidos originais.
- Não implantar na DigitalOcean sem autorização explícita.
- Não avançar sem testes e validação; registrar cada etapa e o novo ponto de parada.
- Priorizar futuramente o teste real no Samsung, sem pular requisitos de segurança.

---

# Validação Flutter/APK — Etapa 6.1 — 25/10/2026

O bloqueio foi identificado: o daemon Flutter do VS Code (PID 10500) mantém o lock interno do SDK. Language server, tooling daemon e DevTools também pertencem ao editor; foram preservados. Somente processos `cmd.exe` órfãos iniciados pelas tentativas Malhas foram encerrados.

`flutter pub get` concluiu e resolveu `flutter_secure_storage`; o formatador aplicou alterações somente nos arquivos da Etapa 6. A análise e os testes não puderam iniciar porque o Flutter Tools não conseguiu abrir o lockfile mantido pelo daemon VS Code. Não há diagnóstico de erro de compilação e nenhum APK foi gerado.

## Próxima ação única

Com autorização, reiniciar o daemon Flutter do VS Code fechando/reabrindo a janela do editor correspondente; depois executar análise, testes e, se aprovados, APK debug.

---

# Ponto de parada — Etapa 6.2 — 25/10/2026

O daemon Flutter do VS Code identificado como PID 10500 foi reiniciado sem encerrar o VS Code. O ambiente foi liberado para `pub get`, formatação, análise e testes. O mock de teste compatível com `remoteOrderId` foi ajustado; `flutter test` passou com 13 testes e nenhuma falha.

`flutter analyze` não encontrou erro de compilação, mas retorna código 1 por 31 avisos de lint: dois da infraestrutura de sessão introduzida na Etapa 6 e os demais preexistentes. Não foram feitas refatorações para suprimir avisos não relacionados.

O APK debug não foi gerado. Duas tentativas de `flutter build apk --debug` pararam em `:app:cleanMergeDebugAssets` porque um handle externo manteve aberto `build\\app\\intermediates\\assets\\debug\\mergeDebugAssets`. Foram encerrados somente o formatador Dart Malhas que estava comprovadamente travado e o daemon Gradle criado pela primeira tentativa. A listagem de handles do Windows não está autorizada nesta sessão (`openfiles` retornou acesso negado). Não houve `flutter clean`, remoção manual de build, alteração de assinatura, instalação no Samsung ou modificações em Firebird, PostgreSQL, Delphi, Motorista, DNS ou DigitalOcean.

## Próxima ação única

Fechar ou identificar a ferramenta que mantém aberto o diretório de ativos de build e executar novamente `flutter build apk --debug`. Quando concluído, conferir o APK em `build\\app\\outputs\\flutter-apk\\app-debug.apk` e instalar manualmente no Samsung para o primeiro teste, sem declarar a homologação no aparelho antes dessa conferência.

---

# Ponto de parada — Etapa 6.3 — 25/10/2026

O bloqueio do Gradle foi resolvido. Não havia processo com handle aberto: o Handle oficial da Microsoft não retornou correspondência para o diretório. A causa foram atributos `ReadOnly` em toda a árvore de artefatos `build` (1.465 itens). O atributo foi removido exclusivamente de `E:\\Jorginho\\Malha_Confeccao\\build`, sem excluir arquivos, sem `flutter clean` e sem modificar código, SQLite, Firebird, PostgreSQL, Delphi, Motorista, DNS ou DigitalOcean.

`flutter build apk --debug` concluiu em 133,1 s. O APK atual é `E:\\Jorginho\\Malha_Confeccao\\build\\app\\outputs\\flutter-apk\\app-debug.apk`, gravado em 25/10/2026 às 16:42:30, com 170.785.694 bytes e SHA-256 `56625B95B5D45B02B8EE8FB7375A2FCD49F6F5A86BFE1C2E64775FE176572962`. O pacote é `br.com.parmasoft.parma_gestor_malhas`, versão 0.1.0 (versionCode 1), assinado com certificado Android Debug SHA-256 `1a58367bccab491a3b756b818bdb0ca9eb3c2934ecd1171c930993fd7f80f7f0`.

Não há dispositivo ADB conectado, portanto não foi possível comparar a assinatura deste APK com a instalação atual do Samsung. Nenhuma instalação ou desinstalação foi realizada; a homologação Samsung continua pendente.

## Próxima ação única

Conectar o Samsung por USB com depuração autorizada e consultar a versão/assinatura instalada do pacote `br.com.parmasoft.parma_gestor_malhas` antes de instalar manualmente o APK debug recém-gerado.

---

# Encerramento e ponto de retomada — 25/10/2026

## Estado confirmado

- O fluxo local API Malhas Nuvem → PostgreSQL → Agente Malhas → Firebird Tekno Prime → painel Delphi está homologado. O painel exibiu o pedido fictício de R$ 13,90; idempotência e preservação dos valores comerciais foram validadas.
- As adaptações principais Flutter foram concluídas: autenticação Nuvem, armazenamento seguro de tokens, renovação preparada, empresa/vendedor autenticados, catálogo, `POST /api/v1/pedidos`, UUID original, identificador remoto, timeout/reenvio e valores financeiros em escala inteira. API: 11 testes locais aprovados na etapa correspondente. Flutter: 13 testes aprovados, nenhuma falha. `flutter analyze` está sem erros de compilação e mantém 31 avisos de lint.
- O APK debug foi compilado com sucesso em 25/10/2026 às 16:42:30 após remover atributos `ReadOnly` somente dos artefatos gerados em `build`. Arquivo: `E:\\Jorginho\\Malha_Confeccao\\build\\app\\outputs\\flutter-apk\\app-debug.apk`; 170.785.694 bytes; SHA-256 `56625B95B5D45B02B8EE8FB7375A2FCD49F6F5A86BFE1C2E64775FE176572962`; pacote `br.com.parmasoft.parma_gestor_malhas`; versão 0.1.0, versionCode 1.
- O Samsung foi identificado via ADB. O pacote instalado e o novo APK possuem mesma versão e assinatura compatível; atualização por substituição preservando dados é tecnicamente possível. O APK não foi instalado, não houve desinstalação e o SQLite não foi alterado.
- Jorginho normalmente realiza a compilação, atualização, instalação e teste no Samsung pelo procedimento USB/`flutter run` ou, quando necessário, por APK. O Codex não deve instalar por ADB sem necessidade e autorização específica. A homologação visual/funcional no aparelho é de Jorginho. USB de desenvolvimento não é transmissão pela internet; `adb reverse` é opcional para testes locais.

## Pendências externas e regras de implantação

- Domínio aprovado: `malhas.parmatech.com.br`; DigitalOcean: `165.227.77.226`; Marinho é responsável pela configuração DNS. Aguardar confirmação do registro A `malhas` → `165.227.77.226` (TTL 300, se disponível) e comprovar resolução antes de qualquer implantação.
- A arquitetura externa planejada é Flutter → HTTPS → Nginx → API Malhas Nuvem → PostgreSQL → Agente local → Firebird → Painel Delphi. A Malhas permanecerá isolada do Motorista, preservando API, banco, serviço, Nginx/HTTPS e backups existentes.
- Antes de publicar, validar banco/usuário exclusivos, serviço próprio, porta 8092, Nginx/certificado, segredos, backup independente com destino externo, retenção, restauração, rollback e comunicação segura do Agente. Não implantar sem autorização.
- Preservar permanentemente pedidos offline, UUID, preços/totais, condições comerciais, prazos, observações, cliente/empresa/vendedor, idempotência e isolamento. Catálogo não pode alterar pedidos existentes. Não modificar as quatro tabelas Firebird homologadas.

## Estado final

**Concluído:** fluxo local API → Delphi; adaptações Flutter; testes automatizados; APK debug; compatibilidade técnica com o Samsung.

**Pendente:** DNS; HTTPS/implantação externa; backup externo e restauração; URL externa no Flutter; homologação real Samsung → Delphi pela internet.

## Primeira ação de 26/10/2026

**Verificar a resposta do Marinho e o estado real do DNS antes de iniciar a implantação externa.**

Sequência posterior, somente após DNS confirmado e autorização: revisar implantação/backup/segurança; publicar isoladamente; validar HTTPS, autenticação, catálogo e endpoints; validar Agente com API externa; preparar URL HTTPS no Flutter; Jorginho atualizará/testará o Samsung; criar pedido real de homologação pela internet; confirmar API, PostgreSQL, Agente, Firebird e Delphi; validar valores, UUID, status e ausência de duplicidade; registrar evidências antes de declarar homologação ponta a ponta.

---

# Ponto de parada — Etapa 7.1 — 26/10/2026

O Agente Malhas foi preparado localmente para futura execução automática no computador Windows da recepção, sem instalar ou registrar a tarefa. Foram adicionados modelos do Agendador de Tarefas, inicializador PowerShell, ambiente sem segredos e manual operacional. O modelo usa gatilho de inicialização do computador, execução independente do Delphi, janela oculta, prevenção de nova instância e reinício após falha.

O código operacional ganhou lock exclusivo associado ao `state.db`, logs rotativos, parada controlada por arquivo e tratamento de saída para que erros inesperados possam ser supervisionados pelo Agendador. A configuração agora bloqueia HTTP para host externo: HTTPS é obrigatório; HTTP só é aceito em `localhost`/loopback com consentimento explícito de teste local. A recepção mantém commit antes do ACK, idempotência pela chave Firebird existente e preservação do payload comercial original.

Validação local executada: `python -m unittest discover -s tests -v` com 5 testes aprovados e `python -m compileall -q agent main.py` sem erro. Não foi iniciado o Agente com configuração real, não houve chamada de rede, conexão ou escrita Firebird, mudança PostgreSQL, migration, tarefa agendada, serviço, DigitalOcean, DNS, Samsung ou Motorista.

## Próxima ação única

Aguardar DNS válido e autorização para instalação controlada. Antes de registrar a tarefa, definir conta Windows dedicada, permissões de acesso ao Firebird e ACLs do arquivo de ambiente, estado e logs; preencher segredos somente fora do Git.

---

# Ponto de parada — tentativa de publicação — 26/10/2026

DNS confirmado por Google, Cloudflare e resolvedor padrão para `165.227.77.226`. A verificação rápida, somente leitura, do droplet confirmou Motorista ativo em `127.0.0.1:8091`, PostgreSQL restrito a localhost, `8092` livre e 13 GB de espaço disponível. Não há recursos Malhas remotos existentes: banco/role, aplicação, unit systemd e vhost Nginx estão ausentes.

Nenhuma publicação foi realizada. A execução foi interrompida antes de criar dados persistentes, migrations ou serviço, porque destino externo e credenciais do backup Malhas não foram definidos/aprovados. Pela regra da publicação, esses itens não podem ser inventados e a API não pode entrar em operação real com pedidos sem cópia recuperável. Motorista, Firebird, PostgreSQL existente, Nginx, DNS e Samsung permanecem sem alteração.

## Próxima ação única

Obter a definição e autorização do backup externo Malhas — destino, credencial protegida, retenção, responsável e critério de restauração — antes de retomar a publicação pelo banco exclusivo e backup pré-migration.

---

# Ponto de parada — publicação HTTPS controlada — 26/10/2026

A API Malhas está publicada em `https://malhas.parmatech.com.br/api/v1/health`. Recursos criados somente para Malhas: role/banco `malhas_nuvem`, `/opt/api-malhas-nuvem`, release `20261026T082500Z`, virtualenv, `/etc/api-malhas-nuvem.env` protegido, service systemd e Gunicorn em `127.0.0.1:8092`. A revisão Alembic comprovada é `20261024_0002`.

Durante a primeira migration foi identificado que a revisão inicial criava `malhas_agente_sync_state`, duplicada na revisão `0002`. A falha reverteu a transação inteira no banco novo; não havia tabelas, `alembic_version` ou pedidos. A migration inicial foi corrigida e a instalação retomada somente após verificar o banco vazio. Não houve downgrade nem exclusão de dados.

Foi ativado primeiro vhost HTTP exclusivo para ACME, emitido certificado Let's Encrypt válido até 24/01/2027 e ativado proxy HTTPS para `127.0.0.1:8092`, preservando rota ACME para renovação. Health local/HTTPS aprovado; rota autenticada sem Bearer retornou 401. `api-malhas-nuvem.service` e `api-motorista-nuvem.service` estão ativos; Motorista segue em `127.0.0.1:8091`, PostgreSQL em `127.0.0.1:5432` e não há exposição de Firebird.

Não houve pedido novo, login real, configuração de token técnico, acionamento do Agente, escrita Firebird, alteração Delphi, Samsung ou Motorista. A homologação ponta a ponta ainda não existe. Backup e recuperação permanecem pendentes por decisão explícita desta etapa.

## Próxima ação única

Provisionar de forma controlada a credencial técnica exclusiva do Agente, armazená-la fora do Git no computador da recepção junto das credenciais Firebird autorizadas e executar apenas o primeiro snapshot autenticado. Só depois Jorginho escolherá manualmente um pedido existente no S20 para a homologação.

---

# Ponto de parada — Etapa 7.5 — 26/10/2026

O Agente Malhas autenticou na API HTTPS publicada. A credencial técnica exclusiva foi provisionada na empresa Tekno Prime; somente seu digest HMAC está no PostgreSQL, e o token bruto está exclusivamente no arquivo de ambiente protegido em `C:\ProgramData\ParmaSoft\AgenteMalhas`, fora do Git. Não foi instalada tarefa agendada.

O snapshot manual controlado foi concluído sem escrita Firebird: vendedores e catálogo na revisão 1. PostgreSQL confirmou 3 vendedores, 134 clientes, 4 produtos, 22 formas de pagamento, 2 registros de estado de sincronização e zero pedidos. Um login HTTPS real com vendedor projetado foi validado sem imprimir credenciais ou tokens. Não houve pedido novo, envio Samsung, claim, ack, alteração SQLite, Firebird ou Delphi.

O Flutter já usa `MALHA_API_BASE` por `dart-define`. A configuração futura é `https://malhas.parmatech.com.br/api/v1`; executar manualmente `flutter run --dart-define=MALHA_API_BASE=https://malhas.parmatech.com.br/api/v1`. Para recepção futura, iniciar manualmente o Agente pelo `Start-AgenteMalhas.ps1` sem `-Once`; não o iniciar antes da autorização para o teste funcional.

## Próxima ação única

Aguardar autorização explícita para Jorginho executar o Flutter no S20, autenticar-se e selecionar manualmente um pedido existente. O Codex não deve instalar APK, operar o aparelho ou reenviar pedidos automaticamente.
---

# Encerramento do dia e ponto de retomada — 26/10/2026

## Estado confirmado

- O fluxo Samsung → Internet/HTTPS → API DigitalOcean → PostgreSQL → Agente
  Malhas Windows → Firebird → Painel Delphi foi validado. Pedidos do aplicativo
  chegaram corretamente ao painel, mantendo os snapshots comerciais originais,
  a idempotência e o isolamento por empresa.
- O Agente está configurado no Agendador de Tarefas como `ParmaSoft - Agente
  Malhas`, executado por `NT AUTHORITY\SYSTEM` no boot, sem depender de login.
  O ambiente protegido permanece em
  `C:\ProgramData\ParmaSoft\AgenteMalhas\agente-malhas.env` e os logs em
  `C:\ProgramData\ParmaSoft\AgenteMalhas\logs`. O registro operacional desta
  data confirma estado `Running` e sincronizações bem-sucedidas. Não reiniciar
  ou alterar o Agente nesta retomada documental.
- O painel Delphi está visualmente aprovado até o separador duplo do Total
  Geral. Em aproximadamente 16h48, apresentou sete pedidos recebidos e
  aguardando análise, zero clientes provisórios e zero pedidos analisados.
  Atualiza a cada 15 segundos sem perder seleção; exibe vendedor e pagamento
  pelos cadastros do ParmaGestor, itens em formato compacto, valores alinhados,
  observações preservadas e ações ainda desabilitadas no rodapé.

## Regras preservadas

Valores, quantidades, condições, prazos, observações e totais recebidos do
vendedor são snapshots e não podem ser recalculados pelo catálogo atual. A
recepção não cria Pedido de Venda. Não houve nem está autorizada nesta etapa
alteração de banco, API, PostgreSQL, Firebird, estrutura de sincronização ou
App Motorista.

## Retomada em 27/10/2026

1. Conversar com Jorginho e definir antes de codificar: transformação em Pedido
   de Venda, aproveitamento do snapshot original, tratamento de cliente
   provisório, idempotência, identificação de pedidos processados, situações e
   ações disponíveis no painel.
2. Preparar o roteiro de teste/demonstração com a cliente, conferindo
   instalação, conectividade, autenticação e procedimento. Não instalar,
   publicar ou modificar ambientes automaticamente.

**Ponto exato de retomada:** discutir e projetar a transformação dos pedidos
recebidos em Pedidos de Venda. Não iniciar implementação até nova orientação.

## Atualização — recuperação auditada em 27/10/2026

O Agente Malhas foi iniciado manualmente pelo responsável após a interrupção de
14h20. A auditoria somente de leitura confirmou o processamento correto dos
quatro pedidos antes pendentes: Firebird 13 (Ana Júlia, R$ 134,90), 14 (Ana
Paula, R$ 398,00), 15 (Luciana, R$ 12.397,38) e 16 (Elaine, R$ 18.066,45).

Cada UUID local corresponde a um único UUID remoto, um único cabeçalho e um
único evento `RECEBIDO` no Firebird; os itens, quantidades, unidades, preços,
subtotais, totais e condições comerciais coincidem com os snapshots da nuvem.
Na DigitalOcean, os quatro pedidos têm uma tentativa, `CLAIMED` seguido de
`ACK`, estado final `RECEBIDO_PARMAGESTOR` e IDs Firebird 13–16. A fila da
empresa 1 não possui pedido pendente, reservado ou rejeitado. O log confirma
os quatro ACKs entre 15:34:16 e 15:34:19, sem novo erro, e o processo do
Agente permanecia ativo na auditoria.

**Pendência real:** definir e autorizar, antes de qualquer código, a futura
transformação de pedidos recebidos em Pedido de Venda. Não alterar integração,
Agente, bancos ou painel apenas com base nesta auditoria.

---

# Ponto de parada — encerramento de 27/10/2026

Consultar [RELATORIO_TRABALHOS_2026-10-27.md](RELATORIO_TRABALHOS_2026-10-27.md)
para a cronologia, auditorias e limitações de validação.

- A recuperação dos pedidos Firebird 13–16 permanece confirmada por auditoria
  de leitura, sem duplicidade e com snapshots comerciais preservados.
- Login e Novo Pedido receberam os ajustes visuais aprovados pelo proprietário;
  Meus Pedidos classifica contadores por status e lista pendentes antes de
  recebidos sem mudar dados persistidos.
- `flutter analyze` e `flutter test` não retornaram saída nesta sessão devido a
  bloqueio de processos Dart; não há validação automatizada final a declarar.

## Próxima ação única — 28/10/2026

Receber o vídeo do proprietário para avaliação visual e funcional. Depois,
demonstrar o aplicativo à usuária e registrar somente os ajustes necessários.
Avaliar APK menor posteriormente, incluindo arquitetura, release, assinatura e
preservação dos dados locais.

