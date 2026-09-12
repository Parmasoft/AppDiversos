# Canonicalizacao semantica V1

Esta especificacao e imutavel dentro de `contrato_versao = 1`.

1. O documento semantico e o objeto raiz depois de remover somente
   `snapshot_id`, `snapshot_revision`, `semantic_hash` e `gerado_em`.
2. `contrato_versao` permanece no documento.
3. Objetos tem chaves Unicode ordenadas lexicograficamente; arrays preservam a
   ordem recebida.
4. A serializacao usa JSON compacto, separadores `,` e `:`, sem espacos, e
   bytes UTF-8 sem BOM.
5. `null`, booleanos e inteiros usam as representacoes JSON `null`, `true`,
   `false` e decimal base 10.
6. Strings preservam seus code points; nao ha normalizacao Unicode implicita.
   O escape e o produzido pelo encoder JSON, com `ensure_ascii=false`.
7. Numeros JSON nao inteiros nao sao aceitos. Quantidades, coordenadas e demais
   decimais do contrato devem permanecer strings em formato definido pelo
   produtor. NaN e infinitos nao sao aceitos.
8. O `semantic_hash` e SHA-256 lowercase hexadecimal dos bytes canonicos.

Qualquer mudanca dessas regras exige nova versao de contrato e novos vetores.
Os arquivos `canonicalization-v1-vectors.json` do Agente e da Nuvem devem ser
literalmente iguais.
