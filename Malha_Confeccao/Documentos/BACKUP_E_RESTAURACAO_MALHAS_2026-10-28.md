# Backup e restauração — App Malhas

Data: 28/10/2026

## Objetivo e limite

`BACKUP_MALHAS.bat` produz um RAR restaurável do código-fonte e de seus
artefatos de reconstrução. Ele não é backup dos bancos operacionais e não
contém credenciais reais, tokens, chaves de assinatura ou configurações de
produção.

O arquivo é salvo na raiz do projeto como
`Malha_Confeccao_aaaa-MM-dd_HH-mm-ss.rar`, acompanhado do SHA-256 em
`*.rar.sha256` e de um log `BACKUP_MALHAS_*.log`.

## Conteúdo incluído

O procedimento copia o projeto de forma ampla e conserva fontes Flutter,
Android/Gradle, API Nuvem, Agente, API local legada, testes, migrations
Alembic, scripts, documentos, `pubspec.yaml`, `pubspec.lock`,
`requirements.txt` e arquivos `*.env.example`.

## Exclusões intencionais

- `build`, `.dart_tool`, `.flutter-plugins-dependencies`, `.gradle`, `.idea`,
  `.tools`, `android/local.properties` e artefatos temporários;
- ambientes virtuais Python (`venv`, `.venv`, `.venv-wsl-tests`), caches
  Python, `__pycache__` e `.pytest_cache`;
- arquivos RAR/ZIP/7z anteriores, seus checksums e logs;
- `.env` reais, bancos/estado técnico, certificados, chaves e keystores;
- pontos de reanálise e links simbólicos. Em especial, os links Linux do
  ambiente WSL não são seguidos.

As exclusões são reconstruíveis ou confidenciais. O BAT nunca remove esses
itens do projeto de origem.

## Como executar

1. Feche apenas ferramentas que estejam gravando arquivos do projeto, quando
   possível. Não é necessário interromper API, Agente, Firebird ou Delphi.
2. Execute `BACKUP_MALHAS.bat` a partir do Explorer ou de um `cmd`.
3. Aguarde a mensagem `SUCESSO`.
4. Guarde juntos o RAR, o arquivo `.sha256` e o log.
5. Antes de enviar ao MEGA, confira o SHA-256 com `certutil -hashfile`.

O BAT usa WinRAR instalado localmente e cria a área de preparação abaixo de
`%TEMP%`, fora do projeto. `robocopy` não segue junções; qualquer ponto de
reanálise remanescente é removido somente da cópia temporária.

## Restauração do código e compilação

1. Extraia o RAR para uma nova pasta de trabalho, nunca por cima do projeto em
   uso.
2. Instale Flutter 3.38.5/Dart 3.10.4, Android SDK, JDK compatível (o projeto
   usa alvo Java 17), Python e, para os testes correspondentes, WSL/Ubuntu e
   PostgreSQL.
3. Configure `android/local.properties` com os caminhos do novo computador.
4. Execute `flutter pub get`; depois, os testes e `flutter build apk --debug`.
5. Recrie os ambientes Python com `python -m venv` e instale cada
   `requirements.txt`. No WSL, recrie `.venv-wsl-tests` com Python 3.12.
6. Aplique migrations somente no banco de destino explicitamente autorizado;
   nunca em produção apenas para validar a restauração.

## Recuperação operacional completa

Exige, separadamente e com criptografia, as credenciais e configurações
protegidas do Agente/API, acesso administrativo à DigitalOcean, a chave de
assinatura Android e backups testados do PostgreSQL `malhas_nuvem` e do
Firebird Tekno Prime. Esses elementos não estão no RAR comum.

Para PostgreSQL, o procedimento futuro é `pg_dump` no servidor, cópia externa
e teste de `pg_restore` em banco descartável. Para Firebird, usar `gbak` em
procedimento autorizado; não copiar simplesmente um `.FDB` operacional em uso.

## Validação

O BAT confirma a cópia dos arquivos essenciais, executa o teste de integridade
do RAR pelo `Rar.exe` e grava SHA-256. Em 28/10/2026, a extração isolada
confirmou a estrutura e os arquivos essenciais, sem `.env`, ambientes virtuais,
`build`, `.dart_tool` ou cache Gradle. A compilação restaurada não foi
executada: o Flutter/Dart local está com comportamento de bloqueio sem saída,
já registrado no projeto; a validação atual é somente para extração.

### Resultado da execução validada

- Arquivo: `Malha_Confeccao_2026-10-28_10-23-34.rar`.
- Integridade WinRAR: aprovada por `Rar.exe t`.
- SHA-256:
  `8632075A4ADE3C960FD283CEA2C68055793848BC646F0A6AA9923FACAD2D7670`.
- Extração isolada: aprovada; `pubspec.yaml`, `pubspec.lock`, scripts,
  requirements, Gradle Wrapper e as duas migrations foram encontrados.
- Exclusões verificadas: nenhum `.env`, ambiente virtual, `build`,
  `.dart_tool`, cache Gradle ou RAR/checksum aninhado.
- Classificação: **validado apenas para extração**; a compilação da cópia
  restaurada continua pendente de um ambiente Flutter/Dart sem bloqueio.
