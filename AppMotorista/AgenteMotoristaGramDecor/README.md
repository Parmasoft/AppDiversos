# AgenteMotoristaGramDecor - publicador somente leitura

Primeiro bloco local da ponte para a nuvem. A descoberta usa uma transacao curta read-only;
cada Manifesto e materializado em uma transacao Firebird curta `SNAPSHOT/CONCURRENCY`, tambem
read-only. O Agente executa apenas `SELECT` e publica snapshots V1 por HTTPS. Nao chama
procedures, nao recebe operacoes e nao executa `INSERT`, `UPDATE` ou `DELETE` no Firebird.

O filtro `MOTORISTA_ALLOWED_SCOPES` (`empresa:carga`) e obrigatorio e vazio bloqueia a
execucao. Uma instalacao ainda nao configurada, portanto, nao publica cargas por acidente.
A chave composta impede incluir uma carga de mesmo numero pertencente a outra empresa.

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
