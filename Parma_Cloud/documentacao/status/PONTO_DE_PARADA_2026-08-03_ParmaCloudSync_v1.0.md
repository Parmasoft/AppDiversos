# Ponto de Parada - 03/08/2026

Projeto: ParmaCloudSync v1.0
Cliente piloto: Fabri Tecidos
Status: versao atual funcional e aprovada; Portal da Fabri com produtos reais, ultima compra e layout mobile aprovado

## Resumo Geral

Em 03/08/2026 foram concluidas as etapas de limpeza controlada da nuvem, nova sincronizacao manual com o banco real da Fabri Tecidos, implantacao do campo de ultima compra, validacao real da regra de compra e refinamento do layout mobile do Portal.

O estado final aprovado e:

```text
Banco real Fabri
    -> ParmaCloudSync manual no servidor da Fabri
    -> API Flask/Gunicorn na DigitalOcean
    -> Firebird na DigitalOcean
    -> Portal via Nginx
```

Nao executar novas alteracoes operacionais sem novo backup e nova autorizacao.

## 1. Limpeza Controlada da Nuvem

Foi removido somente o conteudo de:

```sql
TB_PORTAL_PRODUTO
WHERE PPR_CLIENTE = 2
```

Resultado:

```text
Produtos antes: 2958
Produtos depois: 0
```

Foram preservados:

- cliente 2;
- usuarios;
- token;
- hashes de senha;
- estrutura do banco;
- produtos de outros clientes.

Nenhum produto de outro cliente foi removido.

Backup fisico anterior a limpeza:

```text
/var/lib/firebird/backups/cotacao_antes_limpeza_fabri_20260803_121723.fdb
Tamanho: 2.899.968 bytes
SHA256: b99ed8054a7fa5cffac476bc5633344f566bfb47f4cfe879b19b77076c4fd98f
```

Ao final da limpeza, Firebird, API/Gunicorn e Nginx ficaram ativos.

## 2. Nova Sincronizacao Com o Banco Real da Fabri

Servidor real da Fabri:

```text
C:\Parmasoft_Cloud
```

Banco real:

```text
127.0.0.1/3050:C:\Parmasoft\Dados\DADOS.FDB
```

Python funcional existente no servidor:

```bat
venv\Scripts\python.exe
```

Observacao:

- o Python global chamado apenas por `python` nao possuia a dependencia `requests`;
- por isso, o Python global nao foi usado para a carga;
- a execucao aprovada usou o Python do `venv`.

Validacao aprovada:

```bat
venv\Scripts\python.exe main.py --testar-conexao
```

Sincronizacao manual executada:

```bat
venv\Scripts\python.exe main.py --uma-vez
```

Resultado:

```text
Produtos encontrados: 3154
Produtos enviados: 3154
Lotes concluidos: 32
Duracao aproximada: 16,88 segundos
Sincronizacao concluida com sucesso
```

O Servico do Windows ParmaCloudSync ainda nao esta instalado no servidor real da Fabri.

A execucao continua manual nesse servidor.

## 3. Campo de Ultima Compra

Objetivo implementado:

- exibir data da ultima compra;
- exibir numero da nota fiscal;
- preservar e exibir serie no desktop;
- omitir serie apenas no painel mobile para ganhar espaco.

Regra especifica aprovada para a Fabri:

```sql
PC.PRDC_ORIGEM = 'NOTA'
AND NF.NF_ENTRADA_SAIDA = 'E'
AND NF.NF_FORNECEDOR IS NOT NULL
AND NF.NF_STATUS = 'D'
AND COALESCE(NF.NF_FINALIDADE, 1) = 1
AND NF.NF_NATUREZA_OPERACAO IN (3,4,5,6,29,30)
```

Ordenacao:

```sql
ORDER BY NF.NF_DT_LANCAMENTO DESC, NF.NF_ID DESC
```

Origem utilizada:

```sql
TB_PRODUTO_CUSTO PC
JOIN TB_NOTA_FISCAL NF
```

Foi escolhida `NF_DT_LANCAMENTO`, e nao `NF_DT_EMISSAO`, porque representa a entrada no ERP e evita anomalias de datas de emissao digitadas incorretamente.

Campos adicionados em `TB_PORTAL_PRODUTO`:

```sql
PPR_DT_ULTIMA_COMPRA TIMESTAMP
PPR_NF_ULTIMA_COMPRA VARCHAR(30)
PPR_SERIE_ULTIMA_COMPRA VARCHAR(10)
```

Backup fisico anterior a criacao dos campos:

```text
/var/lib/firebird/backups/cotacao_antes_ultima_compra_20260803_155057.fdb
Tamanho: 2.899.968 bytes
SHA256: 336d128853820a3f15271002869f971b8e5a8101b081adb35404b642c6089ee1
```

API e Portal foram publicados com suporte aos novos campos.

Backup remoto anterior a publicacao da API e do Portal com ultima compra:

```text
/var/www/cotacao/backups/portal_ultima_compra_20260803_155733
```

Regra de compatibilidade da API:

- chave ausente no payload: preserva valor existente;
- chave presente com valor: grava o valor;
- chave presente com `null`: grava `null`.

## 4. Validacao Real da Ultima Compra

Produto validado no servidor real:

```text
Produto: 4746
Descricao: CAMBRAIA BORDADA BONECA / PACIFIC / LARANJA FOX
Custo: 29,3448
Estoque: 75,00
```

Ficha de movimentacao:

```text
Entrada: 30/05/2026
Nota fiscal recebida: 114259
Serie: 1
Quantidade: 25,0000
```

Na propria nota:

```text
Data de emissao: 27/03/2026
Data de entrada: 30/05/2026
Numero: 114259
Serie: 1
Natureza: compra para comercializacao fora de MG
```

O Portal retornou corretamente:

```text
Ultima compra: 30/05/2026
NF: 114259
```

Essa validacao confirmou a regra usando `NF_DT_LANCAMENTO`.

## 5. Layout Final do Portal

URL atual:

```text
http://165.227.77.226/portal/fabritecidos
```

### Desktop

O desktop permanece em formato de tabela:

- codigo;
- descricao;
- unidade;
- estoque;
- custo;
- preco;
- ultima compra abaixo da descricao;
- serie exibida;
- alternancia branco/amarelo-claro preservada.

### Mobile

Cada produto e apresentado em painel continuo com tres linhas visuais.

Area esquerda:

- codigo formatado visualmente com seis digitos e zeros a esquerda;
- hifen entre codigo e descricao;
- unidade fixa na segunda linha;
- descricao com no maximo duas linhas;
- continuacao alinhada abaixo do inicio da descricao;
- ultima compra e NF na terceira linha;
- serie omitida somente no mobile para ganhar espaco.

Exemplo:

```text
COD: 004746 - CAMBRAIA BORDADA BONECA / PACIFIC /
UN: MT         LARANJA FOX
ULTIMA COMPRA: 30/05/2026    NF: 114259
```

Area direita:

```text
ESTOQUE: 75,00
CUSTO:   29,34
VENDA:   69,98
```

Caracteristicas finais:

- coluna direita separada por linha vertical de 2px;
- rotulos em negrito;
- valores em peso normal;
- sem linhas horizontais internas;
- sem caixas internas;
- sem sombras internas;
- alternancia branco/amarelo-claro;
- sem rolagem horizontal;
- painel validado em celular real;
- desktop permaneceu inalterado.

O layout final foi aprovado visualmente por Jorge em 03/08/2026.

## 6. Estado Atual dos Arquivos Publicados na DigitalOcean

Consulta feita por leitura em 03/08/2026.

Arquivos atuais:

```text
/var/www/cotacao/static/portal/index.html
Tamanho: 4.490 bytes
SHA256: 0ac86f24d1ea3c84553a78f6f04b2a246ec516ec9e2dde3a5f72a17289492b24

/var/www/cotacao/static/portal/portal.js
Tamanho: 16.906 bytes
SHA256: b822ea2c1214586c70ff7a625ac690cbbb3f032d99baea0f4837cc88a0e79496

/var/www/cotacao/static/portal/portal.css
Tamanho: 10.765 bytes
SHA256: d4fdea2c53b41a4559bdfdda32fa04e78ee579b6fd3738a805c8fb0603266f8c
```

Versionamento atual no `index.html`:

```html
<link rel="stylesheet" href="/static/portal/portal.css?v=20260803_cards_mobile_5">
<script src="/static/portal/portal.js?v=20260803_cards_mobile_5"></script>
```

Backup remoto mais recente criado antes da publicacao final do layout mobile:

```text
/var/www/cotacao/backups/portal_antes_cards_mobile_5_20260803_192134
```

## 7. Pastas Locais e Backups Relevantes

As seguintes pastas foram confirmadas por leitura e existem no ambiente local:

```text
E:\Jorginho\Parma_Cloud\backups\ultima_compra_fabri_20260803_122503
E:\Jorginho\Parma_Cloud\digitalocean_publicados_ultima_compra_20260803_123558
E:\Jorginho\Parma_Cloud\backup_layout_atual_antes_cards_mobile_20260803_141948
E:\Jorginho\Parma_Cloud\ajuste_cards_mobile_20260803_5
```

Outras pastas de trabalho locais do layout mobile tambem permaneceram preservadas:

```text
E:\Jorginho\Parma_Cloud\ajuste_cards_mobile_20260803_2
E:\Jorginho\Parma_Cloud\ajuste_cards_mobile_20260803_3
E:\Jorginho\Parma_Cloud\ajuste_cards_mobile_20260803_4
E:\Jorginho\Parma_Cloud\publicacao_cards_mobile_20260803_5
```

## 8. Pendencias Futuras

Tratar separadamente, sem misturar com a versao atualmente aprovada:

- instalar definitivamente o Servico do Windows ParmaCloudSync no servidor real da Fabri;
- usar o procedimento correto de runtime definido na homologacao, apos avaliar a instalacao existente no servidor;
- desenvolver o instalador profissional;
- testar o Portal com o Fabricio e anotar possiveis novos campos;
- HTTPS;
- dominio amigavel;
- fechamento futuro da exposicao direta da porta 5000;
- revisao futura do encerramento do Gunicorn;
- nao misturar essas melhorias com a versao atualmente aprovada.

## 9. Ponto Oficial de Retomada

A versao atual esta funcional e aprovada.

Na retomada:

- nao limpar novamente a nuvem;
- nao repetir sincronizacao sem necessidade;
- nao alterar layout aprovado sem novo backup;
- comecar pela avaliacao da instalacao automatica do ParmaCloudSync no servidor real da Fabri;
- depois planejar o instalador profissional.

## 10. O Que Nao Foi Feito Nesta Atualizacao Documental

Nesta atualizacao documental:

- nenhum codigo foi alterado;
- nenhum arquivo foi publicado;
- nenhum banco foi alterado;
- nenhum servico foi reiniciado;
- nenhuma sincronizacao foi executada;
- nenhum servidor da Fabri foi acessado ou modificado;
- nenhum token, senha, hash de usuario, chave secreta ou conteudo sensivel foi registrado.

## Ponto de Parada Oficial

ParmaCloudSync v1.0 e Portal da Fabri Tecidos estao funcionais e aprovados ao fim de 03/08/2026.

A proxima etapa deve iniciar pela avaliacao da instalacao definitiva do Servico do Windows ParmaCloudSync no servidor real da Fabri, seguida do planejamento do instalador profissional.
