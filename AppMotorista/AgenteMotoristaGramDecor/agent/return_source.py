"""The only Firebird write path for cloud-confirmed delivery operations."""
from datetime import datetime

import fdb


class FirebirdDeliveryReturnSource:
    def __init__(self, config, connect=fdb.connect):
        self.config = config
        self._connect = connect

    def apply(self, payload):
        data_hora_aparelho = payload.get("data_hora_aparelho")
        if data_hora_aparelho:
            data_hora_aparelho = datetime.fromisoformat(data_hora_aparelho)
        connection = self._connect(
            host=self.config.firebird_host, port=self.config.firebird_port,
            database=self.config.firebird_database, user=self.config.firebird_user,
            password=self.config.firebird_password, charset=self.config.firebird_charset,
        )
        try:
            cursor = connection.cursor()
            cursor.execute(
                """SELECT RESULTADO, CODIGO_RESPOSTA, MENSAGEM, OPERACAO_GUID,
                          OCORRENCIA_GUID, TIPO, PEDIDO, PENDENTES_PEDIDO,
                          PENDENTES_PARADA, REPLAY
                     FROM SP_APL_ENTREGA_NUVEM(?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)""",
                (payload["empresa"], payload["manifest_guid"], payload["stop_id"], payload["order_id"],
                 payload["expected_occurrence_guid"], payload["operation_guid"],
                 payload["contrato_versao"], payload["payload_hash"],
                 payload["codigo"], data_hora_aparelho, payload.get("fuso_minutos"),
                 payload.get("latitude"), payload.get("longitude"), payload.get("precisao"),
                 payload.get("dispositivo")),
            )
            row = cursor.fetchone()
            if row is None:
                raise RuntimeError("SP_APL_ENTREGA_NUVEM nao retornou resultado")
            connection.commit()
        except Exception:
            connection.rollback()
            raise
        finally:
            connection.close()
        return dict(zip(("resultado", "codigo_resposta", "mensagem", "operacao", "ocorrencia_guid", "tipo", "pedido", "pendentes_pedido", "pendentes_parada", "replay"), row))
