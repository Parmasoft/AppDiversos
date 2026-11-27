# Etapa 5 — integração Flutter/API Firebird

Data: 21/10/2026  
Status: interrompida com segurança antes de implementar endpoints comerciais ou modificar o Flutter.

## Resultado do pré-requisito de segurança

A API local e a conexão somente leitura com o Firebird estão funcionais, mas a autenticação de vendedores **não está comprovada como segura** para uso externo ou para liberar consultas no Samsung.

### Evidências verificadas em leitura

- O banco GramDecor contém `TB_VENDEDOR` com `VDR_EMPRESA`, `VDR_ID`, `VDR_STATUS`, `VDR_LOGIN` e `VDR_SENHA`.
- Os metadados indicam `VDR_LOGIN` com tamanho 50 e `VDR_SENHA` com tamanho 20.
- Os fontes do ParmaGestor exibem esses dois campos diretamente no cadastro de vendedor, inclusive como “Login Tablet” e campo de senha mascarado na interface.
- Não foi identificada nos fontes consultados uma rotina de hash seguro, comparação de hash, geração/rotação de token, expiração de sessão ou revogação para `TB_VENDEDOR`.
- A API Motorista possui um padrão diferente e comprovadamente mais adequado: tabela própria de identidade, hash Werkzeug, tokens opacos persistidos somente como SHA-256 e sessão Bearer. Esse padrão não pode ser aplicado automaticamente ao vendedor sem uma definição administrativa e sem criar estruturas — o que está fora desta etapa e não pode alterar o banco.

Consequentemente, não é seguro comparar a senha legada de `VDR_SENHA`, nem assumir seu formato, nem transformar `VDR_LOGIN` em autenticação externa. Não foram lidos valores de login ou senha, nem retornados dados de vendedores/clientes.

## Auditoria técnica das consultas futuras

As tabelas solicitadas foram confirmadas no banco de testes e nos fontes:

| Área | Estrutura confirmada | Regra observada |
| --- | --- | --- |
| Cliente | `TB_CLIENTE`: `CLI_EMPRESA`, `CLI_ID`, `CLI_RSOCIAL_NOME`, `CLI_FANTASIA_APELIDO`, `CLI_STATUS`, `CLI_VENDEDOR`, `CLI_TABELA_PRECO` | O cliente é associado ao vendedor por empresa e `CLI_VENDEDOR`; os fontes usam cliente ativo com `CLI_STATUS = 'A'`. |
| Vendedor | `TB_VENDEDOR`: `VDR_EMPRESA`, `VDR_ID`, `VDR_STATUS`, nome/fantasia, login e senha legados | A junção de carteira observada é `CLI_EMPRESA = VDR_EMPRESA` e `CLI_VENDEDOR = VDR_ID`. |
| Produto | `TB_PRODUTO`: `PRD_EMPRESA`, `PRD_ID`, `PRD_STATUS`, `PRD_DESCRICAO`, `PRD_UN_VENDA`, `PRD_PRECO_VENDA` | Produtos inativos são filtrados por `PRD_STATUS <> 'I'` nos fontes de orçamento. |
| Código de barras | `TB_PROD_CODIGO_BARRAS`: `PRDC_EMPRESA`, `PRDC_PRODUTO`, `PRDC_COD_BARRAS`, `PRDC_PRINCIPAL` | A seleção de código principal é usada nas pesquisas existentes. |
| Tabela comercial | `TB_TABELA_PRECO`: empresa, id, status, descrição, tipo e percentual de ajuste | `CLI_TABELA_PRECO` identifica a tabela do cliente. O orçamento calcula valor a partir de `PRD_PRECO_VENDA` e do tipo/percentual da tabela. |

O cálculo comercial exato ainda requer homologação de todas as exceções (preço específico, promoção, permissões e arredondamento). Nenhum preço foi retornado como se fosse definitivo.

## O que não foi implementado

- Não foi criado endpoint de login de vendedor.
- Não foi criado endpoint de clientes ou produtos, pois seriam comerciais e exigem autenticação/autorização prévia.
- Não foi criado token fixo, conta de teste, senha alternativa ou bypass de carteira.
- O Flutter, inclusive a tela Novo Pedido, não foi modificado.
- Não foi executado ADB reverse, pois não há endpoint comercial autenticado para testar no Samsung.
- Nenhum dado ou estrutura do Firebird foi alterado.

## Serviços internos criados para teste (sem HTTP)

Foram criados `app/catalog/service.py` e testes unitários correspondentes, exclusivamente sem `Blueprint`/rota pública:

- `search_clients_for_vendedor(empresa, vendedor_id, termo)` exige três caracteres e inclui no SQL parametrizado empresa, vendedor, `CLI_STATUS = 'A'` e busca por código, razão/nome ou fantasia.
- `search_products_for_authorized_client(empresa, vendedor_id, cliente_id, termo)` exige três caracteres e revalida no `EXISTS` que o cliente está ativo e pertence à carteira antes de retornar produtos ativos.
- Ambas usam `read_connection()` e fecham cursor; o preço retornado pelo serviço é `null` até que a fórmula comercial seja homologada.

Os parâmetros `empresa`/`vendedor_id` são apenas a futura entrada interna de um contexto autenticado no servidor. Eles não são aceitos de HTTP nem do Flutter. Os testes usam mocks e não leem dados cadastrais reais.

Resultado da validação automatizada após esses serviços: **9 testes aprovados**. Não foi executado ADB reverse e não houve teste no Samsung, pois isso só será autorizado após a identidade do vendedor ser autenticada e vinculada pelo servidor.

## Status da etapa

| Item | Estado |
| --- | --- |
| API local/`/health` | OK (validação anterior) |
| Firebird somente leitura | OK (validação anterior) |
| Autenticação segura de vendedor | PENDENTE |
| Consulta autorizada de clientes | PENDENTE/BLOQUEADA |
| Consulta autorizada de produtos | PENDENTE/BLOQUEADA |
| Teste Samsung via ADB reverse | BLOQUEADO pela ausência de autenticação válida |

## Próximo passo necessário

Definir e autorizar um mecanismo de identidade de vendedor que não use a senha legada diretamente. A opção recomendada é criar, em etapa própria e contra cópia autorizada do banco, uma identidade de aplicativo de vendedor com senha armazenada como hash e sessões Bearer opacas/rotativas, vinculada explicitamente a `VDR_EMPRESA` e `VDR_ID`. Só após isso devem ser criadas as rotas protegidas de clientes e produtos e configurado o ADB reverse para o Samsung.

Nenhuma credencial, token, login ou dado cadastral foi incluído neste documento.

## Complemento — Login Tablet existente

Foi realizada nova auditoria somente em leitura, agora considerando a confirmação de que a tela **Manutenção de Vendedor** apresenta “Login Tablet” e “Senha”.

### Campos reais confirmados

- `TB_VENDEDOR.VDR_EMPRESA` e `TB_VENDEDOR.VDR_ID`: chave composta do vendedor;
- `TB_VENDEDOR.VDR_LOGIN`: Login Tablet, `VARCHAR(50)`;
- `TB_VENDEDOR.VDR_SENHA`: Senha, `VARCHAR(20)`;
- `TB_VENDEDOR.VDR_STATUS`: situação do vendedor;
- `TB_VENDEDOR.VDR_RSOCIAL_NOME`: nome do vendedor.

Os fontes Delphi de Manutenção de Vendedor ligam diretamente os controles “Login Tablet” e “Senha” a `VDR_LOGIN` e `VDR_SENHA`. A importação/cadastro também grava diretamente esses campos em `TB_VENDEDOR` por parâmetros SQL.

### Resultado da auditoria da validação

Não foi encontrada, nos fontes Delphi consultados, uma rotina de autenticação de tablet que:

- compare `VDR_LOGIN` e `VDR_SENHA`;
- transforme, criptografe ou aplique hash à senha;
- determine `VDR_EMPRESA` a partir do login;
- trate logins repetidos entre empresas;
- crie, expire ou revogue sessão/token de vendedor.

O tipo/tamanho de `VDR_SENHA` e o vínculo direto de interface não comprovam texto simples, hash ou qualquer outro formato. Portanto, a regra real de validação não pôde ser comprovada somente pelos fontes e metadados disponíveis.

### Decisão de segurança

Não foi implementado login na API e não foi executado teste de credencial de vendedor. Fazer `WHERE VDR_LOGIN = ? AND VDR_SENHA = ?` seria criar uma validação nova sem comprovar que ela corresponde ao ERP e poderia expor uma senha legada em uma API externa. Também não há base segura para escolher empresa quando o mesmo login existir em mais de uma empresa.

Para prosseguir, é necessário localizar a implementação efetivamente usada pelo aplicativo tablet legado (fonte, executável/documentação ou serviço correspondente) ou receber definição formal da regra de autenticação e de desambiguação por empresa. Até isso ocorrer, as consultas comerciais permanecem sem rota HTTP e o Flutter não é alterado.

## Atualização 5.1 — autenticação autorizada pelo responsável

O responsável autorizou expressamente a compatibilidade da senha recebida com `VDR_SENHA` para o teste local. A API passa a consultar somente `TB_VENDEDOR`, com SQL parametrizado, exige `VDR_STATUS = 'A'` e compara o valor recuperado com `hmac.compare_digest`. Nenhuma senha é retornada, registrada ou incluída em testes.

`VDR_LOGIN` é pesquisado globalmente entre vendedores. Se houver mais de um vendedor ativo para o mesmo login, a API recusa a autenticação e não escolhe empresa arbitrariamente. Em êxito, a sessão efêmera em memória contém sempre `VDR_EMPRESA` e `VDR_ID`, expira em 15 minutos e pode ser encerrada por `DELETE /api/v1/sessoes/atual` com Bearer token. Após reiniciar a API, as sessões se perdem; isso é limitação deliberada do desenvolvimento local, não solução de produção.

O Flutter preserva o visual do Login e agora envia usuário/senha apenas para `http://127.0.0.1:5056/api/v1/sessoes` no desenvolvimento. O token não é persistido. HTTP em texto claro foi permitido somente no manifesto `debug` para o ADB reverse; a configuração principal de produção não foi enfraquecida.

Ainda falta executar login com uma credencial de vendedor informada pelo operador na própria tela, configurar `adb reverse tcp:5056 tcp:5056` com o Samsung conectado e validar o fluxo físico. Não houve alteração no Firebird, rota de consulta comercial, pedido ou sincronização.

Validação executada: testes Python da API, **10 aprovados**; `flutter analyze`, concluído sem problemas. O teste real de credenciais não foi executado porque nenhuma senha de vendedor foi fornecida ou registrada nesta atividade.

## Atualização 5.2 — rota e log operacional

O código atual registra `POST /api/v1/sessoes`; a tabela de rotas também contém `DELETE /api/v1/sessoes/atual` e `GET /health`. A resposta 404 da instância então ativa confirma que ela havia sido iniciada antes da inclusão do blueprint de autenticação. É obrigatório encerrar e reiniciar `iniciar_api_malhas.bat` para carregar o código novo; não é necessário alterar Firebird ou credenciais.

A API passou a registrar no console, sem query string, corpo, senha, token ou cabeçalho Authorization: horário, método, caminho, HTTP e duração. Exemplo: `[16:25:10] POST /api/v1/sessoes -> HTTP 401 (12 ms)`. Erros 500 registram rastreamento técnico somente no servidor e devolvem JSON genérico.

## Encerramento do dia — situação real

Data: 21/10/2026.

O login real do vendedor no Samsung está **PENDENTE / NÃO HOMOLOGADO**. As mensagens observadas no aparelho foram “API indisponível. Verifique USB.” e “Rota não encontrada.” Não há confirmação de senha incorreta, nem confirmação de que a última tentativa alcançou a rota de autenticação. Na última tentativa relatada, a janela da API não exibiu nova requisição.

Evidências confirmadas, mas insuficientes para homologar login: Samsung reconhecido por `adb devices`; `adb reverse tcp:5056 tcp:5056` e sua listagem confirmados; navegador do Samsung acessou `/health` e recebeu `{"status":"ok"}`; conexão Firebird validada separadamente; `POST /api/v1/sessoes` existe no código atual; e testes automatizados passaram. Esses fatos não substituem uma tentativa real que apareça no log da instância atual da API.

Próximo passo único: diagnosticar o processo que atende a porta 5056 e homologar o login real no Samsung. Não alterar senha, autenticação, banco ou Flutter antes de confirmar `GET /health -> HTTP 200` na janela correta e, depois, registrar o HTTP resultante de `POST /api/v1/sessoes`.
