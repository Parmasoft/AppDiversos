# API local — Pedidos de Malhas

Base Flask modular, restrita ao desenvolvimento local nesta etapa. Ela ainda nao possui autenticacao, rotas comerciais ou integracao Flutter.

## Dependencias

- Python 3.11+
- Flask
- Werkzeug
- `fdb` (driver Firebird)

Instale em ambiente virtual local:

```text
python -m venv venv
venv\Scripts\python -m pip install -r requirements.txt
```

## Configuracao

Copie `.env.example` para `.env` e informe somente as credenciais autorizadas de leitura do banco de testes GramDecor. O `.env` e ignorado pelo Git. Nao use banco operacional remoto, nao insira credenciais no codigo e nao exponha a API na rede.

## Teste controlado de conexao

```text
venv\Scripts\python check_connection.py
```

O teste abre uma transacao `read committed/read-only`, executa somente `SELECT 1 FROM RDB$DATABASE`, encerra cursor/conexao e nao inicia HTTP. Erros retornam mensagem sanitizada, sem senha ou string de conexao.

## Execucao local

```text
venv\Scripts\python run.py
```

O servidor atende apenas em `127.0.0.1` por padrao, na porta configuravel 5056. `GET /health` retorna somente `{"status":"ok"}` e nao acessa o banco.
