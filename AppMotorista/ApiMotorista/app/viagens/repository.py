from app.database import transaction


_REGISTER_DELIVERY_SQL = """
    SELECT RESULTADO, CODIGO_RESPOSTA, MENSAGEM, OPERACAO_GUID,
           OCORRENCIA_GUID, TIPO, PEDIDO, PENDENTES_PEDIDO,
           PENDENTES_PARADA, REPLAY
    FROM SP_APL_ENTREGA_NUVEM(?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
"""

_MANIFEST_COMPANY_SQL = """
    SELECT CARGM_EMPRESA
    FROM TB_CARGA_MANIFESTO
    WHERE CARGM_GUID = ? AND CARGM_MOTORISTA_APP = ?
"""


def register_delivery_operation(
    manifesto_guid,
    motorista_id,
    sessao_id,
    parada,
    pedido,
    operacao_guid,
    occurrence_guid,
    payload_versao,
    payload_hash,
    codigo,
    data_hora_aparelho,
    fuso_minutos,
    latitude,
    longitude,
    precisao,
    dispositivo,
):
    with transaction() as connection:
        cursor = connection.cursor()
        cursor.execute(_MANIFEST_COMPANY_SQL, (manifesto_guid, motorista_id))
        company_row = cursor.fetchone()
        if company_row is None:
            return {
                "resultado": "RECUSADA",
                "codigo_resposta": "MANIFESTO_NAO_AUTORIZADO",
                "mensagem": "Manifesto nao autorizado para o motorista autenticado.",
                "operacao": None,
                "ocorrencia_guid": None,
                "tipo": None,
                "pedido": pedido,
                "pendentes_pedido": None,
                "pendentes_parada": None,
                "replay": False,
            }
        parameters = (
            company_row[0], manifesto_guid, parada, pedido, occurrence_guid,
            operacao_guid, payload_versao, payload_hash, codigo,
            data_hora_aparelho, fuso_minutos, latitude, longitude, precisao,
            dispositivo,
        )
        cursor.execute(_REGISTER_DELIVERY_SQL, parameters)
        row = cursor.fetchone()

    if row is None:
        raise RuntimeError("SP_APL_ENTREGA_NUVEM nao retornou resultado.")

    return {
        "resultado": row[0],
        "codigo_resposta": row[1],
        "mensagem": row[2],
        "operacao": None,
        "operacao_guid": row[3],
        "ocorrencia_guid": row[4],
        "tipo": row[5],
        "pedido": row[6],
        "pendentes_pedido": row[7],
        "pendentes_parada": row[8],
        "replay": bool(row[9]),
    }
