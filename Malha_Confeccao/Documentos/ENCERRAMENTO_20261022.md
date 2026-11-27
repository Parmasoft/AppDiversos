# Encerramento do dia — App de Malhas

**Data:** 22/10/2026  
**Projeto:** `E:\Jorginho\Malha_Confeccao`

## Estado atual comprovado

O aplicativo Flutter possui login integrado à API local e uma tela Home cujo layout foi aprovado. A navegação da Home, incluindo Novo Pedido, Meus Pedidos, Meus Clientes, Financeiro, Novo Cliente, resumo demonstrativo e navegação inferior, não deve ser alterada sem nova autorização.

### Autenticação e comunicação local

- O login chama a API local na porta `5056`.
- A autenticação usa o cadastro de vendedores do ParmaGestor (`TB_VENDEDOR`).
- A empresa e o vendedor são derivados no servidor no momento do login e armazenados na sessão Bearer efêmera; não são recebidos do aplicativo em cada consulta.
- Para ensaios por USB em aparelho físico, permanece necessária a configuração de `adb reverse` para a porta `5056`.
- Esta topologia é exclusiva de desenvolvimento local; não é arquitetura de produção para vendedores externos.

### Home

- Layout aprovado e preservado.
- Ações disponíveis: Novo Pedido, Meus Pedidos, Meus Clientes, Financeiro e Novo Cliente.
- Resumo demonstrativo e navegação inferior permanecem demonstrativos.

### Novo Pedido

- Cabeçalho amarelo e duas abas: **Pedido** e **Itens**.
- Aba Pedido: pesquisa de clientes, formas de pagamento e observações.
- Aba Itens: seleção por cartões, quantidade, inclusão, edição e exclusão.
- O rascunho é mantido ao alternar entre as abas.
- A quantidade precisa ser positiva.
- Não há gravação, envio ou sincronização de pedidos implementados.

### Integração Firebird em leitura

- `GET /api/v1/catalogo/clientes?termo=...`, autenticado.
- `GET /api/v1/catalogo/formas-pagamento`, autenticado.
- `GET /api/v1/catalogo/produtos-touch`, autenticado.
- Produtos touch exigem grupo com `PGRU_MOSTRAR = 'S'`.
- Todas essas consultas derivam a empresa da sessão e utilizam transação Firebird somente leitura.

## Auditoria de login, empresa e clientes — 22/10/2026

### Banco e contexto de sessão

A configuração local atual da API declara:

| Item | Resultado |
| --- | --- |
| Firebird | `127.0.0.1:3050` |
| Banco | `E:\Dados Clientes\Tekno Prime\DADOS.FDB` |
| Login auditado | `EU` |
| Vendedor ativo encontrado | empresa `1`, vendedor `12` |
| Registros ativos para o login `EU` | 1 |

O login pesquisa `TB_VENDEDOR` por `UPPER(TRIM(VDR_LOGIN))`. Após a validação de senha, a API grava na sessão os valores de `VDR_EMPRESA` e `VDR_ID`. Assim, para `EU`, clientes, produtos touch e formas de pagamento usam empresa `1` e vendedor `12` onde aplicável.

No banco Tekno Prime, a empresa 1 retornou 4 produtos touch e 22 formas de pagamento ativas na auditoria. A homologação manual do fluxo no aparelho ainda é necessária.

### Pesquisa de clientes `MARIA`

A API aplica a seguinte regra, com limite de 30 itens:

```sql
SELECT FIRST 30 C.CLI_ID, C.CLI_RSOCIAL_NOME, C.CLI_FANTASIA_APELIDO
FROM TB_CLIENTE C
WHERE C.CLI_EMPRESA = :empresa
  AND C.CLI_VENDEDOR = :vendedor
  AND C.CLI_STATUS = 'A'
  AND (
    UPPER(C.CLI_RSOCIAL_NOME) LIKE :termo
    OR UPPER(C.CLI_FANTASIA_APELIDO) LIKE :termo
    OR CAST(C.CLI_ID AS VARCHAR(20)) LIKE :termo
  )
ORDER BY C.CLI_RSOCIAL_NOME
```

| Medição para `MARIA` no banco Tekno Prime | Quantidade |
| --- | ---: |
| Clientes ativos da empresa 1, sem filtro de vendedor | 110 |
| Clientes da empresa 1 vinculados ao vendedor 12 | 0 |
| Clientes ativos da empresa 1 sem vendedor atribuído | 103 |
| Itens retornados ao login `EU` | 0 |

**Causa comprovada:** o resultado vazio decorre do filtro obrigatório de carteira (`CLI_VENDEDOR = 12`), e não da ausência de clientes, do termo ou da empresa. A maior parte dos resultados encontrados não tem vendedor atribuído.

### Comparação com o desktop

A consulta padrão do ParmaGestor desktop para pesquisa de clientes filtra empresa e situação ativa, mas não inclui `CLI_VENDEDOR` como filtro fixo. Isso explica por que o desktop da empresa 1 exibe clientes contendo `MARIA`, enquanto o aplicativo não os exibe para o vendedor 12.

### Decisão pendente

Não alterar a regra atual sem decisão comercial. É necessário definir se o tablet `EU` deve:

1. ver somente a carteira do vendedor 12;
2. ver a carteira do vendedor 12 e os clientes sem vendedor; ou
3. ver todos os clientes ativos da empresa 1.

## Pendências para retomada

1. Definir e homologar a regra comercial da pesquisa de clientes para o vendedor `EU`.
2. Homologar no aparelho a empresa e o vendedor recebidos na sessão.
3. Validar manualmente os quatro produtos reais touch da Tekno Prime.
4. Conferir as formas de pagamento retornadas para a empresa 1.
5. Revisar apenas os detalhes visuais que ainda forem apontados pelo usuário.
6. Projetar persistência de rascunhos e funcionamento offline.
7. Projetar envio e sincronização de pedidos pela internet.
8. Implementar gravação real de pedidos somente após as regras comerciais serem definidas e homologadas.

O aplicativo **não está pronto para produção**.

## Arquitetura e proteções futuras

Como o aplicativo será usado por vendedores externos, a solução definitiva precisa de API HTTPS acessível externamente, autenticação e autorização no servidor, isolamento obrigatório por empresa, regras de carteira, persistência offline, sincronização idempotente contra pedidos duplicados e validação no servidor de preços e permissões comerciais.

O Firebird não deve ser exposto ao aplicativo externo. As pastas `E:\Jorginho\BarCode\BarCodeNovo` e `E:\Jorginho\AppMotorista` permanecem referências exclusivamente para consulta. Todo desenvolvimento deste aplicativo deve permanecer em `E:\Jorginho\Malha_Confeccao`; projetos Delphi e bancos Firebird não devem ser modificados por este projeto.

## Próxima ação recomendada

Obter a decisão comercial para a visibilidade dos clientes sem vendedor no tablet `EU`. Após autorização explícita, implementar somente a regra aprovada e homologar o fluxo no aparelho antes de avançar para gravação ou sincronização de pedidos.
