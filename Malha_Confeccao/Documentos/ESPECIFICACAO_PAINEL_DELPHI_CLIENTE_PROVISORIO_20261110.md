# Painel Delphi — dados ampliados do cliente provisório

O painel deve consultar `TB_MALHA_CLIENTE_PROV_REC` e exibir, além dos dados já existentes, inscrição estadual, e-mail, WhatsApp, CEP, logradouro, número, complemento, bairro, cidade e UF. Valores nulos devem aparecer como não informados, sem impedir a consulta do pedido.

## Conversão para cliente fixo

Exibir a ação **Transformar em Cliente Fixo** somente após auditoria específica das regras do ParmaGestor: empresa, documentos, duplicidades, campos obrigatórios, transação e retorno ao pedido. Esta entrega não cria botão de fachada, não grava em `TB_CLIENTE` e não altera tabelas oficiais.
