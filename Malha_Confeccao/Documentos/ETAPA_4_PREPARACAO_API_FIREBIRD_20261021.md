# Etapa 4 — Preparação da API e conexão Firebird

Data: 21/10/2026  
Escopo concluído: estrutura local da API, teste controlado de conectividade e testes automatizados. Não foram criadas rotas comerciais, autenticação de vendedores, gravações nem integração Flutter.

## Estrutura criada

```text
api/
  app/
    health/routes.py       # GET /health, sem acesso ao banco
    config.py              # configuração por ambiente
    database.py            # conexão/transação somente leitura
    environment.py         # leitura opcional de .env local
    api_errors.py
  tests/
  .env.example
  requirements.txt
  check_connection.py
  run.py
  README.md
```

O desenho segue a separação modular da API Motorista: fábrica Flask, configuração, banco, rotas e testes em módulos distintos. A API local escuta somente em `127.0.0.1` por padrão, na porta configurável `5056`.

## Dependências

- Flask 3.x
- Werkzeug 3.x
- `fdb` 2.x, o mesmo driver Firebird identificado nas APIs de referência

Não houve instalação de dependências nesta etapa. Os testes foram executados usando o ambiente Python já existente de referência, exclusivamente para validação; nenhum arquivo desse projeto foi alterado.

## Configuração Firebird

`.env.example` fornece somente nomes de variáveis e o caminho de referência do banco de testes GramDecor:

- `FB_HOST`, `FB_PORT`, `FB_DATABASE`, `FB_USER`, `FB_PASSWORD`, `FB_CHARSET`;
- `MALHA_API_HOST`, `MALHA_API_PORT`, `MALHA_API_DEBUG`.

O `.env` local está protegido no `.gitignore`. Credenciais não foram inseridas no fonte, documento ou exemplo.

`check_connection.py` carrega o ambiente e, quando a configuração estiver completa, abre a conexão com `fdb`, inicia transação `read committed/read-only`, executa exclusivamente `SELECT 1 FROM RDB$DATABASE`, fecha cursor/conexão e encerra a transação. A camada de banco devolve erros sanitizados: ela não inclui senha, caminho do banco nem texto original do driver na mensagem pública.

## Resultado real do teste de conexão

O teste foi executado em 21/10/2026 e não abriu conexão porque não há `.env` local configurado. A saída controlada informou os parâmetros ausentes:

```text
FB_DATABASE, FB_USER, FB_PASSWORD
```

Isso é o comportamento esperado para não inventar nem copiar credenciais de projetos de referência. Portanto, a conectividade com `E:\Dados Clientes\GramDecor\DADOS.FDB` ainda está **pendente de credencial autorizada somente leitura**. Nenhuma consulta ou alteração foi feita no banco.

## Atualização 4.1 — preparação para validação real

Foi criado `api/.env`, arquivo local protegido pelo `.gitignore`, sem valores de usuário ou senha. A configuração não sensível definida é `127.0.0.1:3050`, banco `E:\Dados Clientes\GramDecor\DADOS.FDB` e charset `ISO8859_1`. O driver continua sendo `fdb`.

O host, a porta e o driver foram confirmados por inspeção em leitura das referências; o charset foi adotado da configuração de leitura do BarCode para o banco GramDecor. A API Motorista também usa `fdb` e porta padrão 3050, mas tem charset padrão distinto e não teve nenhuma credencial consultada ou reaproveitada.

Até que o operador preencha `FB_USER` e `FB_PASSWORD` com uma conta de leitura autorizada, `check_connection.py` deve permanecer pendente e não será executado contra o banco. O `.env` não deve integrar Git nem backups.

## Atualização 4.2 — correção de carregamento e inicializador

Foi identificado um defeito de ordem de inicialização: `check_connection.py` carregava o `.env` antes de chamar `create_app`, mas a classe `Config` já havia sido importada nesse ponto e lia o ambiente durante a importação. Assim, valores vazios podiam permanecer congelados na configuração Flask, mesmo quando o `.env` tinha sido localizado.

`Config.from_environment()` agora lê as variáveis no instante da criação da aplicação. O carregador continua calculando o caminho absoluto de `api/.env` a partir do próprio módulo, independentemente do diretório do terminal, e passou a aceitar também arquivo UTF-8 com BOM. Nenhum valor do `.env` foi alterado ou registrado.

Também foi criado `api/iniciar_api_malhas.bat`. Ele entra na pasta da API, prefere `api/venv/Scripts/python.exe`, verifica Flask e `fdb` sem instalar nada automaticamente e executa `run.py`. A API permanece limitada a `127.0.0.1:5056` pela configuração local. A validação de `/health` e a do Firebird são independentes.

## Atualização 4.3 — validação concluída

Após a correção, `check_connection.py` foi executado a partir do diretório do projeto, fora de `api`, e carregou o arquivo `api/.env` pelo caminho absoluto calculado pelo carregador. A conexão com o banco local de testes `E:\Dados Clientes\GramDecor\DADOS.FDB` foi confirmada usando o driver `fdb`.

Resultado da única consulta executada:

```text
SELECT 1 FROM RDB$DATABASE  ->  1
```

O script confirmou a transação somente leitura e encerrou cursor/conexão pelo context manager. Nenhuma consulta comercial, DDL ou alteração de dado foi executada.

O arquivo `api/iniciar_api_malhas.bat` também foi validado. A instância temporária respondeu `HTTP 200` em `GET http://127.0.0.1:5056/health` com `{"status":"ok"}`. A porta 5056 foi conferida como livre após o encerramento da validação. O endpoint de saúde não abriu conexão Firebird; a validação do banco foi feita separadamente por `check_connection.py`.

Os testes automatizados foram repetidos após a correção: **6 testes aprovados**.

## Testes executados

`python -m unittest discover -s api/tests -v`

Resultado: **5 testes aprovados**.

- inicialização Flask e resposta `GET /health`;
- resposta JSON genérica para rota inexistente;
- validação de nomes de configurações obrigatórias sem exibir valores;
- falha Firebird sanitizada;
- abertura de transação de leitura, `SELECT 1 FROM RDB$DATABASE`, fechamento de cursor/conexão e commit da transação no cenário simulado.

## Auditoria dos dados para a próxima etapa

A auditoria anterior permanece válida e foi utilizada como limite de projeto:

- `TB_CLIENTE`: `CLI_EMPRESA`, `CLI_ID`, `CLI_RSOCIAL_NOME`, `CLI_FANTASIA_APELIDO`, `CLI_STATUS`, `CLI_VENDEDOR`, `CLI_TABELA_PRECO`;
- `TB_VENDEDOR`: `VDR_EMPRESA`, `VDR_ID`, campos de nome/fantasia; o relacionamento observado usa empresa e vendedor;
- `TB_PRODUTO`: `PRD_EMPRESA`, `PRD_ID`, `PRD_STATUS`, `PRD_DESCRICAO`, `PRD_UN_VENDA`, `PRD_PRECO_VENDA`;
- `TB_PROD_CODIGO_BARRAS`: empresa, produto, código e indicador principal;
- `TB_TABELA_PRECO`: empresa, id, status, tipo e percentual de desconto/acréscimo.

Os fontes do orçamento do ParmaGestor confirmam que o preço comercial decorre do preço-base e da tabela comercial aplicável. Por isso, a futura API deverá calcular o preço no servidor após validar o cliente e a carteira; ela não aceitará preço informado pelo Flutter.

## Pendências

1. Criar localmente `api/.env` com credenciais de leitura autorizadas para o banco GramDecor e repetir o teste controlado.
2. Confirmar, usando apenas cópia autorizada, a tabela comercial final e exceções de preço antes de implementar qualquer consulta de produto.
3. Definir a associação administrativa entre usuário autenticado do novo app, empresa e vendedor ParmaGestor.
4. Implementar autenticação/autorização antes de expor consultas de clientes ou produtos.
5. Só então criar as duas rotas de leitura, com mínimo de três caracteres, limite de resultados e validação de carteira no servidor.

## Conformidade

- Não foram modificados Flutter, telas aprovadas, BarCode, AppMotorista, ParmaGestor, `PARMASOFT_INTEGRACAO` ou a estrutura/registros do Firebird.
- Nenhuma API foi iniciada, publicada ou exposta à internet.
- Nenhuma rota comercial, gravação, sincronização, pedido ou migração foi implementada.
