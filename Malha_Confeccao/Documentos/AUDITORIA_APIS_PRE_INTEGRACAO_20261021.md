# Auditoria das APIs existentes — pré-integração Firebird

Data: 21/10/2026  
Escopo: inspeção exclusivamente em leitura de `BarCode\api`, `AppMotorista\ApiMotorista` e fontes do `ParmaIndustrial` no repositório ParmaSoft. Nenhum serviço foi iniciado, nenhuma dependência foi instalada e nenhum banco foi acessado.

## Conclusão executiva

Para o App de Pedidos de Malhas, a base técnica recomendada é a arquitetura modular da API Motorista, combinada com o conhecimento de consultas Firebird já comprovado na API BarCode:

```text
Flutter (HTTPS) -> API de vendedores -> Firebird ParmaGestor
```

O aplicativo nunca deve conhecer credenciais Firebird nem estabelecer conexão com o banco. A API deve obter o vendedor a partir da sessão autenticada e aplicar a restrição de carteira no SQL/serviço do servidor.

## 1. API BarCode (`E:\Jorginho\BarCode\api`)

### O que está implementado

- API Flask monolítica em `app.py`, com driver Python `fdb` para Firebird.
- `iniciar_api.bat` cria/usa ambiente virtual e instala `flask` e `fdb` quando necessário. Não foi encontrado um arquivo de dependências versionado nessa pasta.
- A conexão é aberta por uma função única e consultas usam parâmetros posicionais do driver (`?`).
- As rotas retornam JSON e usam estados HTTP para erro de entrada, não encontrado e erro interno.
- Há abertura, `commit` para operações de escrita, `rollback` em falhas e fechamento de conexão em blocos `finally` em boa parte das rotas.
- A rota de busca de produto exige ao menos três caracteres, limita o resultado a 30 registros e retorna código, descrição, unidade e preço. Ela consulta `TB_PRODUTO` e filtra produto inativo.
- A rota de leitura de código de barras mostra também a relação `TB_PROD_CODIGO_BARRAS -> TB_PRODUTO`.

### Limitações para o novo app externo

- A API é concentrada em um único arquivo e mistura leitura, gravações operacionais e impressão.
- A configuração de banco está embutida no fonte, inclusive dado sensível. Esse padrão não deve ser copiado.
- As rotas observadas não têm uma camada de autenticação/autorização de vendedor.
- O inicializador e a própria conexão indicam uso local; não há evidência de publicação HTTPS externa nesse projeto.

### Reaproveitamento recomendado

- Driver `fdb`, consultas parametrizadas, conversão explícita de `Decimal`/numéricos para JSON e tratamento transacional.
- A ideia de limitar, ordenar e exigir mínimo de três caracteres na busca de produtos.
- Não reutilizar a configuração embutida, nem transportar o `app.py` inteiro.

## 2. API Motorista (`E:\Jorginho\AppMotorista\ApiMotorista`)

### O que está implementado e coberto por fontes/testes

- API Flask modular: fábrica em `app/__init__.py`, configuração em `app/config.py`, conexão/transação Firebird em `app/database.py`, e módulos separados de autenticação e viagens.
- Dependências declaradas: Flask 3.x, Werkzeug 3.x e `fdb` 2.x.
- Credenciais e parâmetros de conexão são lidos de variáveis de ambiente; existe `.env.example`. O `.env` real não foi lido nem copiado.
- Autenticação em `POST /api/v1/motorista/sessoes` e renovação em `POST /api/v1/motorista/sessoes/renovar`.
- Tokens opacos são gerados com `secrets`; somente o SHA-256 é persistido em `TB_MOTORISTA_APP_SESSAO`. O token bruto só integra a resposta de login/renovação.
- O decorador de autenticação exige `Authorization: Bearer ...`, consulta a sessão ativa/não expirada e coloca sessão, motorista e dispositivo no contexto do servidor.
- A senha é validada com `werkzeug.security.check_password_hash` contra `TB_MOTORISTA_APP`; a senha legada do ERP não é consultada.
- Rotas de viagens são protegidas pelo decorador. Na confirmação de entrega, empresa, motorista, sessão e dispositivo são derivados do contexto autenticado, e não do JSON enviado pelo cliente.
- A entrega valida rigorosamente o payload, canonicaliza-o, calcula SHA-256 e usa operação idempotente no banco (`SP_REG_ENTREGA_MANIFESTO`).
- Há testes unitários para aleatoriedade/digest de token e para validações, campos de propriedade do servidor e idempotência da entrega.

### Rede e disponibilidade

- `run.py` e o lote local usam, por padrão, `127.0.0.1:5055`; o lote menciona uso com ADB reverse. Isso comprova execução local de desenvolvimento, não exposição externa.
- O código inspecionado não configura TLS/HTTPS, proxy reverso, rate limit, CORS restritivo, observabilidade, nem política de publicação em nuvem.
- Portanto, não há evidência documental ou de configuração de que a autenticação/API externa esteja homologada em produção. Há implementação e testes locais, mas a homologação externa continua pendente.

### Reaproveitamento recomendado

- Fábrica Flask, `Blueprint`s por domínio, `Config` por ambiente, context managers de leitura/transação e `ApiError` com respostas JSON consistentes.
- Sessão opaca Bearer, hashes de tokens no Firebird, expiração curta de acesso e rotação de refresh token.
- Regra essencial: derive identidade e permissões da sessão no servidor; não aceite vendedor, empresa, preço, carteira ou permissões como autoridade do payload Flutter.
- O padrão de chave de idempotência/canonicalização deve ser reutilizado futuramente no envio de pedidos offline, ainda que esta primeira integração seja apenas de leitura.

## 3. Esquema ParmaGestor confirmado nos fontes

As estruturas abaixo foram identificadas nos data modules e consultas do `ParmaIndustrial`. Os nomes foram verificados nos fontes; seus dados e índices não foram acessados.

| Finalidade | Tabelas e campos confirmados | Relação/regra observada |
| --- | --- | --- |
| Cliente | `TB_CLIENTE`: `CLI_EMPRESA`, `CLI_ID`, `CLI_RSOCIAL_NOME`, `CLI_FANTASIA_APELIDO`, `CLI_STATUS`, `CLI_VENDEDOR`, `CLI_TABELA_PRECO` | Cliente ativo é tratado como `CLI_STATUS = 'A'`. A carteira é indicada por `CLI_VENDEDOR`. |
| Vendedor | `TB_VENDEDOR`: `VDR_EMPRESA`, `VDR_ID`, `VDR_RSOCIAL_NOME`, `VDR_FANTASIA_APELIDO` | Os fontes fazem junção por empresa e vendedor: `CLI_EMPRESA = VDR_EMPRESA` e `CLI_VENDEDOR = VDR_ID`. |
| Produto | `TB_PRODUTO`: `PRD_EMPRESA`, `PRD_ID`, `PRD_STATUS`, `PRD_DESCRICAO`, `PRD_UN_VENDA`, `PRD_PRECO_VENDA` | Produtos inativos são excluídos por `PRD_STATUS <> 'I'`. |
| Código de barras | `TB_PROD_CODIGO_BARRAS`: `PRDC_EMPRESA`, `PRDC_PRODUTO`, `PRDC_COD_BARRAS`, `PRDC_PRINCIPAL` | A busca de produto do ParmaGestor/BarCode toma o principal por empresa/produto. |
| Tabela comercial | `TB_TABELA_PRECO`: `TBP_EMPRESA`, `TBP_ID`, `TBP_STATUS`, `TBP_TIPO`, `TBP_DESCONTO_ACRESCIMO` | O orçamento calcula o preço a partir de `PRD_PRECO_VENDA`, aplicando acréscimo/desconto segundo tipo e valor da tabela. `CLI_TABELA_PRECO` é o vínculo do cliente confirmado nos fontes. |

Os fontes de orçamento mostram que o preço exibido é derivado no lado servidor da tabela comercial do cliente, e não simplesmente o `PRD_PRECO_VENDA`. A regra completa de seleção de tabela (inclusive exceções comerciais por vendedor/cliente) deve ser validada com uma cópia autorizada do banco e o responsável de negócio antes de publicar qualquer endpoint.

## 4. Desenho das duas primeiras consultas

As rotas abaixo são uma proposta de contrato para a próxima fase; **não foram criadas nesta auditoria**.

### Pesquisa de clientes

- `GET /api/v1/vendedores/clientes?termo=...`
- Recusar termos com menos de três caracteres.
- Resolver vendedor e empresa pelo token/sessão, nunca por parâmetros da tela.
- Consultar `TB_CLIENTE` filtrando simultaneamente empresa, `CLI_STATUS = 'A'`, `CLI_VENDEDOR` do contexto autenticado e termo por `CLI_ID`, `CLI_RSOCIAL_NOME` ou `CLI_FANTASIA_APELIDO`.
- Limitar, ordenar e retornar apenas identificador, código, razão/nome e fantasia necessários à tela.

### Pesquisa de produtos

- `GET /api/v1/vendedores/produtos?termo=...&cliente_id=...`
- Recusar termos com menos de três caracteres e revalidar que o cliente pertence à carteira do vendedor antes de usar sua tabela comercial.
- Pesquisar `TB_PRODUTO` por `PRD_ID` e `PRD_DESCRICAO`, filtrando empresa e produto ativo; usar `TB_PROD_CODIGO_BARRAS` quando pesquisa por código de barras for necessária.
- Calcular e retornar no servidor `id`, código, descrição, unidade e preço comercial resultante. O aplicativo somente exibe o preço; não o edita nem o recalcula.

## 5. Pendências antes de implementar

1. Definir e homologar a associação segura entre o usuário do novo app e `TB_VENDEDOR`/empresa ParmaGestor. A API Motorista usa tabelas próprias de motorista; ela não resolve automaticamente o usuário vendedor.
2. Validar em cópia autorizada do Firebird a consulta de carteira, chaves, índices, acentuação/collation e todos os casos comerciais de tabela de preço.
3. Confirmar formalmente a regra de preço: tabela do cliente, preço específico, promoções, permissões e arredondamentos. Não há base para assumir que `PRD_PRECO_VENDA` seja sempre o preço final.
4. Definir a infraestrutura externa: domínio, certificado TLS, proxy reverso, firewall, limite de requisições, logs seguros, monitoramento, backups e política de rotação de segredos.
5. Definir provisionamento administrativo de vendedores e revogação de sessão; não expor cadastro/troca de senha ao aplicativo nesta fase.
6. Projetar respostas de erro de rede no Flutter, armazenamento seguro de tokens e, para a etapa posterior de pedidos, outbox local e idempotência ponta a ponta.
7. Criar testes de integração apenas contra cópia autorizada do banco. Esta auditoria não executou SQL e não comprovou conectividade, permissões ou funcionamento em produção.

## 6. Próximo passo técnico recomendado

Com autorização separada, criar no projeto novo uma API de vendedores mínima, modular e configurada por ambiente, inspirada na API Motorista. Antes de conectá-la ao Flutter, implementar e testar apenas autenticação/provisionamento de vendedor e as duas rotas de leitura contra uma cópia local autorizada do Firebird. A validação de carteira e o cálculo do preço deverão ocorrer integralmente no servidor.

## Registro de conformidade da auditoria

- Não foram alterados BarCode, AppMotorista, ParmaGestor, `PARMASOFT_INTEGRACAO`, banco de dados ou Flutter.
- Nenhum `.env` real, senha, token ou credencial foi copiado para este documento.
- Nenhum endpoint, serviço, dependência, migration ou conexão de banco foi criado/iniciado.
