# Arquitetura do primeiro bloco minimo

## Fluxo implementado

```text
Firebird GramDecor --SELECT/read-only consistente--> AgenteMotoristaGramDecor
                  --lease + snapshot V1/HTTPS--> ApiMotoristaNuvem
                  --> recibo idempotente + projecoes isoladas por tenant
                  --> listagem/detalhe compativeis com o App
```

O Agente nao recebe comandos. A API da nuvem nao possui acesso ao Firebird e nao aceita
operacoes de entrega. O banco pertence exclusivamente ao dominio Motorista.

## Persistencia e concorrencia

- Producao usa PostgreSQL 18, SQLAlchemy Core 2.x, Psycopg 3 e Alembic.
- SQLite e permitido somente como banco descartavel dos testes da API.
- O processamento usa advisory lock transacional por tenant/Manifesto, constraints de UUID e
  revision, e uma unica transacao para recibo, estado corrente e projecoes.
- Lease/fencing e validado sob o mesmo lock antes de examinar a revision.
- `snapshot_id` identifica a publicacao, `snapshot_revision` ordena e `semantic_hash` compara
  conteudo; nenhuma dessas funcoes e sobreposta.

## Projecoes e controle de snapshot

- `load_projection`, `manifest_projection`, `stop_projection`, `order_projection` e
  `occurrence_projection` representam a ultima projecao aplicada.
- `snapshot_receipt` guarda UUID, revision, hash, fencing e resultado imutavel da publicacao.
- `manifest_snapshot_state` guarda revision/hash/UUID correntes por tenant e Manifesto.
- `snapshot_publisher_lease` guarda titular, fencing e expiracao por tenant e Manifesto.

Nova publicacao aplicavel substitui atomicamente os filhos do Manifesto. Snapshot menor gera
recibo sem aplicar; mesma revision/hash e replay; mesma revision/hash diferente e conflito;
revision maior/hash igual avanca o piso sem reescrever a projecao.

## Eventos e notificacoes preparados

`tracking_event` e `notification_outbox` continuam apenas como estruturas e servico interno,
sem rota publica, emissor ou processo de envio. Receber snapshot nao cria evento. A confirmacao
autoritativa futura da entrega devera ser persistida separadamente da projecao de snapshot.

## Decisoes ainda pendentes

- Executar a suite de integracao em PostgreSQL 18 real e descartavel antes da implantacao.
- Determinar o marco inequivoco de saida para rota; Manifesto `L` nao basta.
- Auditar e-mail/consentimento antes de sincronizar dado pessoal.
- Implementar futuramente a ativacao movel por codigo de uso unico.
- Definir e implementar em outro bloco o inbox de operacoes e o retorno autoritativo da
  `SP_REG_ENTREGA_MANIFESTO`.

Nenhum tenant deve produzir notificacoes sem ativacao explicita. A allowlist do Agente continua
fechada por padrao e exige pares `empresa:carga` expressos.
