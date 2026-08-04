# Ponto de Parada - 02/08/2026

Projeto: ParmaCloudSync v1.0
Cliente piloto: Fabri Tecidos
Status: ParmaCloudSync v1.0 e Portal da Fabri Tecidos homologados tecnicamente; aguardar implantacao real no servidor da Fabri

## Resumo Geral

Em 02/08/2026 foram concluidas as etapas operacionais de custo, publicacao do Portal, login sem diferenciar maiusculas e minusculas, logout, URL simplificada e Nginx como reverse proxy.

O fluxo homologado ao fim do dia e:

```text
ERP Firebird
    -> ParmaCloudSync
    -> API Flask/Gunicorn
    -> Firebird na DigitalOcean
    -> Portal via Nginx
```

Ficaram validados:

- custo;
- preco;
- estoque;
- login;
- logout;
- URL simplificada;
- sincronizacao manual controlada;
- Portal pela porta 80 via Nginx;
- acesso antigo pela porta 5000 preservado.

Nao executar mais alteracoes operacionais hoje.

## 1. Campo de Custo na Nuvem

Foi criada de forma controlada a coluna:

```sql
TB_PORTAL_PRODUTO.PPR_CUSTO NUMERIC(15,4)
```

Validacao de metadados:

```text
FIELD_PRECISION=15
FIELD_SCALE=-4
```

Antes da sincronizacao:

```text
TOTAL_PRODUTOS=2958
CUSTOS_NULL=2958
CUSTOS_ZERO=0
CUSTOS_POSITIVOS=0
```

Nenhum outro objeto do banco foi alterado.

Backup fisico utilizado:

```text
/var/lib/firebird/backups/cotacao_antes_custo_20260801_172600.fdb
```

## 2. Publicacao da API e do Portal

Foram publicados:

```text
/var/www/cotacao/api_nuvem.py
/var/www/cotacao/static/portal/index.html
/var/www/cotacao/static/portal/portal.js
/var/www/cotacao/static/portal/portal.css
```

Backup da publicacao de custo e login:

```text
/var/www/cotacao/backups/publicacao_custo_login_20260802_123050
```

Validacoes:

```text
PY_COMPILE_API_NUVEM=OK
IMPORT_API_NUVEM=OK
OBJETO_FLASK_EXISTE=SIM
GET_CONNECTION_EXISTE=SIM
```

## 3. Login do Portal

O usuario passou a ser localizado sem diferenciacao entre maiusculas e minusculas:

```sql
AND UPPER(U.PUS_USUARIO) = UPPER(?)
```

Foram validados:

```text
fabricio
Fabricio
FABRICIO
```

As tres formas localizaram o mesmo usuario.

A senha permanece sensivel a maiusculas e minusculas, utilizando:

```python
check_password_hash(senha_hash, senha)
```

O nome exibido continua vindo do banco conforme cadastrado:

```text
Fabricio
```

## 4. Atualizacao do Runtime Windows Para Custo

Na maquina Windows 10 de homologacao foram atualizados somente:

```text
C:\Parmasoft_Cloud\modelos.py
```

e a lista de campos do `SELECT` do `config.ini`, acrescentando:

```sql
P.PRD_PRECO_CUSTO AS CUSTO
```

Foram preservados:

- host e porta do Firebird;
- caminho do banco;
- usuario e senha;
- token;
- endpoint;
- identificador;
- intervalo;
- tamanho dos lotes;
- timeouts;
- demais configuracoes.

Hash do novo `modelos.py`:

```text
356C5513FE162893983B6853D4F9E28D04BED38C41AC6616FFFB7A45CAF61166
```

Os demais arquivos do runtime Windows foram comparados com a entrega homologada e permaneceram identicos.

## 5. Sincronizacao Manual Controlada

Foi executada uma sincronizacao unica:

```bat
C:\Python311-32\python.exe main.py --uma-vez
```

Resultado:

```text
Produtos encontrados: 2958
Lotes enviados: 30
Produtos enviados: 2958 de 2958
Duracao aproximada: 16,39 segundos
Sincronizacao concluida com sucesso
```

O Servico Windows permaneceu parado durante o teste.

## 6. Validacao do Custo na Nuvem

Depois da sincronizacao:

```text
TOTAL_PRODUTOS=2958
CUSTOS_NULL=0
CUSTOS_ZERO=11
CUSTOS_POSITIVOS=2947
MENOR_CUSTO_POSITIVO=0.0100
MAIOR_CUSTO=109782.4100
PRODUTO_1096_CUSTO=14.9000
```

O produto 1096 foi conferido tambem no banco de origem:

```text
PRD_PRECO_CUSTO=14.9000
```

O Portal exibiu corretamente o mesmo custo.

## 7. Ajuste Visual de Custo e Preco

Foi alterado somente:

```text
static/portal/portal.js
```

A apresentacao passou a ser:

```text
Custo: 14,90
Preco: 59,98
```

Foram retirados os textos `R$`.

Regras finais:

- custo com duas casas decimais;
- preco com duas casas decimais;
- custo zero como `0,00`;
- custo nulo como `-`;
- banco e API continuam preservando quatro casas decimais no custo.

Backup local:

```text
E:\Jorginho\Parma_Cloud\backups\portal_visual_moeda_20260802_103657\portal.js
```

Backup remoto:

```text
/var/www/cotacao/backups/portal_visual_moeda_20260802_133754/static/portal/portal.js
```

## 8. Botao Sair

Foi criada a rota:

```text
POST /portal/<identificador>/logout
```

O logout executa:

```python
session.clear()
```

Foi adicionado botao `Sair` ao lado do usuario conectado.

Ao sair:

- a sessao Flask e encerrada;
- o nome salvo no `sessionStorage` e removido;
- a pesquisa e os resultados sao limpos;
- a tela volta para o login;
- novo acesso exige autenticacao.

A sessao permanente continua com duracao de oito horas quando o usuario nao utiliza o botao `Sair`.

## 9. URL Simplificada

Foi criada a rota:

```text
GET /portal/<identificador>
```

O identificador do cliente pode ser obtido:

1. pelo parametro antigo `?cliente=...`;
2. pelo caminho amigavel `/portal/<identificador>`.

URL final para a Fabri Tecidos:

```text
http://165.227.77.226/portal/fabritecidos
```

O endereco antigo continua funcionando:

```text
http://165.227.77.226:5000/static/portal/index.html?cliente=fabritecidos
```

## 10. Nginx Como Reverse Proxy

Foi alterado:

```text
/etc/nginx/sites-available/default
```

Configuracao aplicada:

```nginx
location / {
    proxy_pass http://127.0.0.1:5000;
    proxy_http_version 1.1;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
}
```

Validacao:

```text
nginx -t: successful
```

Recarregamentos utilizados:

```text
API: systemctl kill -s HUP --kill-who=main parmasoft-portal.service
Nginx: systemctl reload nginx
```

Backup:

```text
/var/www/cotacao/backups/portal_logout_url_nginx_20260802_140301
```

## 11. Estado Final da DigitalOcean

API:

```text
ActiveState=active
SubState=running
Result=success
NRestarts=0
```

Gunicorn:

- um master;
- dois workers;
- porta 5000 ouvindo;
- `/ping` retornando HTTP 200.

Nginx:

```text
active
```

Portal acessivel pela porta 80 atraves do endereco simplificado.

## 12. Teste do Fim de Semana

A maquina Windows de homologacao pode permanecer desligada.

O Fabricio podera testar normalmente:

- abertura do link;
- login;
- pesquisa;
- custo;
- preco;
- estoque;
- botao `Sair`;
- acesso pelo celular ou computador.

Os dados exibidos serao a fotografia dos 2.958 produtos enviados pela copia do banco usada na homologacao.

Sem a maquina Windows ligada, nao ocorrerao novas sincronizacoes, mas o Portal e os dados ja enviados continuarao disponiveis na nuvem.

## 13. Pendencias Conhecidas

Nao foram implementados ainda:

- HTTPS;
- dominio amigavel;
- fechamento da exposicao direta da porta 5000;
- usuario Linux exclusivo para o Gunicorn;
- correcao do timeout de encerramento do Gunicorn.

O encerramento do Gunicorn atualmente ultrapassa `TimeoutStopSec=30` e o systemd aplica `SIGKILL`. A API volta e funciona normalmente, mas o comportamento ocorreu mais de uma vez e deve ser estudado separadamente.

Nao misturar essas melhorias com a implantacao real de segunda-feira.

## Proxima Etapa - Implantacao Real na Fabri

Na proxima sessao, realizar a instalacao definitiva no servidor real da Fabri Tecidos:

1. identificar o servidor correto;
2. fazer backup;
3. instalar ou validar Python 3.11.9 de 32 bits para todos os usuarios;
4. utilizar o runtime dedicado:

```text
C:\Python311-32
```

5. instalar dependencias;
6. executar `pywin32_postinstall`;
7. copiar o runtime aprovado;
8. criar ou configurar o `config.ini` com o banco real;
9. testar conexao;
10. executar sincronizacao manual controlada;
11. conferir os produtos e custos na nuvem;
12. instalar o Servico Windows;
13. confirmar que `ImagePath` utiliza:

```text
C:\Python311-32\pythonservice.exe
```

14. testar start, stop e restart;
15. validar o log;
16. confirmar inicializacao automatica.

## Proxima Evolucao - Instalador Profissional

Depois da implantacao real, iniciar o planejamento e desenvolvimento de um instalador profissional do ParmaCloudSync para os proximos clientes.

O instalador deve ser tratado como uma nova etapa e primeiro deve ter seu desenho tecnico aprovado.

Requisitos iniciais a considerar:

- instalacao limpa e orientada;
- identificacao de instalacao nova ou atualizacao;
- backup automatico de instalacao anterior;
- instalacao em pasta padrao;
- deteccao ou instalacao do Python 3.11.9 de 32 bits;
- uso do runtime global dedicado, nunca do `venv` para hospedar o servico;
- instalacao das dependencias;
- execucao do `pywin32_postinstall`;
- criacao das pastas de logs e backups;
- configuracao assistida do Firebird;
- configuracao do identificador e endpoint do cliente;
- token sem ser incluido em pacote publico;
- teste de conexao antes de instalar/iniciar o servico;
- sincronizacao manual inicial;
- instalacao do Servico Windows com inicio automatico;
- confirmacao do `ImagePath`;
- tela ou relatorio final de instalacao;
- log detalhado da instalacao;
- atualizacao idempotente;
- opcao de reparo;
- desinstalacao segura;
- preservacao do `config.ini` em atualizacoes;
- rollback em caso de falha;
- nenhuma inicializacao automatica antes da configuracao e validacao.

Avaliar uma tecnologia apropriada para o instalador, possivelmente Inno Setup, mas nao comecar a codificacao antes de apresentar:

1. arquitetura proposta;
2. fluxo de instalacao;
3. arquivos incluidos;
4. tratamento de credenciais;
5. estrategia de atualizacao;
6. estrategia de rollback;
7. instalacao e remocao do Servico Windows;
8. riscos tecnicos;
9. plano de testes.

## Ponto de Parada Oficial

ParmaCloudSync v1.0 e Portal da Fabri Tecidos ficaram homologados tecnicamente.

Custo, preco, estoque, login, logout, URL simplificada e sincronizacao foram validados.

Nao executar mais alteracoes operacionais hoje.

Aguardar a proxima sessao para:

1. revisar o retorno do Fabricio;
2. realizar a implantacao no servidor real;
3. iniciar o desenho do instalador profissional.
