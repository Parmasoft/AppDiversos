# API Motorista

Base modular de leitura do App Motorista.

Escopo atual:

- criação e renovação de sessão;
- autenticação por token opaco Bearer;
- listagem das viagens liberadas para o motorista autenticado;
- snapshot de uma viagem;
- conferência normal de entrega por leitura C/R, com idempotência.

Endpoint de leitura:

```text
POST /api/v1/motorista/viagens/{manifesto_guid}/paradas/{parada}/pedidos/{pedido}/leituras
```

A API canonicaliza o payload, calcula o SHA-256 e executa
`SP_REG_ENTREGA_MANIFESTO`. Empresa, motorista, sessão e dispositivo são
derivados do contexto autenticado; o cliente não escolhe a ocorrência a consumir.

Os tokens brutos existem somente na resposta ao cliente. O banco armazena apenas SHA-256 dos tokens. A senha é validada pelo hash Werkzeug armazenado em `TB_MOTORISTA_APP`; a API nunca consulta a senha legada do ERP e nunca devolve o hash.

## Execução

Defina as variáveis descritas em `.env.example`, instale `requirements.txt` e execute:

```text
python run.py
```

Não há endpoint de cadastro ou troca de senha neste bloco. O provisionamento inicial do motorista deve ser administrativo e o hash deve ser produzido pela API/service Python com `werkzeug.security.generate_password_hash`.
