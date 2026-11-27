# Operação futura — Agente Malhas

Este material prepara a instalação futura. Não registra tarefa, não cria usuário,
não inicia o Agente e não contém credenciais reais.

## Pré-requisitos de instalação futura

1. Confirmar o DNS e o certificado de `https://malhas.parmatech.com.br`.
2. Usar uma conta local dedicada, sem privilégios administrativos, com acesso ao
   Firebird e às pastas do Agente estritamente necessários.
3. Criar `C:\ProgramData\ParmaSoft\AgenteMalhas` e limitar a leitura do arquivo
   `agente-malhas.env` à conta do Agente e administradores autorizados. A conta
   precisa modificar somente `state.db`, `state.db.lock`, `stop.request` e `logs`.
4. Criar virtualenv e instalar as dependências já aprovadas. Não usar credenciais
   do Motorista, nem seu banco, serviços, certificados ou diretórios.
5. Copiar o exemplo de ambiente para fora do Git, inserir os valores autorizados
   e manter `MALHAS_AGENT_API_URL` em HTTPS. HTTP somente é aceito em loopback
   com a chave explícita de teste local.

## Agendador de Tarefas

Importar o XML somente depois de substituir o usuário de exemplo por uma conta
dedicada e informar a senha no próprio Agendador. A senha não deve constar no
XML, em scripts ou em logs. Selecionar “Executar estando o usuário conectado ou
não” e validar que a conta consegue ler o ambiente e acessar o Firebird sem
interface gráfica. O gatilho é de inicialização do computador; não depende do
Delphi aberto. `IgnoreNew` e o lock do processo impedem instâncias concorrentes.

Antes de ativar, executar uma única vez sob a mesma conta e verificar: criação
de `state.db`, escrita do log, acesso autorizado ao Firebird e health HTTPS.
Essa validação futura não deve criar ou alterar dados comerciais.

## Parada controlada e reinício

Para manutenção: desabilitar a tarefa, criar o arquivo vazio definido em
`MALHAS_AGENT_STOP_FILE` e aguardar o registro “Parada controlada solicitada”.
O Agente termina após o ciclo corrente; não finalizar o processo à força salvo
incidente. Para retomar, apagar o marcador, habilitar a tarefa e usar “Executar”.
Após reinicialização do computador, o Agendador inicia o processo novamente.

## Recuperação

Em indisponibilidade de internet/API, o Agente repete o ciclo no intervalo
configurado e mantém snapshots pendentes no SQLite. Se houver commit Firebird
antes de falha do ACK, o claim expira e a chave idempotente impede nova gravação
do mesmo pedido. O conteúdo comercial original e seu hash permanecem intactos.
Falhas inesperadas encerram o processo com código não zero para o Agendador
reiniciar; após três falhas consecutivas, investigar o log e o alerta operacional.

## Logs e token

Os logs registram início, falha/recuperação de comunicação, confirmação de
pedido, erro inesperado e parada controlada. Não registram token, senha ou
payload completo. Rotação padrão: 5 MiB por arquivo e cinco históricos.

Para rotação do token: provisionar uma segunda credencial autorizada, atualizar
somente o arquivo protegido, executar parada/reinício controlado, validar
autenticação e então revogar o token anterior. Nunca reutilizar token ou segredo
do Motorista.
## Registro operacional — 26/10/2026

O cenário descrito como futuro nas seções históricas abaixo foi ativado e
validado nesta data. A tarefa agendada é `ParmaSoft - Agente Malhas`, executada
por `NT AUTHORITY\SYSTEM`, com gatilho de inicialização do computador e sem
dependência de login interativo. O registro de operação informa estado
`Running` e logs com sincronizações bem-sucedidas.

Permanecem preservados o arquivo externo de ambiente
`C:\ProgramData\ParmaSoft\AgenteMalhas\agente-malhas.env`, os logs em
`C:\ProgramData\ParmaSoft\AgenteMalhas\logs` e o lock exclusivo associado ao
estado do Agente. Nenhum segredo é registrado neste documento. Não reiniciar,
reconfigurar ou substituir a tarefa por causa deste registro documental.

