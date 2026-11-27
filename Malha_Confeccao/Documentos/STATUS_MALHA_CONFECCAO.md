# Status consolidado — App de Malhas Confecção

## Atualização vigente — 28/10/2026

O estado vigente está consolidado em [CONSOLIDACAO_MALHAS_2026-10-28.md](CONSOLIDACAO_MALHAS_2026-10-28.md). O fluxo Flutter → HTTPS → PostgreSQL → Agente → Firebird → Painel Delphi foi comprovado em testes externos controlados; o pedido 26 foi auditado como **APROVADO COM RESSALVAS** pela ausência de UUID remoto direto no Firebird. Valores comerciais, ACK, processamento único e ausência de duplicidade foram confirmados.

O `BACKUP_MALHAS.bat` foi implementado e validado para integridade e extração, não para compilação restaurada. A próxima prioridade é somente o diagnóstico/plano offline-first: login offline seguro, catálogo SQLite e sincronização transacional. Não implementar sem nova autorização. O histórico abaixo permanece preservado.

**Data:** 23/10/2026  
**Escopo deste documento:** consolidação documental. Não altera código, banco, API, SQLite, scripts, configuração, serviços ou APK.

Os relatórios anteriores permanecem preservados. Para o diagnóstico de preços e o APK mais recente, consulte [CORRECAO_PRECOS_E_LAYOUT_20261023.md](CORRECAO_PRECOS_E_LAYOUT_20261023.md). Para o marco de retomada desta data, consulte [ULTIMO_PONTO_DE_PARADA_MALHA_CONFECCAO.md](ULTIMO_PONTO_DE_PARADA_MALHA_CONFECCAO.md).

## Estado funcional atual

O aplicativo Flutter possui login e catálogo pela API local autenticada, com empresa e vendedor derivados da sessão. A comunicação atual é de desenvolvimento local pela porta 5056, dependente de USB/ADB reverse; não há publicação externa, sincronização ou envio de pedidos.

- Novo Pedido: cliente oficial ou provisório, forma de pagamento, observações, prazo em dias corridos, previsão de entrega e seleção obrigatória de **Gerencial?** (Sim/Não).
- Itens: catálogo autorizado para o vendedor, unidades e quantidades inteiras ou fracionadas conforme a regra da unidade; preço unitário somente leitura, vindo de `TB_PRODUTO.PRD_PRECO_VENDA` pela API, subtotal e total calculados sem `float` financeiro.
- Carrinho: seleção e acúmulo do mesmo produto, edição de quantidade, exclusão confirmada com lixeira vermelha, totais quantitativos separados por unidade, total financeiro e bloqueio de salvamento quando houver preço indisponível.
- Pedidos locais: SQLite versão 4, múltiplos pedidos isolados por empresa/vendedor, recuperação ao reabrir, mensagem central temporária após salvar e retorno à Home; nenhum pedido é transmitido.
- Meus Pedidos: lista pedidos locais pendentes de envio, abre e atualiza o pedido correspondente. A seção de enviados permanece vazia até existir confirmação futura da API.
- Meus Clientes: consulta a mesma API usada em Novo Pedido, com pesquisa, estado de carregamento/erro/vazio e ficha somente leitura. A autorização da carteira é mantida no servidor.
- Novo Cliente: PF/PJ provisório local, validação de CPF/CNPJ e telefone, prevenção de duplicidade por empresa/vendedor e início de Novo Pedido com identificador local distinto do ID Firebird.

## Evidência e situação de homologação

| Situação | Evidência |
| --- | --- |
| Homologado no Samsung, conforme informado pelo usuário nas etapas anteriores | Carrinho local, salvamento SQLite com múltiplos pedidos e isolamento empresa/vendedor, confirmação central e retorno à Home, Meus Clientes (lista, pesquisa e ficha). |
| Implementado e coberto por testes automatizados | Cliente provisório, campos comerciais, migrações SQLite, preço/subtotal/total, bloqueio para preço ausente e preservação de pedidos anteriores. |
| Validação técnica concluída em 23/10 | API: 12 testes; Flutter: 13 testes; `flutter analyze` sem erros, com 22 avisos/informações preexistentes; APK debug gerado às 16:00. |
| Ainda requer nova homologação manual no Samsung | Correção da instância antiga da API, apresentação de preços, cálculos financeiros, novo layout de prazo/previsão e comportamento de pedidos antigos sem preço. |
| Não implementado | Envio, sincronização, recebimento por servidor, painel de recepção, conversão em Pedido de Venda, alteração Firebird e integração externa. |

## Preços: estado confirmado

Foi identificada uma instância antiga da API na porta local 5056. Após reinicialização, a rota `GET /api/v1/catalogo/produtos-touch` retornou `preco_unitario` como texto decimal para os produtos auditados, preservando o filtro de empresa da sessão. Valores nulos, negativos ou inválidos são declarados indisponíveis, sem substituição por R$ 0,00. O detalhamento e o roteiro de homologação estão no relatório de correção citado acima.

## Limites vigentes

- Não há gravação no Firebird, emissão fiscal, alteração no Delphi, integração externa ou envio de pedidos/clientes.
- Cliente provisório e pedido local ainda não possuem cadastro oficial na empresa.
- O servidor futuro deverá validar novamente produto, preço, autorização, empresa, vendedor e cliente; o aplicativo não é fonte de verdade comercial.

## Referências relacionadas

- [CONSOLIDACAO_DESENVOLVIMENTO_20261023.md](CONSOLIDACAO_DESENVOLVIMENTO_20261023.md)
- [IMPLEMENTACAO_CARRINHO_20261023.md](IMPLEMENTACAO_CARRINHO_20261023.md)
- [IMPLEMENTACAO_MEUS_PEDIDOS_20261023.md](IMPLEMENTACAO_MEUS_PEDIDOS_20261023.md)
- [IMPLEMENTACAO_MEUS_CLIENTES_20261023.md](IMPLEMENTACAO_MEUS_CLIENTES_20261023.md)
- [IMPLEMENTACAO_CLIENTE_PROVISORIO_20261023.md](IMPLEMENTACAO_CLIENTE_PROVISORIO_20261023.md)
- [CAMPOS_COMERCIAIS_MALHAS_20261023.md](CAMPOS_COMERCIAIS_MALHAS_20261023.md)

---

# Registro de encerramento — 24/10/2026

Este registro complementa — e não substitui — o histórico anterior deste documento. Reflete o desenvolvimento e as validações locais concluídas em 24/10/2026; não representa implantação externa nem homologação real pelo celular.

## Arquitetura definida

Fluxo de consultas de catálogo:

`Firebird → Agente Malhas → PostgreSQL Nuvem → API HTTPS → App Flutter`

Fluxo planejado de envio de pedidos:

`App Flutter/SQLite → API HTTPS → PostgreSQL Nuvem → Agente Malhas → quatro tabelas Firebird → Painel Delphi → confirmação ao aplicativo`

- O Firebird não será exposto à internet e o App utilizará exclusivamente HTTPS.
- O Agente Malhas é independente do Agente Motorista.
- A infraestrutura física já existente na DigitalOcean poderá ser compartilhada futuramente, mas Motorista mantém serviços, banco, credenciais e configurações isolados e preservados.
- Nenhuma implantação de Malhas foi realizada na DigitalOcean.

## Fotografia da DigitalOcean em 24/10/2026

Conforme auditoria registrada nesta data: droplet `parmasoft-cotacao` operacional, PostgreSQL 18.6, Nginx e HTTPS ativos, Motorista em `127.0.0.1:8091` com health HTTP 200, aproximadamente 13 GB livres em disco e 2,9 GB de memória disponível no momento da verificação. A revisão Alembic do Motorista era `20260925_0004`. Backups diários estavam em execução; destino, retenção e restauração ainda requerem confirmação. Outros serviços existentes devem ser preservados.

Estes dados são uma fotografia de 24/10/2026, não uma garantia permanente de capacidade ou disponibilidade.

## API Nuvem Malhas local

Local: `ApiMalhasNuvem`.

API Flask independente, com PostgreSQL/SQLAlchemy, Alembic próprio e configuração por variáveis de ambiente. Implementa autenticação de vendedores, sessões Bearer e renovação, permissões por empresa, recepção idempotente de pedidos por UUID e hash canônico, consultas de situação e estados de processamento.

Endpoints implementados:

- `GET /api/v1/health`
- `POST /api/v1/sessoes`
- `POST /api/v1/sessoes/renovar`
- `GET /api/v1/empresas`
- `POST /api/v1/pedidos`
- `GET /api/v1/pedidos`
- `GET /api/v1/pedidos/{id}`
- `POST /api/v1/agente/vendedores/snapshot`
- `POST /api/v1/agente/catalogo/snapshots`

Ainda não existem endpoints de `claim/ack` ou recepção de pedidos pelo Agente. Não existe implantação externa da API Malhas.

## PostgreSQL local de testes

- WSL `Ubuntu-24.04`; PostgreSQL 18.6; cluster `18/main`.
- Banco descartável: `malhas_nuvem_teste`.
- TCP local em `127.0.0.1:5432`, com SCRAM; acesso administrativo por socket local sob o usuário `postgres`, conforme configuração existente.
- Migrations aplicadas: `20261024_0001` (estrutura inicial) e `20261024_0002` (estado de sincronização do Agente). Versão Alembic final: `20261024_0002`.
- A primeira migration registrou 14 tabelas físicas, incluindo `alembic_version`, e 28 índices identificados na validação inicial. A segunda adicionou `malhas_agente_sync_state`.
- `alembic check` não apontou diferenças após a migration inicial. O banco foi preservado com dados fictícios de teste e nenhuma migration foi aplicada na DigitalOcean.

## Agente Malhas

Local: `AgenteMalhas`.

Aplicação Python independente, com leitura Firebird somente leitura e publicação técnica de vendedores/permissões, clientes autorizados, produtos/preços e formas de pagamento. Usa Bearer técnico exclusivo, digest HMAC de credenciais, SQLite técnico para revisão e snapshots pendentes, hash canônico, idempotência e reenvio após falha de comunicação.

A publicação de catálogo foi implementada e validada localmente. Isso não significa que o Agente esteja em operação na DigitalOcean nem que a integração completa com Firebird esteja homologada.

## Regra comercial permanente

**O pedido deve chegar ao ParmaGestor exatamente como foi feito pelo vendedor.**

Exemplo obrigatório: preço de R$ 13,90 no pedido permanece R$ 13,90 quando o catálogo for atualizado posteriormente para R$ 15,00. A sincronização não pode modificar ou recalcular preço unitário, quantidade, subtotal, total, forma/condições de pagamento, prazo, previsão de entrega, indicador gerencial, observações ou outras informações originais. Alteração posterior de catálogo não pode rejeitar automaticamente pedido existente.

Clientes provisórios não se tornam cadastros oficiais automaticamente.

## Histórico concluído preservado

Permanecem concluídos e não devem ser refeitos: Flutter com funcionamento offline e SQLite local; login; consultas de clientes e produtos; criação de pedidos; clientes provisórios; UUID e proteção contra duplicação; API Flask local; quatro tabelas Firebird de recepção criadas e testadas; e painel Delphi de recepção desenvolvido. O trabalho atual é a comunicação externa, sem auditoria, recriação ou alteração das quatro tabelas Firebird.

## Testes de 24/10/2026

| Etapa | Resultado consolidado |
| --- | --- |
| Etapa 1 | 4 testes locais da API aprovados; idempotência e preservação do payload validadas. |
| Etapa 2 | Migration inicial em PostgreSQL 18.6 local; 1 teste de integração PostgreSQL aprovado; alinhamento SQLAlchemy/Alembic confirmado. |
| Etapa 3 | 7 testes locais da API aprovados; 1 teste local do Agente aprovado; snapshots técnicos e recuperação de falhas implementados. |
| Etapa 3.1 | 2 testes de integração PostgreSQL aprovados e 1 teste do Agente aprovado. Bearer técnico, rejeição de token inválido, isolamento entre empresas, catálogo/permissões, idempotência e preservação de preço original validados. |

Também foram registrados o bootstrap corrigido de `migrations/env.py` e o uso de IDs fictícios únicos por execução no teste PostgreSQL, evitando colisão com dados de teste já existentes. Não houve teste externo real pelo celular.

## Pendências

### Agente — recepção de pedidos

- Implementar `claim/ack` na API Nuvem e recebimento de pedidos no Agente Malhas.
- Garantir idempotência no destino Firebird, preservar o pedido original e testar falha após gravação e antes do `ack`.
- Integrar o fluxo às quatro tabelas existentes e ao painel Delphi, sem recriá-los.

## Registro de implementação — 25/10/2026

Implementados localmente: endpoints técnicos `POST /api/v1/agente/pedidos/claim` e `POST /api/v1/agente/pedidos/{id}/ack`, protegidos pelo Bearer exclusivo do Agente; reserva atômica por empresa, expiração, tentativas, confirmação idempotente e isolamento por empresa, sem migration PostgreSQL; e no Agente Malhas, consulta/reserva, validação do payload original, gravação transacional em `TB_MALHA_PEDIDO_RECEBIDO`, `TB_MALHA_PEDIDO_RECEBIDO_ITEM`, `TB_MALHA_CLIENTE_PROV_REC` quando aplicável e `TB_MALHA_PEDIDO_EVENTO`, seguida de ack. A gravação não consulta catálogo nem recalcula valores comerciais; o vendedor de origem retornado pelo claim é preservado.

Testes: 10 testes locais da API aprovados (claim/ack, ack duplicado, expiração, isolamento e preservação de R$ 13,90) e 2 do Agente aprovados. Dois testes PostgreSQL foram ignorados porque `MALHAS_POSTGRES_TEST_URL` não foi configurada. Não houve escrita real no Firebird de testes nem observação no painel Delphi nesta execução, pois a conexão local de testes não foi configurada.

Próxima ação única: configurar o Firebird local de testes do Agente e executar um pedido ponta a ponta para confirmar a gravação e a visualização no painel Delphi, sem alterar tabelas ou dados comerciais existentes.

## Homologação local — Etapa 4.1 — 25/10/2026

### Evidências verificadas

- PostgreSQL local: `127.0.0.1:5432` respondeu como disponível. A consulta administrativa ao cluster não pôde ser concluída porque o usuário WSL atual não é role PostgreSQL e o acesso `sudo` ao usuário `postgres` exige senha não disponibilizada nesta execução.
- Não há `MALHAS_POSTGRES_TEST_URL`, `DATABASE_URL`, `MALHAS_TOKEN_HASH_SECRET`, nem variáveis `MALHAS_AGENT_*` ou `FB_*` no ambiente do processo atual.
- Não há arquivo de configuração do `ApiMalhasNuvem` ou do `AgenteMalhas` contendo essas credenciais. O único `.env` encontrado é de `api` legado e aponta para `E:\Dados Clientes\Tekno Prime\DADOS.FDB`; ele não foi usado, pois não foi identificado como banco de testes da Confecção.
- Os serviços Firebird 2.5 e 5.0 estão em execução, mas a porta 3050 não estava escutando no contexto da verificação e nenhum banco Firebird de testes da Confecção foi identificado por configuração existente.

### Resultado real

Os dois testes PostgreSQL permaneceram bloqueados por ausência da URL de conexão de testes. Não foi possível iniciar a API/Agente com credenciais técnicas existentes, verificar as quatro tabelas de recepção, gravar o pedido fictício, testar o reenvio após commit nem confirmar a tela Delphi. Nenhuma operação foi feita em banco operacional, nenhuma estrutura foi alterada e não há homologação declarada.

### Impedimento e próxima ação única

Disponibilizar no ambiente local, sem publicar credenciais em documentos, a configuração já autorizada para `MALHAS_POSTGRES_TEST_URL` e as variáveis `MALHAS_AGENT_*`/`FB_*` que apontem explicitamente para o Firebird de testes da Confecção. Com isso, executar os dois testes PostgreSQL e um pedido ponta a ponta controlado.

## Recuperação de configurações — Etapa 4.2 — 25/10/2026

### PostgreSQL recuperado

- O ambiente existente é `ApiMalhasNuvem/.venv-wsl-tests`, criado com Python 3.12 em WSL e contendo `psycopg`, SQLAlchemy e Alembic.
- O acesso que funcionou foi WSL `Ubuntu-24.04` iniciado diretamente como usuário Linux `postgres`, com conexão por socket Unix ao banco `malhas_nuvem_teste`; não foi usada senha TCP nem houve alteração de role, senha ou permissão.
- A consulta somente leitura confirmou a revisão `20261024_0002`.
- Com `MALHAS_POSTGRES_TEST_URL` apontando ao socket local, os dois testes de `tests.test_postgresql_integration` foram executados e aprovados: `test_agent_snapshots_on_postgresql_preserve_orders` e `test_postgresql_receipt_replay_conflict_status_and_original_values`.

### Agente e Firebird

- O Agente requer `MALHAS_AGENT_API_URL`, `MALHAS_AGENT_TOKEN`, `MALHAS_AGENT_EMPRESA_ID`, `MALHAS_AGENT_EMPRESA_NOME`, `FB_DATABASE`, `FB_USER` e `FB_PASSWORD`; a execução única é `python main.py --once`. O token é Bearer técnico pré-provisionado em `malhas_agente_credencial`; somente seu digest fica no banco, portanto não pode ser recuperado a partir da tabela.
- A consulta sem segredos ao PostgreSQL encontrou apenas empresas de teste e credenciais técnicas de testes anteriores; não existe empresa/credencial técnica identificada para a Confecção. Não foi gerado token novo.
- Firebird: `fbserver` está escutando em `0.0.0.0:3050`. O driver do Agente é `fdb` 2.x, compatível com a conexão documentada de Firebird 2.5. Ambos os serviços Firebird 2.5 e 5.0 estão instalados/ativos; a associação do processo da porta a um deles não foi confirmada.
- Candidatos documentais: `E:\Dados Clientes\GramDecor\DADOS.FDB` foi o banco local de testes validado em 21/10; `E:\Dados Clientes\Tekno Prime\DADOS.FDB` aparece no `.env` do projeto legado e está excluído para esta etapa; `E:\Dados Clientes\Fabri Tecidos\DADOS.FDB` aparece apenas como referência comentada externa. Não foi aberta conexão Firebird nem feita gravação.

### Próxima ação única

Definir explicitamente qual dos candidatos Firebird é o banco de testes autorizado da Confecção e fornecer ou configurar o token técnico já existente (ou autorizar formalmente seu provisionamento). Só então executar a homologação ponta a ponta.

## Correção do destino Firebird — 25/10/2026

O banco Firebird de desenvolvimento/testes autorizado para a Confecção é `E:\Dados Clientes\Tekno Prime\DADOS.FDB`. GramDecor e Fabri Tecidos não são destinos autorizados desta etapa.

- A configuração local existente confirmou conexão em modo somente leitura por `127.0.0.1:3050`, charset `ISO8859_1`, usando driver `fdb` 2.x. O processo `fbserver` está escutando na porta 3050.
- As quatro tabelas existentes foram confirmadas por metadados: `TB_MALHA_PEDIDO_RECEBIDO`, `TB_MALHA_PEDIDO_RECEBIDO_ITEM`, `TB_MALHA_CLIENTE_PROV_REC` e `TB_MALHA_PEDIDO_EVENTO`.
- O nome longo solicitado anteriormente, `TB_MALHA_CLIENTE_PROVISORIO_RECEBIDO`, não pode existir em Firebird 2.5 por exceder o limite de 31 caracteres. `TB_MALHA_CLIENTE_PROV_REC` é sua tabela efetiva e contém os campos de cliente provisório esperados pelo contrato.
- Os campos de cabeçalho, itens e evento consultados cobrem as inserções já implementadas no Agente, incluindo empresa, vendedor, UUID/origem, hash, valores, pagamento, prazo, previsão, gerencial, observação e evento. Nenhum DDL ou dado foi alterado.

Para executar o Agente ainda faltam somente as variáveis técnicas do Agente (`MALHAS_AGENT_API_URL`, `MALHAS_AGENT_TOKEN`, `MALHAS_AGENT_EMPRESA_ID`, `MALHAS_AGENT_EMPRESA_NOME`) e a configuração de ambiente `FB_*` equivalente à conexão Tekno Prime. O token não será provisionado sem autorização específica.

## Homologação local — Etapa 4.3 — 25/10/2026

### Configuração e credencial

- Empresa determinada por leitura do Firebird: `EMP_ID=1`, `TEKNO PRIME`, razão social `COMERCIAL LAUD LTDA`.
- Foi provisionada uma credencial Bearer exclusiva para o Agente somente no PostgreSQL `malhas_nuvem_teste`. O token foi gerado criptograficamente, o banco recebeu somente seu digest HMAC e token/segredo ficaram em variáveis do perfil local, fora do Git e fora deste relatório.
- A API local foi executada temporariamente no WSL em `127.0.0.1:5057`; o `claim` vazio confirmou a autenticação técnica.
- O Agente foi configurado com a conexão Firebird Tekno Prime e executado uma vez. O SQLite técnico foi movido para pasta temporária local fora do repositório, pois o caminho inicial não era gravável.

### Correções mínimas necessárias ao dado real

- A primeira leitura identificou clientes sem vendedor e vendedores sem login/senha. O Agente agora exclui da projeção clientes sem carteira e vendedores sem credenciais de tablet, conforme o contrato autenticável da API. Firebird não foi alterado.

### Pedido controlado e resultado

- Foi criado no PostgreSQL de testes um pedido explicitamente fictício, com UUID exclusivo, observação `HOMOLOGACAO ETAPA 4.3 - PEDIDO FICTICIO`, preço unitário/subtotal/total de R$ 13,90, empresa 1, vendedor 4, cliente 29, produto 4573 e forma de pagamento 1.
- O Agente realizou snapshot, claim, gravação e ack. No Firebird foram confirmados um cabeçalho `RECEBIDO`, um item e um evento `RECEBIDO`; foram preservados vendedor, pagamento, prazo 28, previsão 22/11/2026, indicador gerencial, observação e os R$ 13,90 originais.
- Após nova execução do Agente, a contagem por UUID no Firebird permaneceu em 1. No PostgreSQL, o pedido está `RECEBIDO_PARMAGESTOR`, tentativa 1 e processado.
- O painel Delphi não foi aberto nem alterado. Como o registro foi gravado com status `RECEBIDO` em `TB_MALHA_PEDIDO_RECEBIDO`, está disponível para conferência manual no painel de recepção existente.

### Próxima ação única

Abrir o painel Delphi de recepção no ambiente Tekno Prime e localizar o pedido pela observação de homologação/UUID para registrar a evidência visual. Depois, preparar somente a configuração HTTPS externa, sem publicar ainda.

## Preparação DigitalOcean — Etapa 5 — 25/10/2026

### Auditoria somente leitura

- Conforme confirmação do responsável nesta data, o pedido fictício da homologação foi visualizado no painel Delphi: 1 recebido/aguardando análise, vendedor 4, cliente de homologação, R$ 13,90 e situação `RECEBIDO`.
- Droplet `parmasoft-cotacao` ativo há 50 dias: disco de 24 GB com 13 GB livres e 2,9 GiB de memória disponível. A capacidade atual comporta uma API Flask pequena, sujeita a monitoramento após publicação.
- PostgreSQL 18-main está ativo e escuta somente em `127.0.0.1:5432`. Existem apenas o banco/role `motorista_nuvem` e os bancos/roles padrão; `malhas_nuvem` e sua role exclusiva ainda não existem.
- Nginx, Certbot e HTTPS estão ativos. Os certificados atuais pertencem somente a `financeiroapp.kozow.com`, `motorista.parmatech.com.br` e `nutridaia.freeddns.org`; não há hostname, vhost ou certificado Malhas.
- A porta `127.0.0.1:8091` pertence ao `api-motorista-nuvem.service`, isolado em `/opt/api-motorista-nuvem`, com ambiente próprio. A porta proposta `8092` não estava em escuta e está disponível no instante da auditoria.
- O backup Motorista usa `pg_dump` custom local em `/var/backups/api-motorista-nuvem/postgresql`, agendado diariamente às 03:15 UTC e removendo arquivos com mais de 7 dias. Há dumps recentes. Não foi identificada cópia externa, retenção adicional ou teste de restauração documentado.

### Prontidão da API Malhas

- A API possui configuração por ambiente, migrations Alembic, autenticação/sessões, Bearer técnico do Agente, health check e endpoints técnicos protegidos.
- Para produção ainda faltam itens indispensáveis: incluir/instalar Gunicorn como servidor WSGI de produção, configuração estruturada de logs e erro 500 sanitizado, arquivo de ambiente protegido, unit systemd, diretório/logs próprios, banco/role exclusivos e vhost/certificado Nginx próprios. HTTPS deve terminar no Nginx; Gunicorn deve ficar somente em localhost.

### Contratos Flutter — sem alteração

- A URL atual é `MALHA_API_BASE`, com padrão HTTP local `http://127.0.0.1:5056/api/v1`; é configurável por `dart-define`, mas não há URL HTTPS externa configurada.
- O código atual ainda chama endpoints do legado (`/pedidos-malhas/recepcao` e `/catalogo/...`) que não existem no contrato atual `ApiMalhasNuvem` (`/pedidos`, `/sessoes`, `/empresas` e endpoints técnicos). Também espera um recibo e campos de sessão diferentes.
- Não há renovação de sessão integrada, sincronização automática/segura da outbox offline nem consulta do status remoto pelo contrato Nuvem atual. Portanto o Flutter não está pronto para enviar pedidos pela internet sem uma etapa própria de alinhamento de contrato.

### Plano mínimo de implantação futura

1. Definir hostname DNS exclusivo Malhas e confirmar titularidade/propagação.
2. Criar banco `malhas_nuvem`, role e segredo independentes; aplicar Alembic somente nesse banco.
3. Criar `/opt/api-malhas-nuvem`, venv e arquivo de ambiente root-only; instalar dependências incluindo Gunicorn.
4. Criar unit `api-malhas-nuvem.service` em `127.0.0.1:8092`, logs separados e health check local.
5. Criar vhost Nginx e certificado exclusivos; validar HTTPS, headers, limites e ausência de exposição PostgreSQL/Firebird.
6. Criar backup Malhas separado, com retenção/destino aprovados e restauração testada em banco descartável.
7. Após alinhar o Flutter ao contrato Nuvem, testar Samsung → HTTPS → PostgreSQL → Agente → Tekno Prime → painel Delphi.

### Próxima ação única

Autorizar e definir o hostname DNS exclusivo da API Malhas. Sem hostname não é possível preparar de forma segura o vhost e o certificado HTTPS, e não há publicação autorizada ainda.

## Domínio e HTTPS — Etapa 5.1 — 25/10/2026

### DNS e droplet

- O documento solicitado `STATUS_APP_MOTORISTA_CARGA.md` não foi localizado. Foram usadas somente as configurações atuais auditadas do droplet e referências técnicas disponíveis do Motorista.
- A zona pública `parmatech.com.br` está delegada a `dns1`–`dns4.embradic.net`; a administração operacional da zona não pode ser determinada apenas pelo DNS.
- `motorista.parmatech.com.br` resolve para `165.227.77.226`, e a conexão SSH a esse IP confirmou o hostname remoto `parmasoft-cotacao`.
- `malhas.parmatech.com.br` não possui registro A resolvido nem resultado de pesquisa pública; não há conflito DNS conhecido.
- Registro necessário, ainda não criado: `A  malhas.parmatech.com.br  →  165.227.77.226`.

### Preparação local concluída

- Foram criados apenas templates locais em `ApiMalhasNuvem/deploy/`: unit Gunicorn em `127.0.0.1:8092`, ambiente sem segredos, vhost Nginx, template de backup e roteiro de rollback/implantação.
- Gunicorn foi adicionado às dependências e a API passou a devolver resposta 500 sanitizada. Os 10 testes locais da API passaram; os dois testes PostgreSQL permaneceram dependentes da URL de ambiente nesta execução.
- Nenhum template foi copiado ao droplet. Nenhum banco, role, DNS, Nginx, certificado, firewall, serviço ou recurso Motorista foi alterado.

### Pendências bloqueantes

1. Criar e propagar o registro DNS A acima, por administrador com acesso à zona Embradic.
2. Aprovar destino externo, retenção e teste de restauração para backup Malhas independente.
3. Autorizar explicitamente a criação dos recursos isolados no droplet após DNS válido.
4. Alinhar o Flutter ao contrato `ApiMalhasNuvem` antes do teste Samsung externo.

### Próxima ação única

Solicitar ao administrador da zona Embradic a criação do registro `A malhas.parmatech.com.br → 165.227.77.226` e retornar com a confirmação de propagação. Não criar esse registro sem autorização remota específica.

## Integração Flutter/API Nuvem — Etapa 6 — 25/10/2026

### Contratos adaptados

- API: foram adicionados endpoints autenticados e isolados por empresa/vendedor para `GET /api/v1/catalogo/clientes`, `GET /api/v1/catalogo/produtos` e `GET /api/v1/catalogo/formas-pagamento`. Não houve migration.
- Login agora retorna a empresa do vendedor. O Flutter passou a usar `/api/v1/pedidos`, interpreta o recibo Nuvem (`id`, `status`) e usa `/catalogo/produtos` em vez do endpoint legado.
- Sessão: access/refresh token, empresa e vendedor passaram a ser persistidos em `flutter_secure_storage`; há rotina de renovação por `/sessoes/renovar`. Nenhuma senha é salva em SQLite.
- Outbox: o UUID local é preservado, o identificador remoto da API é armazenado em nova coluna SQLite e timeout consulta `GET /pedidos` pelo UUID antes de marcar falha. O estado visual passou a dizer `Recebido pela API`, não ParmaGestor.
- Valores enviados são construídos sem `double` financeiro: quantidade em seis casas, preço/subtotal/total em escala decimal inteira de quatro casas.

### Correções e validação

- Foi adicionada migration SQLite versão 6 para `remote_order_id`, preservando os rascunhos existentes. O isolamento por empresa/vendedor continua no filtro e nas chaves do SQLite.
- API: 11 testes locais aprovados, incluindo catálogo autenticado/isolado, login, pedido idempotente, claim/ack e preservação de preço. Dois testes PostgreSQL dependem da variável de URL nesta execução.
- A obtenção/validação Flutter não produziu resultado conclusivo nesta sessão: processos Dart preexistentes permaneceram ativos e os comandos `flutter analyze`, `flutter test` e `dart format` não retornaram saída antes do limite. Não foi gerado APK.

### Pendências

- Validar compilação Flutter após normalizar os processos Dart locais e executar testes de integração do cliente HTTP/sessão/outbox.
- O aplicativo ainda precisa de uma etapa de UX para restauração automática de sessão e logout explícito; a infraestrutura segura de tokens foi preparada nesta etapa.

### Próxima ação única

Executar `flutter analyze` e `flutter test` em ambiente Flutter disponível; corrigir qualquer erro de compilação antes de gerar APK debug ou testar no Samsung.

## Validação Flutter/APK — Etapa 6.1 — 25/10/2026

- Os processos Dart identificados pertencem ao VS Code: language server, tooling daemon, DevTools e `flutter daemon` (PID 10500). Eles não foram encerrados.
- Foram encontrados e encerrados somente launchers `cmd.exe` órfãos, comprovadamente criados pelas tentativas de validação Malhas e presos em contenção do lock interno do Flutter.
- `flutter pub get` foi concluído pelo SDK Dart direto; `flutter_secure_storage` foi resolvido no lockfile. O formatador foi executado e aplicou mudanças apenas em `lib/main.dart` e `lib/local_draft_store.dart`.
- `flutter analyze` e `flutter test` continuam bloqueados pelo lockfile `E:\src\Flutter\bin\cache\lockfile`, mantido pelo daemon Flutter do VS Code. O usuário possui permissão de arquivo; não há erro de fonte Flutter diagnosticado nesta tentativa.
- Não foi gerado APK, pois os testes essenciais ainda não puderam ser executados. Não houve alteração em Samsung, Firebird, Delphi, Motorista, DigitalOcean ou DNS.

### Próxima ação única

Com autorização do responsável, reiniciar somente o daemon Flutter do VS Code (fechar/reabrir a janela do editor que o iniciou) e então executar, sequencialmente, `flutter analyze`, `flutter test` e `flutter build apk --debug` se todos passarem.

### Implantação DigitalOcean

- Confirmar dimensionamento, limites, destino/retenção/restauração de backups.
- Criar futuramente banco `malhas_nuvem`, role exclusiva, serviço próprio para a API, porta localhost independente (proposta `8092`, após confirmação) e hostname HTTPS ainda não definido.
- Criar vhost/certificado Nginx exclusivos e preservar integralmente o Motorista.

### App Flutter e teste externo

- Configurar URL HTTPS da API Malhas, validar login e catálogo pela internet e gerar APK para Samsung.
- Testar internet externa, pedido online, pedido offline com sincronização posterior e chegada ao painel Delphi.

---

# Validação Flutter/APK — Etapa 6.2 — 25/10/2026

- Foi confirmado que o PID 10500 era o `flutter daemon` iniciado pelo VS Code. A finalização controlada não concluiu por causa dos filhos; após a autorização, ele foi encerrado com sua árvore. O processo principal e as janelas do VS Code foram preservados.
- O lock residual do SDK só foi removido depois de confirmada a ausência de processo Flutter que o utilizasse. `flutter pub get` concluiu e o formatador foi aplicado somente aos arquivos da integração e ao mock de teste afetado.
- `flutter analyze` não apresentou erro de compilação, mas retornou código 1 por 31 avisos de lint. Dois avisos pertencem aos métodos de restauração/renovação de sessão preparados nesta etapa; os demais são avisos preexistentes de estilo, APIs Flutter depreciadas e declarações não usadas. Não houve refatoração fora do escopo.
- `flutter test` foi concluído com **13 testes aprovados e 0 falhas**. Foi corrigido apenas o mock `LocalDraftStore` para refletir o novo parâmetro `remoteOrderId` da integração.
- A geração de `flutter build apk --debug` foi tentada duas vezes. Ambas falharam em `:app:cleanMergeDebugAssets`: um processo externo mantém aberto `build\\app\\intermediates\\assets\\debug\\mergeDebugAssets`. Foram encerrados apenas um `dart format` Malhas comprovadamente travado e o daemon Gradle criado pela primeira tentativa; o VS Code permaneceu aberto. A segunda tentativa falhou no mesmo ponto.
- A consulta local de handles do Windows foi impedida por permissão (`openfiles`: acesso negado). Nenhuma pasta de build foi apagada manualmente, nenhum `flutter clean` foi executado e nenhum APK novo foi produzido.

### Próxima ação única

Liberar o handle externo sobre `build\\app\\intermediates\\assets\\debug\\mergeDebugAssets` (por exemplo, fechar a ferramenta que o estiver usando) e executar novamente `flutter build apk --debug`. Com o APK gerado, instalar manualmente no Samsung para homologação; a homologação no aparelho ainda não foi realizada.

---

# APK debug — Etapa 6.3 — 25/10/2026

- O utilitário oficial Microsoft Sysinternals Handle não encontrou handle aberto em `build\\app\\intermediates\\assets\\debug\\mergeDebugAssets`. Assim, não há evidência de bloqueio por Java, Gradle, Flutter, VS Code, Android Studio, Defender ou indexador.
- A causa confirmada foi atributo `ReadOnly` nos artefatos gerados: a raiz `build` e 1.465 itens descendentes estavam marcados como somente leitura. As permissões NTFS estavam corretas. Foi removido exclusivamente esse atributo dentro de `build`; nenhum código-fonte, dado local, arquivo em uso ou diretório fora de `build` foi alterado. Não houve `flutter clean` nem exclusão manual.
- Após a correção dos atributos, `flutter build apk --debug` foi concluído com sucesso em 133,1 s. Os avisos Java sobre source/target 8 obsoleto não impediram o build.
- APK atual: `E:\\Jorginho\\Malha_Confeccao\\build\\app\\outputs\\flutter-apk\\app-debug.apk`; gerado em 25/10/2026 às 16:42:30; 170.785.694 bytes; SHA-256 `56625B95B5D45B02B8EE8FB7375A2FCD49F6F5A86BFE1C2E64775FE176572962`.
- Metadados verificados: pacote `br.com.parmasoft.parma_gestor_malhas`, versão `0.1.0` (versionCode 1), minSdk 24, targetSdk 36. A assinatura é Android Debug (APK Signature Scheme v2), certificado SHA-256 `1a58367bccab491a3b756b818bdb0ca9eb3c2934ecd1171c930993fd7f80f7f0`.
- Nenhum dispositivo estava conectado via ADB. Portanto a compatibilidade da assinatura/pacote com o aplicativo atualmente instalado no Samsung não pôde ser comparada nesta máquina. O APK não foi instalado e nenhum dado SQLite foi tocado.

### Próxima ação única

Conectar o Samsung com depuração USB autorizada, consultar o pacote instalado `br.com.parmasoft.parma_gestor_malhas` e comparar assinatura/versão antes de instalar manualmente este APK debug. A homologação no aparelho permanece pendente.

---

# Encerramento consolidado — 25/10/2026

## Regras permanentes de trabalho

- Jorginho normalmente compila, instala, atualiza e testa o aplicativo Flutter no Samsung pelo procedimento habitual: conexão USB e `flutter run`. Quando necessário, também gera e instala APKs.
- Não solicitar ao Codex instalações por ADB sem necessidade ou autorização específica. O Codex responde por desenvolvimento, correções, testes automatizados, diagnósticos técnicos e documentação; a homologação visual e funcional no Samsung é responsabilidade de Jorginho.
- A conexão USB de desenvolvimento não se confunde com transmissão de pedidos pela internet. `adb reverse` é alternativa opcional para testes locais, não uma etapa obrigatória.
- Evitar procedimentos redundantes, não repetir validações já concluídas e avançar por etapas, sempre registrando evidências reais.

## Resultados confirmados

### API e integração local

- API Malhas Nuvem e PostgreSQL local validados; Agente Malhas autenticado e funcional.
- A recepção no Firebird Tekno Prime foi validada, com idempotência e preservação de valores comerciais.
- O painel Delphi exibiu o pedido fictício de R$ 13,90. Assim, o fluxo local API → PostgreSQL → Agente → Firebird → Delphi está homologado.
- Isto não homologa ainda o envio real pelo Samsung.

### Flutter — Etapa 6

- Login adaptado à API Nuvem; tokens armazenados com segurança; renovação de sessão preparada; empresa e vendedor autenticados.
- Contratos de clientes, produtos e formas de pagamento disponíveis; envio em `POST /api/v1/pedidos`; UUID original preservado e identificador remoto persistido.
- Timeout/reenvio tratados. Valores financeiros usam escala inteira; o estado visual diferencia `Recebido pela API` de `Recebido pelo ParmaGestor`.
- API: 11 testes locais aprovados na etapa correspondente. Flutter: 13 testes aprovados, sem falhas. `flutter analyze` não tem erro de compilação, mas mantém 31 avisos de lint não resolvidos.

### Compilação e Samsung

- O bloqueio inicial envolveu processos Dart/Flutter do VS Code. A falha posterior do Gradle decorreu de 1.465 itens `ReadOnly` em `build`; os atributos foram corrigidos exclusivamente nos artefatos gerados.
- APK debug gerado em 25/10/2026 às 16:42:30: 170.785.694 bytes; pacote `br.com.parmasoft.parma_gestor_malhas`; versão 0.1.0, versionCode 1; SHA-256 `56625B95B5D45B02B8EE8FB7375A2FCD49F6F5A86BFE1C2E64775FE176572962`.
- Samsung identificado por ADB. O pacote instalado, a versão e a assinatura correspondem ao novo APK; atualização por substituição preservando dados é tecnicamente possível.
- O novo APK não foi instalado. Jorginho fará a atualização pelo procedimento habitual quando necessário. Não desinstalar o aplicativo nem apagar SQLite. O teste real Samsung → API → Delphi permanece pendente.

## DigitalOcean e domínio

- Domínio aprovado: `malhas.parmatech.com.br`; servidor DigitalOcean: `165.227.77.226`; responsável pelo DNS: Marinho.
- Solicitação prevista/encaminhada: registro A, nome `malhas`, IP `165.227.77.226`, TTL 300 se disponível. Aguardar a confirmação do Marinho e comprovar a resolução DNS; não considerar DNS configurado antes disso.
- Arquitetura externa planejada: Flutter → HTTPS → Nginx → API Malhas Nuvem → PostgreSQL → Agente local → Firebird → Painel Delphi.
- A API Malhas deve permanecer isolada do Motorista. Preservar integralmente API, banco, serviço, Nginx/HTTPS e backups do Motorista. Reaproveitar os arquivos locais de implantação Malhas já preparados.
- Antes de publicar: banco e usuário PostgreSQL exclusivos, serviço próprio, porta interna 8092, Nginx/certificado HTTPS, segredos/autenticação, backup independente com destino externo, retenção, restauração testada, rollback e comunicação segura do Agente. Não implantar sem autorização.

## Integridade permanente

Preservar pedidos offline, UUID original, preços/totais e condições comerciais, prazo/data de entrega, indicador gerencial, observações, cliente/empresa/vendedor, idempotência e isolamento por empresa/vendedor. Atualizações de catálogo não podem alterar pedidos já criados. Não alterar as quatro tabelas Firebird de recepção homologadas.

## Estado final do dia

**Concluído:** fluxo local API → Delphi; adaptações principais Flutter; testes automatizados; geração do APK; conferência de compatibilidade com o Samsung.

**Pendente:** DNS; implantação HTTPS; backup externo e teste de restauração; configuração do aplicativo para API externa; homologação real Samsung → Delphi pela internet.

### Próxima ação única — 26/10/2026

Verificar a resposta do Marinho e o estado real do DNS antes de iniciar a implantação externa. Se o DNS ainda não estiver disponível, não improvisar uma implantação insegura; apenas revisar preparações locais que não alterem o servidor.

---

# Etapa 7.1 — Preparação local do Agente Malhas — 26/10/2026

Foram preparados, sem instalar tarefa, serviço, credencial ou aplicativo, os artefatos locais para operação automática futura no computador da recepção: `deploy/Start-AgenteMalhas.ps1`, `deploy/AgenteMalhas-TaskScheduler.xml.example`, `deploy/agente-malhas.env.example` e `deploy/OPERACAO_AGENTE_MALHAS.md`.

O Agente agora possui lock exclusivo por `state.db`, evitando duas instâncias da mesma configuração; logs rotativos locais sem tokens/senhas/payloads completos; parada controlada por arquivo de solicitação; e saída não zero em erro inesperado, permitindo reinício pelo Agendador. A tarefa-modelo inicia no boot, não depende do Delphi, executa sem janela e usa `IgnoreNew` mais lock de processo.

`MALHAS_AGENT_API_URL` passou a exigir HTTPS. HTTP foi limitado a loopback e somente com a variável explícita `MALHAS_AGENT_ALLOW_INSECURE_LOCAL_TESTS=1`; portanto não é possível transmitir token ou pedido para hostname externo em HTTP.

Foram executados `python -m unittest discover -s tests -v` e `python -m compileall -q agent main.py` em `AgenteMalhas`: 5 testes aprovados. Eles cobriram lock de instância, rejeição de HTTP externo, permissão explícita de teste local, recuperação de falha de comunicação, snapshots pendentes e preservação dos valores comerciais. Não houve internet, conexão/gravação Firebird, PostgreSQL, migration, DNS, DigitalOcean, Samsung ou alteração no Motorista.

Pendências para instalação futura: DNS/HTTPS válido, conta Windows dedicada, ACLs de `ProgramData`, credenciais autorizadas fora do Git, ambiente Python validado na conta de execução e teste controlado sem dados comerciais. O comportamento real contra internet, API externa e Firebird continua pendente e não foi declarado homologado.

### Próxima ação única

Aguardar a confirmação DNS e autorização específica para revisar a futura instalação controlada da tarefa no computador da recepção; não registrar/ativar a tarefa antes disso.

---

# Tentativa de publicação — 26/10/2026

O DNS foi confirmado às 07:59:56 -03:00: os resolvedores Google (`8.8.8.8`), Cloudflare (`1.1.1.1`) e padrão responderam o registro A `malhas.parmatech.com.br → 165.227.77.226`. Não houve resposta AAAA ou CNAME; isso não caracteriza falha DNS.

Foram executadas apenas verificações remotas de leitura. O droplet confirmou `api-motorista-nuvem.service` ativo, porta `127.0.0.1:8091` em uso pelo Motorista, PostgreSQL apenas em `127.0.0.1:5432`, porta `8092` livre, 13 GB disponíveis no disco raiz e somente os bancos padrão e `motorista_nuvem`. Não existem role/banco `malhas_nuvem`, unit `api-malhas-nuvem.service`, diretório `/opt/api-malhas-nuvem` ou vhost Nginx Malhas. Nenhuma alteração foi feita no droplet.

A publicação foi interrompida antes de criar recursos persistentes ou colocar a API em operação real, pois o destino externo e as credenciais do backup Malhas continuam indefinidos. O roteiro aprovado determina não inventar essa configuração nem publicar pedidos sem cópia recuperável. Não houve migration, emissão de certificado, alteração Nginx, PostgreSQL, Firebird, Motorista ou Samsung.

### Próxima ação única

Definir e autorizar o destino externo protegido e a credencial operacional de backup da Malhas, incluindo retenção e responsável pela restauração. Após isso, retomar pela criação isolada de role/banco Malhas e backup pré-migration.

---

# Publicação HTTPS controlada — 26/10/2026

Por autorização expressa para homologação controlada, a API Malhas foi publicada sem configurar backup externo e sem liberar operação comercial definitiva. Foram criados exclusivamente no droplet: role e banco PostgreSQL `malhas_nuvem`; ambiente protegido `/etc/api-malhas-nuvem.env` com `root:root`/`0600`; release `20261026T082500Z` em `/opt/api-malhas-nuvem/releases`; virtualenv próprio; serviço `api-malhas-nuvem.service`; e Gunicorn em `127.0.0.1:8092`.

A primeira execução revelou incompatibilidade de migrations: a revisão inicial criava `malhas_agente_sync_state` e a revisão `20261024_0002` tentava criá-la novamente. A transação foi revertida integralmente, deixando o banco novo sem tabelas e sem pedidos. A migration inicial foi corrigida para excluir essa tabela; a instalação foi retomada somente após confirmar o banco vazio. Revisão final comprovada: `20261024_0002`. Não houve downgrade, exclusão de banco ou alteração no Motorista.

O vhost HTTP temporário exclusivo foi validado antes da recarga Nginx, o certificado Let's Encrypt foi emitido para `malhas.parmatech.com.br` e o vhost HTTPS passou a manter a rota ACME para renovação. Certificado: CN `malhas.parmatech.com.br`, emissor Let's Encrypt `YE2`, válido até 24/01/2027; renovação automática configurada pelo Certbot. URL publicada: `https://malhas.parmatech.com.br/api/v1/health`.

Testes efetivamente aprovados no servidor: health local e HTTPS retornaram `{"status":"ok","servico":"api-malhas-nuvem","contrato":1}`; rota protegida `/api/v1/empresas` sem Bearer retornou `401`; `api-malhas-nuvem.service` e `api-motorista-nuvem.service` estão ativos; portas `8092`, `8091` e `5432` continuam apenas em localhost; logs Malhas sem erro posterior ao início. A validação independente a partir desta estação foi limitada por erro local do SChannel/proxy, mas não houve erro no teste HTTPS feito no droplet pelo hostname. Nenhum pedido, login real, token técnico, snapshot do Agente, Firebird, Delphi ou Samsung foi acionado.

Pendências: backup/recuperação permanece postergado por decisão do responsável; provisionar e armazenar fora do Git a credencial técnica do Agente, configurar as credenciais Firebird autorizadas no computador da recepção, publicar snapshots para criar vendedores e validar login real; configurar a URL HTTPS no Flutter; e Jorginho selecionar manualmente um pedido existente no S20. UUID e payload comercial não foram alterados.

### Próxima ação única

Configurar controladamente o Agente Malhas com `https://malhas.parmatech.com.br`, credencial técnica nova protegida e credenciais Firebird autorizadas; após validar snapshot/autenticação, Jorginho poderá testar manualmente um pedido existente no Samsung.

---

# Etapa 7.5 — Agente HTTPS e preparação Flutter — 26/10/2026

Foi provisionada uma credencial técnica exclusiva para o Agente Malhas conforme o contrato existente: somente o digest HMAC foi persistido em `malhas_agente_credencial`; o token bruto foi gerado criptograficamente, transferido pelo canal SSH para o provisionamento, removido do droplet e gravado apenas no arquivo protegido local `C:\ProgramData\ParmaSoft\AgenteMalhas\agente-malhas.env`. O arquivo está fora do Git e possui ACL restrita. Nenhum token, senha ou dado pessoal foi exibido.

O Agente foi configurado com `MALHAS_AGENT_API_URL=https://malhas.parmatech.com.br`, usando a conexão Firebird Tekno Prime já homologada. A tarefa agendada não foi instalada. Foi criado o virtualenv local previsto pelo inicializador; o driver `fdb` homologado do Python base foi reutilizado por `include-system-site-packages=true` porque o índice isolado não forneceu o pacote. Os 5 testes locais do Agente continuam aprovados.

Uma execução controlada `--once` concluiu: snapshot de vendedores e catálogo confirmados na revisão 1. Contagens reais no PostgreSQL após o snapshot: 1 empresa, 1 credencial técnica ativa, 3 vendedores, 134 clientes, 4 produtos, 22 formas de pagamento e 2 estados de sincronização. Há 0 pedidos na nuvem. Também foi validado login HTTPS com uma credencial de vendedor projetada pelo snapshot; login, senha e tokens não foram exibidos. Nenhum pedido foi criado, enviado, reservado ou gravado no Firebird.

O Flutter já aceita a URL pública por `dart-define`; o fonte e SQLite não foram alterados. Para a execução manual futura por Jorginho, usar na raiz Flutter: `flutter run --dart-define=MALHA_API_BASE=https://malhas.parmatech.com.br/api/v1`. Não instalar por ADB nem executar esse comando nesta etapa.

Para receber manualmente um pedido depois da autorização, iniciar o Agente sem `-Once`: `powershell -NoProfile -ExecutionPolicy Bypass -File E:\Jorginho\Malha_Confeccao\AgenteMalhas\deploy\Start-AgenteMalhas.ps1`. Ele fará polling/claim apenas após o pedido ser enviado manualmente pelo Samsung. UUID, snapshot e valores comerciais dos pedidos existentes permanecem inalterados.

### Próxima ação única

Jorginho executar manualmente o Flutter com o `dart-define` HTTPS, autenticar-se e selecionar um pedido existente no S20 somente após nova autorização explícita para o teste funcional ponta a ponta.
## Atualização operacional e visual — 26/10/2026

### Melhoria visual do carrinho — 27/10/2026

Na aba **Novo Pedido → Itens**, a inclusão local bem-sucedida agora exibe por aproximadamente dois segundos uma confirmação central, não bloqueante, com fundo branco, sombra suave, ícone verde e o texto **"Item adicionado ao carrinho!"**. A confirmação é criada somente após a atualização do carrinho; quantidades inválidas e falhas de validação mantêm o tratamento existente e não exibem sucesso. A quantidade continua sendo limpa e o produto permanece selecionado. Toques durante a inclusão em andamento são ignorados.

Foram atualizados `lib/main.dart` e `test/widget_test.dart`. A validação local prevista inclui o teste da confirmação, quantidade inválida, desaparecimento automático e `flutter analyze` nos arquivos envolvidos. Não houve alteração em SQLite, API, sincronização, cálculos, preços ou envio de pedidos; a homologação externa/manual permanece pendente conforme os registros vigentes abaixo.

### Correção de overflow e estado da validação — 27/10/2026

O resultado informado antes desta correção foi **7 testes aprovados e 8 falhos** em `flutter test test/widget_test.dart`. As falhas relacionadas à inclusão de itens apresentaram o mesmo erro de renderização: `RenderFlex overflowed by 179 pixels on the right` na confirmação visual do carrinho. A causa era a linha sem limite de largura no `OverlayEntry`, não uma alteração nas regras do carrinho, totais, rascunhos ou pedidos.

A confirmação foi ajustada para usar margem lateral, largura máxima e texto flexível em até duas linhas; o ícone verde, duração de aproximadamente dois segundos e comportamento não bloqueante foram preservados. Foram solicitadas novamente as execuções de `flutter test test/widget_test.dart` e `flutter analyze lib/main.dart test/widget_test.dart`, mas o conector desta sessão encerrou ambas sem retornar saída ou código de resultado. Portanto, esta correção **não é declarada validada** nesta documentação até que as duas execuções forneçam resultado observável.

Pendência objetiva: repetir os dois comandos no terminal Flutter e registrar a contagem final de testes e o resultado do analisador. Não houve alteração em API, SQLite, sincronização, preços, cálculos comerciais, autenticação ou integração Delphi.

### Fluxo homologado

Foi validado o fluxo completo **Samsung → Internet/HTTPS → API DigitalOcean →
PostgreSQL → Agente Malhas Windows → Firebird → Painel Delphi**. Os pedidos
enviados pelo aplicativo chegaram corretamente ao painel. Esta homologação
preserva UUID, empresa, vendedor, cliente, observações, prazos, indicador
gerencial, quantidades e valores comerciais originalmente registrados; a
sincronização não recalcula preços a partir do catálogo atual e mantém a
idempotência para não duplicar pedidos.

O Agente Malhas está configurado para iniciar automaticamente pelo Agendador de
Tarefas do Windows: tarefa `ParmaSoft - Agente Malhas`, conta
`NT AUTHORITY\SYSTEM`, gatilho no boot e execução independente de login. O
arquivo de ambiente permanece em
`C:\ProgramData\ParmaSoft\AgenteMalhas\agente-malhas.env`; os logs permanecem
em `C:\ProgramData\ParmaSoft\AgenteMalhas\logs`. A proteção contra instâncias
simultâneas continua ativa. O registro operacional desta data informa a tarefa
iniciada em estado `Running` e logs com sincronizações bem-sucedidas.

### Painel Delphi de recepção

O painel de recepção de Malhas foi validado visualmente em 26/10/2026, por volta
de 16h48, com sete pedidos recebidos, sete aguardando análise, nenhum cliente
provisório e nenhum pedido analisado. A tela possui cabeçalho compacto, lista à
esquerda, detalhes à direita, indicadores abaixo do grid e atualização discreta
a cada 15 segundos, preservando a seleção do pedido.

Nos detalhes, vendedor e forma de pagamento são descritos a partir dos cadastros
do ParmaGestor, respeitando a empresa corrente. Cliente, vendedor, pagamento,
gerencial, prazo e previsão usam cabeçalho compacto; os itens preservam a
descrição e os valores recebidos em formato quantidade × preço unitário =
subtotal, alinhados à direita. O Total Geral é destacado com separador duplo;
observações são preservadas; o histórico de eventos foi removido apenas da
apresentação. Os botões Aprovar e Rejeitar permanecem desabilitados no rodapé.

### Limite atual e próxima decisão

Receber um pedido não significa transformá-lo em Pedido de Venda. Não houve
alteração de estrutura Firebird, API, PostgreSQL, Flutter, Agente, protocolo de
sincronização ou App Motorista nesta atualização. A próxima prioridade, em
27/10/2026, é discutir com Jorginho o desenho da transformação de pedidos
recebidos em Pedidos de Venda, incluindo cliente provisório, prevenção de
duplicidade, identificação de pedidos já processados, situações e ações do
painel. Nenhuma implementação desse fluxo está autorizada antes dessa decisão.

Em paralelo, preparar somente o roteiro de teste/demonstração com a cliente:
conferir instalação, conectividade, autenticação e procedimento, sem publicar,
instalar ou alterar ambientes automaticamente.

## Auditoria de recuperação do Agente — 27/10/2026

Após a interrupção registrada às 14h20, o responsável iniciou manualmente o
Agente Malhas com o ambiente HTTPS protegido. Esta auditoria foi exclusivamente
de leitura e confirmou a recuperação dos quatro pedidos que estavam em
`RECEBIDO_NUVEM`, sem tentativas, na empresa 1.

| Firebird | UUID original (local) | UUID remoto (nuvem) | Cliente | Itens | Total nuvem / Firebird | Resultado |
| --- | --- | --- | --- | ---: | ---: | --- |
| 13 | `3c3eb1cc-e557-413c-8aef-532f3a0b2383` | `59d12b05-fafc-4b36-a586-e69f704b6f10` | ANA JÚLIA GONÇALVES CANDIAN | 1 | R$ 134,90 / R$ 134,90 | Conforme |
| 14 | `b6abe021-7502-4645-bb4a-782de991a29f` | `859074b2-7cfe-41e0-a1b1-8f6d164dd4a2` | ANA PAULA DIAS MARQUES | 1 | R$ 398,00 / R$ 398,00 | Conforme |
| 15 | `08586a0f-5725-48e1-8a8a-c73e29f642e1` | `4ab577e0-f04e-44dd-abfd-93fdfc3a9c25` | LUCIANA APARECIDA NOGUEIRA TEIXEIRA | 3 | R$ 12.397,38 / R$ 12.397,38 | Conforme |
| 16 | `c8a301f7-8f1c-4517-a92a-6fea4fd32dd5` | `bf6edb20-d0c4-4550-8db0-477e0c29757e` | ELAINE APARECIDA VIANA | 3 | R$ 18.066,45 / R$ 18.066,45 | Conforme |

- PostgreSQL: cada pedido fez exatamente um `CLAIMED` e um `ACK`, terminou em
  `RECEBIDO_PARMAGESTOR`, com `attempts = 1`, sem reserva ativa. O ACK retornou
  respectivamente os IDs Firebird 13, 14, 15 e 16. A fila da empresa 1 não
  possui pedido `RECEBIDO_NUVEM`, `CLAIMED` ou `REJEITADO_PARMAGESTOR`.
- Firebird: um cabeçalho por UUID/origem `FLUTTER`, sem duplicidade; um evento
  `RECEBIDO` por pedido; 1, 1, 3 e 3 itens, respectivamente. Empresa Tekno
  Prime; Isabella Silva Patricio nos pedidos 13–15 e Camilla Pires Duriguetto
  no 16. Não houve cliente provisório nesses quatro pedidos.
- A comparação de cliente, vendedor, forma de pagamento, prazo, previsão,
  gerencial, observações, produtos, unidade, quantidades, preços unitários,
  subtotais e totais não encontrou divergência. Os preços recebidos são os
  snapshots originais do payload: não há evidência de consulta ou recálculo
  pelo catálogo atual.
- Log do Agente: iniciado às 15:34:13; os quatro UUIDs foram confirmados entre
  15:34:16 e 15:34:19. As sincronizações posteriores de vendedores e catálogo
  continuaram normais; não foi encontrado novo erro depois da recuperação. O
  processo do Agente permanece em execução nesta verificação.

**Conclusão limitada às evidências:** o teste de recuperação após a interrupção
do Agente foi validado para os pedidos 13–16, do PostgreSQL ao Firebird e ao
painel informado pelo responsável. Esta auditoria não autoriza nem implementa
a conversão desses registros em Pedido de Venda. A pendência real permanece o
desenho e a autorização desse próximo fluxo.

---

## Encerramento documental — 27/10/2026

O relatório completo do dia está em
[RELATORIO_TRABALHOS_2026-10-27.md](RELATORIO_TRABALHOS_2026-10-27.md).

Foram registrados os ajustes localizados de interface e apresentação: confirmação
não bloqueante do carrinho; Login simplificado com ação do teclado; validação de
Cliente, pagamento, prazo e Gerencial antes de abrir Itens; contadores por
status; e pendentes antes de recebidos. Nenhum deles modifica API, SQLite,
sincronização, UUID, idempotência, preços ou estados persistidos.

Os testes Flutter mais recentes desta sessão não retornaram resultado observável
por bloqueio de processos Dart. Não devem ser declarados aprovados até nova
execução. A próxima ação é receber o vídeo do proprietário, demonstrar o app à
usuária e só então avaliar ajustes e um APK menor.

