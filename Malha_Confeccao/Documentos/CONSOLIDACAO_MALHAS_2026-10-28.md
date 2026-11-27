# Consolidação geral — App Malhas/Confecção

**Data:** 28/10/2026  
**Escopo:** consolidação documental baseada nos registros existentes e nas auditorias de 27 e 28/10. Nenhum código, banco, serviço, script operacional ou configuração foi modificado por este documento.

## Estado funcional comprovado

Fluxo validado em testes externos controlados:

`Flutter → API HTTPS → PostgreSQL malhas_nuvem → Agente Malhas → Firebird Tekno Prime → Painel Delphi`

Há evidência de pedidos recebidos pela API HTTPS, processados pelo Agente, gravados no Firebird e apresentados no painel Delphi. Isso não declara operação geral de produção. Foi relatada demonstração no Samsung S20, com espelhamento por scrcpy e gravação por OBS Studio; não há artefatos desses programas na documentação consultada, portanto não se atribui a eles validação técnica adicional.

## Marco histórico — pedido externo 26

Em 28/10, aproximadamente às 09h20 locais, foi auditado somente por consultas o pedido 26, Tekno Prime, vendedora Camilla Pires Duriguetto, cliente Carlos Eduardo da Silva Pinto, total R$ 2.344,00 e dois itens.

- UUID original: `fd31f9a4-2a54-4316-8e81-58461db40b3b`.
- UUID remoto: `20077e94-cb54-4c71-bd62-93f05e6986f4`.
- Um único pedido na nuvem, um cabeçalho no Firebird, dois itens e valores comerciais preservados.
- Uma tentativa, sequência `RECEBIDO_NUVEM → CLAIMED → ACK`, sem duplicidade ou erro; horários UTC e locais coerentes.

**Resultado: APROVADO COM RESSALVAS.** O Firebird não persiste diretamente o UUID remoto. A vinculação foi comprovada pelo UUID original, ACK e log do Agente. Decisão atual: não alterar a estrutura Firebird apenas por esse campo; persistência do UUID remoto é melhoria futura. Não havia arquivo dedicado dessa auditoria em `Documentos`; este é o registro consolidado. Dados pessoais não devem ser repetidos em material de compartilhamento externo.

## Melhorias Flutter de 27/10

Conforme `RELATORIO_TRABALHOS_2026-10-27.md`:

- Login reorganizado, sem textos demonstrativos, com ações de teclado e bloqueio contra submissão simultânea; contrato de autenticação preservado.
- Novo Pedido com rótulos, previsão destacada, Gerencial Sim/Não, observação multilinha e validação obrigatória de cliente, pagamento, prazo e gerencial.
- Carrinho com confirmação não bloqueante; o overflow de 179 pixels foi corrigido por margem, largura máxima e texto flexível.
- Meus Pedidos passou a distinguir pendentes/recebidos e ordenar pendentes antes dos recebidos sem gravar dados.
- UUID, preços, cliente, pagamento, prazo, itens e snapshots comerciais permanecem preservados.

Na manhã de 27/10 houve diagnóstico de sintaxe, mocks, persistência e testes. Existe registro histórico de 13 testes aprovados e análise sem erro de compilação; execuções posteriores de `dart format`, `flutter analyze` e `flutter test` não retornaram saída por bloqueio de processos Dart. Correções posteriores não são declaradas aprovadas sem execução observável.

## Regras permanentes da integração

- UUID original e idempotência impedem duplicidade.
- Preços, quantidades, subtotais, totais, pagamento, prazo, previsão, gerencial e observações são snapshots; não são recalculados.
- O Agente confirma ACK somente após commit transacional no Firebird.
- Isolamento de empresa/vendedor, autenticação das rotas e Firebird não exposto à internet são obrigatórios.
- Falha após commit e antes do ACK é recuperada por claim expirável e idempotência.

## Offline — aprovado conceitualmente, não implementado

Os testes de 28/10 confirmaram que login e pesquisa de clientes dependem da API e que não há catálogo persistente completo após reabrir o app. A mensagem legada sobre USB também é inadequada para uso externo.

O proprietário aprovou: primeiro acesso online; autorização offline segura sem senha em texto puro; SQLite com carteira autorizada, produtos/preços, pagamentos, empresa, vendedor e data da última sincronização; sincronização automática na primeira utilização online diária e atualização manual; pesquisa local sem fallback automático; preservação do último catálogo íntegro; e pedidos offline com UUID e valores originais. O prazo máximo sem sincronizar ficará configurável futuramente, sem bloqueio nesta etapa.

O diagnóstico de 28/10 identificou a necessidade de endpoint autenticado de snapshot completo/paginado da carteira: a rota atual de clientes é limitada e não prepara com segurança o catálogo inteiro. Não houve implementação autorizada.

## Backup restaurável

O documento [BACKUP_E_RESTAURACAO_MALHAS_2026-10-28.md](BACKUP_E_RESTAURACAO_MALHAS_2026-10-28.md) registra `BACKUP_MALHAS.bat`, que usa WinRAR a partir de cópia temporária, sem seguir links WSL, e exclui artefatos, segredos e backups anteriores.

- RAR validado: `Malha_Confeccao_2026-10-28_10-24-27.rar`.
- SHA-256: `16F1CF989E0C0E496F29112CA11B9BB4FFC1578DB45B28AD5B09FE3F917D3388`.
- Compactação, integridade e extração isolada aprovadas; arquivos essenciais presentes e `.env`, caches, links WSL e ambientes virtuais ausentes.

**Classificação: VALIDADO APENAS PARA EXTRAÇÃO.** A compilação restaurada permanece pendente pelo bloqueio/ausência de saída Flutter/Dart. O RAR comum não substitui backup protegido de credenciais, keystore Android, estado do Agente, PostgreSQL ou Firebird.

## Pendências e ponto de retomada

### Prioridade imediata

1. Retomar o diagnóstico/plano de login offline, SQLite e sincronização de catálogo.
2. Não iniciar implementação offline sem autorização expressa.

### Segurança e recuperação

- Executar compilação/testes em cópia restaurada quando Flutter/Dart voltar a fornecer resultado observável.
- Definir backup protegido de configurações, keystore, estado do Agente e acessos de recuperação.
- Manter procedimentos independentes e testados de `pg_dump`/`pg_restore` e `gbak`.

### Melhorias futuras

- Prazo máximo configurável sem sincronização.
- Persistência eventual do UUID remoto no Firebird.
- Revisão do histórico de pedidos enviados e demais melhorias já registradas.

**Estado atual:** aplicativo funcional nos testes online; integração externa comprovada pelo pedido 26; auditoria aprovada com ressalva; backup validado para extração; compilação restaurada pendente; offline completo não implementado.

**Próxima etapa:** apresentar/retomar o diagnóstico técnico de login offline, SQLite e sincronização de catálogo, aproveitando a arquitetura existente. Aguardar autorização antes de implementar.
