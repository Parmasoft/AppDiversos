from app.database import transaction


_REGISTER_DELIVERY_SQL = """
    SELECT RESULTADO, CODIGO_RESPOSTA, MENSAGEM, OPERACAO,
           OCORRENCIA_GUID, TIPO, PEDIDO, PENDENTES_PEDIDO,
           PENDENTES_PARADA, REPLAY
    FROM SP_REG_ENTREGA_MANIFESTO(?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
"""


def register_delivery_operation(
    manifesto_guid,
    motorista_id,
    sessao_id,
    parada,
    pedido,
    operacao_guid,
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
    parameters = (
        manifesto_guid,
        motorista_id,
        sessao_id,
        parada,
        pedido,
        operacao_guid,
        payload_versao,
        payload_hash,
        codigo,
        data_hora_aparelho,
        fuso_minutos,
        latitude,
        longitude,
        precisao,
        dispositivo,
    )

    with transaction() as connection:
        cursor = connection.cursor()
        cursor.execute(_REGISTER_DELIVERY_SQL, parameters)
        row = cursor.fetchone()

    if row is None:
        raise RuntimeError("SP_REG_ENTREGA_MANIFESTO nao retornou resultado.")

    return {
        "resultado": row[0],
        "codigo_resposta": row[1],
        "mensagem": row[2],
        "operacao": row[3],
        "ocorrencia_guid": row[4],
        "tipo": row[5],
        "pedido": row[6],
        "pendentes_pedido": row[7],
        "pendentes_parada": row[8],
        "replay": bool(row[9]),
    }
