# Último ponto — App Motorista

## 23/11/2026 — projeção derivada V2 implantada na Nuvem

Produção atualizada para Alembic `20261123_0005`; `delivery_confirmation_projection` foi reconstruída apenas para o manifesto da carga 776. Há quatro confirmações, zero duplicidades e duas recusas históricas excluídas. O snapshot Firebird bruto permanece em `P`; a visão efetiva devolve os três pedidos e as três paradas em `E`. Health local e público retornaram HTTP 200; retorno Firebird continua desabilitado.

Próximo passo único: conferir no S20 apenas a visualização atualizada da viagem; não reenviar leituras nem habilitar retorno Firebird sem nova autorização.

Atualizado em 23/11/2026.

## Tarefa atual

Projetar e homologar uma visão autoritativa de entrega na Nuvem que derive os
estados operacionais do ledger aceito, antes de encerramento ou retorno Firebird.

## Bloqueio confirmado

As leituras reais foram auditadas no ledger: quatro aceitações, uma por ocorrência,
e duas recusas históricas terminais. Porém a projeção do manifesto permanece em
`P` por desenho atual; não há estado persistido de pedido/parada/manifesto entregue
nem retorno Firebird habilitado.

O offline está implementado em SQLite/outbox e coberto por testes automatizados,
mas não foi validado no Samsung em modo avião. A projeção Nuvem atual é uma cópia
do snapshot Firebird e não incorpora o ledger V2, por decisão explícita do código.

## Próximo passo único

Criar proposta técnica para uma visão derivada de aceites V2 (ou projeção derivada
materializada) com unicidade por ocorrência, reconstrução e testes de concorrência;
em paralelo, executar futuramente teste manual offline em carga fictícia isolada.
Não reenviar operações históricas, encerrar viagem ou habilitar retorno Firebird.

## Restrições ativas

- Sem deploy, restart, migration, escrita DigitalOcean ou leitura real no S20.
- Sem retorno Firebird, `SP_APL_ENTREGA_NUVEM`, claim/ack ou agente contínuo.
- Preservar mudanças locais; não usar reset/checkout.
- Registrar imediatamente no diário cada avanço, bloqueio ou mudança de direção.
