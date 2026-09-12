# App Motorista

Flutter V1 do motorista Parmasoft. O primeiro bloco contém login, sessão segura,
refresh, Minhas Viagens, detalhe da viagem, paradas, pedidos e visualização das
ocorrências esperadas. Scanner e registro de leitura C/R ainda não fazem parte
deste bloco.

## Ambiente local

A API é configurada centralmente por `dart-define`. No emulador Android, o valor
padrão aponta para a máquina hospedeira:

```text
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:5055
```

Para celular físico, use o IP da máquina que executa a API:

```text
flutter run --dart-define=API_BASE_URL=http://SEU_IP_LOCAL:5055
```

Ambiente e timeout também podem ser definidos:

```text
--dart-define=API_ENV=desenvolvimento
--dart-define=API_TIMEOUT_SECONDS=20
```

Tokens são armazenados com `flutter_secure_storage`; senha e tokens não são
gravados em log. A interface segue o padrão mobile-first do projeto: letras
grandes, cartões amplos, alto contraste e somente informação operacional.
