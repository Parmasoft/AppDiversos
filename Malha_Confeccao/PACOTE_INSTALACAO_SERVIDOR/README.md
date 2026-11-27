# Pacote de instalação do Agente Malhas

Pacote isolado para `C:\Parmasoft\AgenteMalhas` no AMPLIATOSERVER. Consulte [GUIA_FINAL_AMPLIATOSERVER.md](GUIA_FINAL_AMPLIATOSERVER.md) para a transferência única e validação final. Não contém `venv`, cache, estado SQLite, logs, migrations, credenciais ou tokens.

Estrutura obrigatória de execução:

```text
C:\Parmasoft\AgenteMalhas\main.py
C:\Parmasoft\AgenteMalhas\agent\__init__.py
C:\Parmasoft\AgenteMalhas\agent\config.py
C:\Parmasoft\AgenteMalhas\agent\http_client.py
C:\Parmasoft\AgenteMalhas\agent\instance_lock.py
C:\Parmasoft\AgenteMalhas\agent\read_source.py
C:\Parmasoft\AgenteMalhas\agent\receive_orders.py
C:\Parmasoft\AgenteMalhas\agent\state.py
C:\Parmasoft\AgenteMalhas\agent\sync.py
C:\Parmasoft\AgenteMalhas\agent\diagnostics.py
```

Não mova arquivos de `agent` para a raiz: `main.py` e o diagnóstico os importam como pacote Python `agent`.

Os testes de unidade acompanham o pacote apenas para verificação do código; a instalação normal não os executa e não altera o Firebird.
