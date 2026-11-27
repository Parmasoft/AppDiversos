# Mapa de componentes — App Motorista

Este mapa cobre exclusivamente `E:\Jorginho\AppMotorista`; App Malhas e outros
projetos estão fora do escopo.

| Componente | Caminho / ambiente | Papel | Dependências |
| --- | --- | --- | --- |
| Flutter | `AppMotorista\` | App Android e outbox | API Nuvem HTTPS; SQLite; V2 com GUIDs persistidos |
| API local legada | `ApiMotorista\` | Fluxo histórico V1 | Firebird; não é alvo do V2 Nuvem |
| API Nuvem fonte | `ApiMotoristaNuvem\` | API mobile, snapshots e ledger | PG18/Alembic/Gunicorn; workspace sujo |
| API Nuvem implantada | DigitalOcean `/opt/api-motorista-nuvem` | Destino do S20 | serviço `api-motorista-nuvem.service`; migration 0004 |
| Agente | `AgenteMotoristaGramDecor\` | Firebird para Nuvem | allowlist/HTTPS; retorno desabilitado |
| Firebird homologação | `E:\Dados Clientes\GramDecor\DADOS.FDB` | Origem de manifestos | acessar somente com autorização explícita |
| PostgreSQL homologação | WSL PG18 `motorista_nuvem_test` | Testes isolados | migration 0004; sem relação com DigitalOcean |

```text
Firebird homologação -> Agente -> API Nuvem <- HTTPS <- Flutter/S20
Flutter outbox -> delivery_read V2 -> ledger Nuvem
```

O segundo fluxo não retorna ao Firebird. `localhost:5055` é somente legado/local;
o S20 usa `https://motorista.parmatech.com.br`.
