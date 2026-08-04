# ParmaCloudSync

Sincronizador oficial da ParmaSoft entre o ERP Firebird dos clientes e o Portal na nuvem.

## Status documental mais recente

Ponto de parada oficial mais recente:

```text
documentacao/status/PONTO_DE_PARADA_2026-08-03_ParmaCloudSync_v1.0.md
```

Resumo do estado atual:

- Portal Fabri Tecidos funcional e aprovado em 03/08/2026;
- banco da nuvem carregado com 3.154 produtos reais da Fabri;
- ultima compra exibida no Portal;
- layout desktop preservado em tabela;
- layout mobile aprovado em painel compacto;
- proxima retomada deve avaliar a instalacao definitiva do Servico Windows ParmaCloudSync no servidor real da Fabri.

## Objetivo da versão 1.0

- Ler as configurações do `config.ini`.
- Conectar ao Firebird do cliente.
- Consultar os produtos.
- Montar o JSON.
- Enviar os dados para a API.
- Registrar logs.
- Repetir o processo em intervalos configuráveis.

## Requisitos

- Python 3.11.
- Firebird Client compatível com a arquitetura do Python.
- Acesso ao banco Firebird do cliente.
- Acesso HTTPS à API do Portal.

> Atenção: se o Firebird Client for 32 bits, o Python também deverá ser 32 bits.

## Instalação

Abra o Prompt de Comando dentro da pasta do projeto:

```bat
py -3.11 -m venv venv
venv\Scripts\activate
python -m pip install --upgrade pip
pip install -r requirements.txt
```

## Configuração

Edite o arquivo `config.ini`.

Os primeiros campos a confirmar no servidor da Fabri Tecidos são:

- Caminho e porta do banco Firebird.
- Usuário e senha.
- Charset.
- URL da API.
- Identificador do cliente.
- SQL real dos produtos.
- Forma de autenticação exigida pelo endpoint.

Não mantenha a senha padrão `masterkey` caso o cliente utilize outra senha.

## Validação 1 — configuração e conexão

Antes de qualquer envio para a nuvem:

```bat
venv\Scripts\activate
python main.py --testar-conexao
```

Resultado esperado:

```text
Conexão com o Firebird validada.
Teste de conexão concluído com sucesso.
```

O teste executa somente:

```sql
SELECT 1 FROM RDB$DATABASE
```

Nenhum dado é alterado e nada é enviado para a API.

## Validação 2 — ciclo único

Somente depois de validar o SQL e o formato esperado pela API:

```bat
python main.py --uma-vez
```

## Execução contínua

```bat
python main.py
```

O intervalo é definido em:

```ini
[aplicacao]
intervalo_segundos = 300
```

## Logs

Os logs são gravados em:

```text
logs\ParmaCloudSync.log
```

Há rotação automática por tamanho, evitando crescimento ilimitado.

## Arquitetura

- `main.py`: entrada da aplicação.
- `config.py`: leitura e validação do INI.
- `banco.py`: acesso ao Firebird.
- `api.py`: comunicação HTTP com o Portal.
- `sincronizador.py`: orquestração dos ciclos.
- `modelos.py`: modelos de dados.
- `logger.py`: configuração dos logs.

## Próximas evoluções previstas

- Sincronização incremental.
- Estoque.
- Tabelas de preço.
- Clientes.
- Pedidos.
- Imagens.
- Serviço do Windows.
- Atualização automática.
- Controle de versão e diagnóstico remoto.
