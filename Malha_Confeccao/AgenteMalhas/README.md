# Agente Malhas — catálogo

Aplicativo local e independente que publica snapshots de vendedores e catálogo na API Nuvem e recebe pedidos destinados à sua empresa. O Firebird permanece local: o Agente faz claim, grava o payload original nas tabelas de recepção existentes e envia ack somente após o commit. Não consulta nem recalcula o catálogo para gravar um pedido.

## Configuração

Defina no ambiente: `MALHAS_AGENT_API_URL`, `MALHAS_AGENT_TOKEN`,
`MALHAS_AGENT_EMPRESA_ID`, `MALHAS_AGENT_EMPRESA_NOME`, `FB_DATABASE`,
`FB_USER` e `FB_PASSWORD`. Opcionais: `FB_HOST` (localhost), `FB_PORT`
(3050), `FB_CHARSET` (WIN1252), `MALHAS_AGENT_STATE_PATH` (state.db) e
`MALHAS_AGENT_RETRY_SECONDS` (10).

O token é uma credencial Bearer técnica exclusiva, provisionada na tabela
`malhas_agente_credencial` pela administração da API. Ele nunca é registrado
em log; a API armazena somente seu digest HMAC.

## Execução local

```text
python -m venv venv
venv\Scripts\python -m pip install -r requirements.txt
venv\Scripts\python main.py --once
```

Sem `--once`, o agente repete a sincronização no intervalo configurado. Antes
de enviar, ele grava o snapshot pendente em SQLite; uma falha de rede preserva
o mesmo corpo e o reenvia, permitindo a idempotência da API.

Na recepção, a idempotência no Firebird usa `MPR_EMPRESA`, `MPR_ORIGEM` e `MPR_ID_LOCAL_PEDIDO`. Se a rede falhar depois do commit e antes do ack, a reserva expira, o pedido é reencontrado e a confirmação é repetida sem duplicação.
