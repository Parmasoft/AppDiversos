# Encerramento — App Malhas/Confecção — 31/10/2026 (noite)

## Contexto e decisão
Jorginho retomou a funcionalidade **Novo Cliente** do App Malhas/Confecção após a responsável da Confecção informar que o cadastro do vendedor deve ser mais completo. Foi apresentada a lista: nome, CNPJ, inscrição estadual, telefone, e-mail, rua, número, bairro, CEP, cidade/estado. O proprietário acredita que o vendedor preencherá todos os campos, **mas a obrigatoriedade será confirmada posteriormente com a funcionária**. Não fixar obrigatoriedade agora.

O usuário mostrou o painel Delphi com pedido de **Nathalia**, em 29/10/2026, total **R$ 7.845,00**, marcado **PROVISÓRIO = SIM** e **RECEBIDO**; contador de clientes provisórios = 1. A imagem comprova identificação do pedido provisório no painel, mas não todos os campos armazenados nem aprovação do cliente.

## Auditoria do Codex nesta noite — somente leitura
**Nenhuma alteração** de Flutter, SQLite, API, PostgreSQL, Agente, Firebird, Delphi, serviços ou APK.

### Implementado segundo análise do código
- Flutter: cadastro PF/PJ; nome/razão social obrigatório (mín. 3 caracteres); CPF/CNPJ obrigatório e validado conforme tipo; telefone obrigatório, com DDD e máscara (10/11 dígitos); nome fantasia opcional para PJ.
- Não existe campo específico de WhatsApp.
- SQLite: cliente provisório com `local_id`, empresa, vendedor, tipo de pessoa, nome, documento, telefone, fantasia, situação, possível ID oficial e datas; unicidade local empresa/vendedor/documento.
- Pedido referencia `local-client:<local_id>`.
- Cliente segue **dentro do pedido**, em `POST /pedidos`, como `cliente.provisorio`, com `local_id`, `tipo_pessoa`, `nome`, `fantasia`, `cpf_cnpj`, `telefone`. Não há rota própria de envio do cliente.
- PostgreSQL: JSON do pedido e registro em `malhas_cliente_provisorio`.
- Agente: grava tipo, nome/razão, fantasia, CPF/CNPJ, telefone em `TB_MALHA_CLIENTE_PROV_REC`; associação do pedido via `MPR_CLIENTE_PROVISORIO`. Identidade por empresa/vendedor/origem FLUTTER/local_id.
- Recepção de pedidos provisórios é comprovada na interface Delphi pela imagem enviada.

### Campos ainda inexistentes de ponta a ponta
Inscrição Estadual, e-mail, rua, número, bairro, CEP, cidade, estado. WhatsApp específico também não existe.

### Risco técnico descoberto
A API possui restrição única para cliente provisório, mas aparentemente tenta inseri-lo novamente a cada novo pedido. **Reutilizar o mesmo cliente provisório em pedidos diferentes pode provocar conflito**. Isso é risco identificado, não falha reproduzida. Validar e corrigir antes de liberar o fluxo ampliado. Preservar idempotência do pedido e do cliente.

### Limitações da auditoria
- O Codex não tinha fontes Delphi no repositório auditado; não comprovou campos lidos pelo painel nem rotinas de aprovação/conversão para cliente oficial.
- Não conseguiu consultar diretamente o caso Nathalia no PostgreSQL/Firebird por falta de acesso operacional no escopo. Não afirmar que todos os dados da Nathalia foram verificados.
- A documentação histórica de 23/10 citava CPF/CNPJ; a auditoria atual confirmou sua existência no código, apesar de dúvida inicial do proprietário.

## Regras de preservação
- Não recriar infraestrutura homologada de pedidos: Flutter → HTTPS → PostgreSQL → Agente → Firebird → Painel Delphi.
- Preservar clientes e pedidos antigos sem novos atributos, snapshot comercial original, `local_id`, vínculo `local-client:`, isolamento empresa/vendedor e idempotência.
- Não inserir cliente diretamente no cadastro oficial sem auditar regras Delphi/ERP; evitar duplicidade por CPF/CNPJ.
- Não decidir ainda se telefone e WhatsApp serão um campo ou campos separados.
- Não remover suporte PF/CPF nem nome fantasia já implementados.

## Próxima retomada — uma etapa por vez
1. Confirmar com a responsável quais campos serão obrigatórios, se atende PF/CPF, se telefone é WhatsApp e como tratar dados faltantes.
2. Testar pontualmente o reuso do mesmo cliente provisório em dois pedidos; corrigir se o risco se confirmar.
3. Planejar ampliação compatível de Flutter/SQLite, contrato/API/PostgreSQL, Agente/Firebird; sem executar sem autorização.
4. Auditar fontes Delphi no repositório correto para entender visualização, aprovação e inclusão oficial; depois definir implementação da aprovação.
5. Homologar um cadastro novo e seus pedidos de ponta a ponta, verificando os campos efetivamente persistidos.

## Estado ao encerrar
**Somente levantamento e auditoria realizados nesta noite. Nenhuma implementação autorizada ou executada.** O projeto Central Financeira Matriz/Filiais foi adiado para terça-feira 03/11/2026 pela manhã, para análise com calma; não misturar os projetos.
