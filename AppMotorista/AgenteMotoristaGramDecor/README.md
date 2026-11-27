# AgenteMotoristaGramDecor - publicador somente leitura

## Status de homologação — 19/11/2026

O agente é a ponte controlada entre o Firebird de homologação e a API oficial
em nuvem `https://motorista.parmatech.com.br` (PostgreSQL). Ele não é um
serviço automatizado de execução contínua nesta fase.

Foi realizada uma rodada única controlada para sincronizar a identidade de
Paulo Henrique Gonçalves, empresa 10, transportador 22, Motorista App ID 1,
usando `E:\Dados Clientes\GramDecor\DADOS.FDB`. O retorno de entregas ficou
desabilitado e não deve ser habilitado até a homologação segura do caminho de
retorno no Firebird.

Para uma carga aparecer no app, o manifesto canônico deve estar liberado (`L`)
para o motorista e o agente deve publicar o snapshot na nuvem. A carga 776 foi
gerada, mas nesta data não foram consultados o status efetivo `G/L`, os
vínculos de liberação ou a confirmação de publicação; nenhuma execução do
agente foi feita para essa carga.

O retorno ao Firebird permanece bloqueado também pela ausência, no banco de
homologação, de `TB_CARGA_MANIFESTO_NUVEM` e `SP_APL_ENTREGA_NUVEM`. O arquivo
`firebird/20260925_0001_sp_apl_entrega_nuvem.sql` é deliberadamente apenas um
envelope de contrato, sem corpo validado, e não pode ser usado isoladamente
como migration.

Primeiro bloco local da ponte para a nuvem. A descoberta usa uma transacao curta read-only;
cada Manifesto e materializado em uma transacao Firebird curta `SNAPSHOT/CONCURRENCY`, tambem
read-only. O Agente executa apenas `SELECT` e publica snapshots V1 por HTTPS. Nao chama
procedures, nao recebe operacoes e nao executa `INSERT`, `UPDATE` ou `DELETE` no Firebird.

O filtro `MOTORISTA_ALLOWED_SCOPES` e obrigatorio e vazio bloqueia a execucao. Cada item aceita
`empresa` (todas as cargas elegiveis da empresa) ou `empresa:carga` (escopo controlado de uma
carga). Uma instalacao ainda nao configurada, portanto, nao publica cargas por acidente. A chave
composta impede incluir uma carga de mesmo numero pertencente a outra empresa.

Antes de ler um Manifesto, o Agente adquire lease/fencing na Nuvem. O conteudo canonico gera
um `semantic_hash`; conteudo igual ao ultimo confirmado nao cria nova publicacao. Conteudo
novo recebe revision monotonicamente maior e `snapshot_id` UUIDv4. Revision, UUID, hash e o
JSON literal sao gravados no SQLite tecnico local antes do primeiro POST, e todo retry reutiliza
esses mesmos valores. `gerado_em` nao participa da identidade semantica.

O SQLite local nao e replica de negocio: contem apenas identidade da instalacao, piso/estado
confirmado, lease/fencing e no maximo uma publicacao pendente por tenant/Manifesto. O arquivo
fica em `instance/agent_state.sqlite3` por padrao, nao e versionado e nao armazena o token do
Agente. Em reinstalacao/troca de maquina, o piso autoritativo vem da aquisicao do lease na Nuvem.

O e-mail do cliente permanece `null` e a autorizacao `false`: o campo real e sua regra de
consentimento ainda dependem de auditoria focal antes de qualquer sincronizacao de dado
pessoal. Endereco e identificacao ja necessarios ao App permanecem no snapshot.

Este bloco nao implementa polling de operacoes de entrega nem executor da
`SP_REG_ENTREGA_MANIFESTO`.
