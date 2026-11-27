# ApiMotoristaNuvem - PostgreSQL preparado em fonte

## Status de homologação — 19/11/2026

A API oficial em uso pelo App Motorista é
`https://motorista.parmatech.com.br`. O endpoint público
`GET /api/v1/health` foi conferido no Samsung S20 e respondeu o serviço como
saudável. O login do motorista e a abertura de **Minhas viagens** foram
homologados no aparelho; a tela informou "Nenhuma viagem liberada".

O aplicativo usa a URL oficial compilada por `dart-define`, sem configuração
de IP pelo motorista. A publicação de viagens depende do
`AgenteMotoristaGramDecor`; não houve publicação confirmada da carga 776 nesta
rodada. O retorno de entregas continua desabilitado até homologação segura da
estrutura Firebird e do respectivo fluxo de retorno.

API isolada da API local e do Firebird GramDecor. A producao exige PostgreSQL por
`postgresql+psycopg`; SQLite e aceito somente como banco descartavel quando `TESTING=true`.
Nenhum servico da DigitalOcean foi criado ou alterado.

## Limites deste bloco

- concede lease curto por Manifesto e recebe snapshots com fencing;
- valida `snapshot_revision`, `snapshot_id` UUIDv4 e `semantic_hash` antes de atualizar projecoes;
- lista/detalha viagens para sessoes moveis previamente provisionadas;
- separa `technical_status` do estado de acompanhamento;
- mantem contratos e estruturas idempotentes de evento/notificacao;
- recebe somente `delivery_read` do motorista, com ledger PostgreSQL e idempotencia UUIDv4; nao escreve no Firebird nem envia e-mail;
- nao possui login/ponte de sessao, pagina publica ou painel definitivo;
- nao emite `SAIU_PARA_ENTREGA` automaticamente.

## Configuracao

As variaveis obrigatorias e seus nomes estao em `.env.example`. Nao grave segredos reais no
repositorio. Em producao, o bind previsto e `127.0.0.1:8091`, atras de Nginx/HTTPS.

O schema PostgreSQL e criado e evoluido exclusivamente pelo Alembic:

```text
alembic upgrade head
```

`app.database.initialize_database()` existe somente para criar SQLite descartavel nos testes.
Tenant e tokens sao provisionados por `app.provisioning`; tokens ficam armazenados somente
como HMAC. Nao existe provisionamento exposto por HTTP, e a credencial autenticada define o
tenant de toda leitura e publicacao.

## Endpoints V1

- `GET /api/v1/health` - saude do processo, sem acessar Firebird.
- `POST /api/v1/agente/snapshot-leases/{manifesto_guid}/acquire` - adquire ou renova lease.
- `POST /api/v1/agente/snapshot-leases/{manifesto_guid}/renew` - renova lease/fencing vigentes.
- `POST /api/v1/agente/snapshots` - exige headers de instancia/fencing; responde `200` para
  replay, `201` para novo recibo e `409` para conflito ou fencing invalido.
- `GET /api/v1/motorista/viagens` - sessao controlada; somente o motorista/tenant.
- `GET /api/v1/motorista/viagens/{manifesto_guid}` - mesmo isolamento.
- `POST /api/v1/motorista/sessoes/renovar` - renova o access token da sessao QR com refresh token.
- `POST /api/v1/motorista/viagens/{manifesto_guid}/paradas/{parada}/pedidos/{pedido}/leituras` - contrato minimo `delivery_read`; tenant e motorista sao derivados do Bearer, nunca do JSON.

O JSON canonico V1 e os vetores comuns ao Agente/API estao em `contracts/v1`.
`semantic_hash` ignora `snapshot_id`, `snapshot_revision`, `semantic_hash` e `gerado_em`;
lease/fencing viajam em headers. O mesmo `snapshot_id` nunca pode representar outra publicacao.

## Validacao antes de producao

Os testes SQLite controlados validam contrato, transacoes e comportamento funcional, mas nao
substituem a suite de integracao em PostgreSQL 18 real e descartavel. Essa suite ainda devera
validar migrations, tipos nativos, advisory lock e concorrencia antes de qualquer implantacao.

## DigitalOcean - ainda nao executar

Qualquer criacao de banco, usuario, servico, segredo, virtual host, DNS, TLS, regra de firewall,
backup ou monitoramento depende de nova autorizacao expressa do Jorginho. Fabri, Nutricao e
Financeiro nao devem ser alterados nem compartilhados.
