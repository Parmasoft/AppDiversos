# Atualização vigente — 26/10/2026

O estado vigente superou as pendências históricas abaixo: em 26/10/2026 foi
homologado o fluxo Samsung → HTTPS → API DigitalOcean → PostgreSQL → Agente
Windows → Firebird → Painel Delphi. O Agente está configurado para execução
automática pela tarefa `ParmaSoft - Agente Malhas` sob `NT AUTHORITY\SYSTEM`,
com logs e ambiente protegidos em `C:\ProgramData\ParmaSoft\AgenteMalhas`.

O painel Delphi foi aprovado visualmente com sete pedidos recebidos e aguardando
análise. Ele atualiza a cada 15 segundos sem perder seleção, preserva snapshots
comerciais e isola a empresa corrente. A conversão em Pedido de Venda continua
não implementada e exige definição explícita antes de qualquer ação.

O estado operacional atual, a auditoria de clientes e as pendências estão em [ENCERRAMENTO_20261022.md](ENCERRAMENTO_20261022.md). A integração local autenticada e a auditoria do vendedor `EU` superam as pendências de login registradas abaixo em 21/10.

O histórico abaixo foi preservado sem alteração.

# Status — Pedidos de Malhas

Data: 21/10/2026

## Entregue e validado

- Telas Flutter de Login, Inicial do Vendedor e Novo Pedido, com visual aprovado nas etapas anteriores.
- Pesquisas demonstrativas de clientes e produtos na tela Novo Pedido.
- API Flask modular em `api/`, com configuração por `.env`, conexão Firebird de leitura e endpoint `/health`.
- Conexão de teste com o banco local GramDecor validada por `SELECT 1 FROM RDB$DATABASE` em transação somente leitura.
- Inicializador `iniciar_api_malhas.bat`.
- Correção do carregamento do `.env` independentemente do diretório do terminal.
- Testes automatizados da API aprovados e `flutter analyze` concluído sem problemas nas validações anteriores.
- Estrutura de autenticação local baseada em `TB_VENDEDOR`: `VDR_LOGIN`, `VDR_SENHA`, `VDR_EMPRESA`, `VDR_ID` e `VDR_STATUS`.
- Sessão Bearer efêmera, com expiração de 15 minutos, exclusivamente para desenvolvimento local.
- Android debug preparado para HTTP local; ADB reverse para a porta 5056 comprovado.
- Logs HTTP sanitizados na API: horário, método, caminho, status e duração; sem senha, token, corpo ou Authorization.

## Não homologado

O login real de vendedor no Samsung permanece **PENDENTE / NÃO HOMOLOGADO**. A comunicação do navegador do Samsung com `/health` foi comprovada, mas não há confirmação de que a tentativa de login tenha chegado à instância atual da API. Mensagens observadas: “API indisponível. Verifique USB.” e “Rota não encontrada.”

Uma instância antiga da API, sem a rota de autenticação, foi identificada como causa comprovada de um 404 anterior. Não está comprovado que todas as tentativas posteriores utilizaram a instância atual.

## Próximo passo único

Diagnosticar a instância que atende a porta 5056 e homologar o login real no Samsung. Não iniciar consultas comerciais, pedidos, sincronização ou publicação externa antes dessa homologação.
