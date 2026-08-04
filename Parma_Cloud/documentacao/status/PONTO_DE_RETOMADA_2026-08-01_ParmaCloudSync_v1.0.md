# Ponto de Retomada - 01/08/2026

Projeto: ParmaCloudSync v1.0
Cliente piloto: Fabri Tecidos
Status: entrega do Servico do Windows reconstruida; procedimento de instalacao corrigido no fim de 01/08/2026

## Contexto Lido

Foram lidos:

- `README.md`
- `documentacao/status/PONTO_DE_PARADA_2026-07-31_ParmaCloudSync_v1.0.md`

O ponto de parada anterior indicava que a proxima etapa seria a implantacao
controlada do ParmaCloudSync como Servico do Windows no servidor da Fabri
Tecidos.

## Validacao Local

Foi executada validacao de sintaxe:

```bat
python -m compileall -q .
```

Resultado:

- aprovado;
- Python local identificado: 3.11.8.

## Ajuste Feito na Retomada

A documentacao anterior citava a existencia dos artefatos:

- `entrega_servico_windows_fabri`
- `INSTRUCOES_INSTALACAO_SERVICO.txt`

Na pasta atual, esses artefatos nao existiam no inicio da retomada.

Foi recriada a pasta:

- `entrega_servico_windows_fabri`

Tambem foi criado o arquivo:

- `INSTRUCOES_INSTALACAO_SERVICO.txt`

Tambem foi gerado o pacote compactado:

- `ParmaCloudSync_v1.0_servico_windows_fabri_2026-08-01.zip`

O arquivo de instrucoes foi colocado:

- na raiz do projeto;
- dentro da pasta `entrega_servico_windows_fabri`.

## Conteudo Atual da Entrega

A entrega foi montada com os arquivos necessarios para execucao do servico:

- `app.py`
- `api.py`
- `banco.py`
- `config.py`
- `logger.py`
- `main.py`
- `modelos.py`
- `requirements.txt`
- `runner.py`
- `servico_windows.py`
- `sincronizador.py`
- `README.md`
- `INSTRUCOES_INSTALACAO_SERVICO.txt`

Decisao importante:

- `config.ini` nao foi incluido na entrega;
- logs nao foram incluidos;
- `__pycache__` nao foi incluido;
- ambiente virtual nao foi incluido;
- tokens e dados sensiveis devem permanecer somente no servidor validado.

O pacote `.zip` contem os mesmos arquivos da pasta de entrega e tambem nao
inclui `config.ini`.

## Observacao Sobre a Entrega Anterior

O ponto de parada de 31/07/2026 listava uma entrega contendo apenas parte dos
arquivos Python. Na pratica, `app.py` depende tambem de:

- `api.py`
- `banco.py`
- `config.py`
- `modelos.py`
- `runner.py`

Por isso, a entrega reconstruida inclui todos os arquivos de runtime
necessarios.

## Atualizacao Posterior em 01/08/2026

Apos a primeira homologacao real do Servico do Windows, foi confirmado que o
servico nao deve ser instalado pelo Python do `venv`.

O procedimento anterior:

```bat
venv\Scripts\python.exe servico_windows.py --startup auto install
```

foi superado pelo diagnostico do erro 1053.

O Servico do Windows deve usar o Python global dedicado:

```text
C:\Python311-32\python.exe
```

O `pywin32_postinstall` deve ser executado fora do `venv`, em Prompt elevado:

```bat
C:\Python311-32\python.exe C:\Python311-32\Scripts\pywin32_postinstall.py -install
```

## Proximo Passo

Executar a implantacao controlada no servidor da Fabri Tecidos seguindo:

```text
INSTRUCOES_INSTALACAO_SERVICO.txt
```

Sequencia principal:

1. Fazer backup da pasta atual no servidor.
2. Copiar os arquivos da entrega para a pasta final.
3. Preservar o `config.ini` validado.
4. Instalar dependencias no Python global dedicado.
5. Executar `C:\Python311-32\python.exe -m compileall -q .`.
6. Executar `C:\Python311-32\python.exe main.py --testar-conexao`.
7. Executar `C:\Python311-32\python.exe main.py --uma-vez`.
8. Instalar o servico:

```bat
C:\Python311-32\python.exe servico_windows.py --startup auto install
```

9. Iniciar o servico:

```bat
C:\Python311-32\python.exe servico_windows.py start
```

10. Confirmar que `sc qc ParmaCloudSync` aponta para `C:\Python311-32\pythonservice.exe`.
11. Conferir `services.msc` e `logs\ParmaCloudSync.log`.
