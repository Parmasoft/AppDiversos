/*
  Firebird 2.5 migration - NOT APPLIED BY THIS REPOSITORY.

  SP_REG_ENTREGA_MANIFESTO is intentionally not altered.  This migration is
  the installation envelope for SP_APL_ENTREGA_NUVEM and must be completed
  from the reviewed, byte-for-byte business-rule copy before a DBA applies it.
  It is intentionally not executable yet: applying a partial delivery rule
  would be worse than leaving return disabled.

  Required public contract:
    P_MANIFESTO_GUID VARCHAR(36), P_PARADA INTEGER, P_PEDIDO INTEGER,
    P_OPERACAO_GUID VARCHAR(36), P_PAYLOAD_VERSAO INTEGER,
    P_PAYLOAD_HASH CHAR(64), P_CODIGO VARCHAR(60),
    P_DH_DISPOSITIVO TIMESTAMP, P_FUSO_MINUTOS SMALLINT,
    P_LATITUDE NUMERIC(18,8), P_LONGITUDE NUMERIC(18,8),
    P_PRECISAO NUMERIC(15,2), P_DISPOSITIVO VARCHAR(100)

  Required outputs: RESULTADO, CODIGO_RESPOSTA, MENSAGEM, OPERACAO,
  OCORRENCIA_GUID, TIPO, PEDIDO, PENDENTES_PEDIDO, PENDENTES_PARADA, REPLAY.

  The final reviewed body must duplicate the established write/audit branch of
  SP_REG_ENTREGA_MANIFESTO, deriving the driver from CARGM_MOTORISTA_APP and
  omitting only its interactive-session validation.  No direct Agent DML is
  permitted.  Run isql only after source review, technical-user grants, a
  disposable Firebird test database and approval.
*/
