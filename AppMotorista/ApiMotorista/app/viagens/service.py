from collections import OrderedDict
from decimal import Decimal

from app.api_errors import ApiError
from app.database import read_connection


def _iso(value):
    return value.isoformat(timespec="seconds") if value else None


def _decimal(value, scale=None):
    if value is None:
        return None
    if not isinstance(value, Decimal):
        value = Decimal(str(value))
    if scale is not None:
        value = value.quantize(Decimal(1).scaleb(-scale))
    return format(value, "f")


def list_viagens(motorista_id):
    with read_connection() as connection:
        cursor = connection.cursor()
        cursor.execute(
            """
            SELECT M.CARGM_GUID, M.CARGM_EMPRESA, M.CARGM_ID, M.CARGM_CARGA,
                   M.CARGM_VERSAO, M.CARGM_DH_LIBERACAO,
                   C.CARG_DESCRICAO, C.CARG_DT_SAIDA, C.CARG_HORA_SAIDA,
                   (SELECT COUNT(*) FROM TB_CARGA_PARADA P
                    WHERE P.CARGPA_EMPRESA = M.CARGM_EMPRESA
                      AND P.CARGPA_CARGA = M.CARGM_CARGA),
                   (SELECT COUNT(*) FROM TB_CARGA_MANIFESTO_OCORRENCIA O
                    WHERE O.CARGMO_EMPRESA = M.CARGM_EMPRESA
                      AND O.CARGMO_MANIFESTO = M.CARGM_ID)
            FROM TB_CARGA_MANIFESTO M
            JOIN TB_MOTORISTA_APP_EMPRESA ME
              ON ME.MOTAPPE_EMPRESA = M.CARGM_EMPRESA
             AND ME.MOTAPPE_MOTORISTA = M.CARGM_MOTORISTA_APP
             AND ME.MOTAPPE_ATIVO = 'S'
            JOIN TB_CARGA C
              ON C.CARG_EMPRESA = M.CARGM_EMPRESA AND C.CARG_ID = M.CARGM_CARGA
            WHERE M.CARGM_STATUS = 'L'
              AND M.CARGM_MOTORISTA_APP = ?
            ORDER BY M.CARGM_DH_LIBERACAO DESC, M.CARGM_ID DESC
            """,
            (motorista_id,),
        )
        rows = cursor.fetchall()

    return [
        {
            "manifesto_guid": row[0],
            "empresa": row[1],
            "manifesto": row[2],
            "carga": row[3],
            "versao": row[4],
            "liberado_em": _iso(row[5]),
            "descricao": row[6],
            "saida_data": row[7].isoformat() if row[7] else None,
            "saida_hora": row[8].isoformat() if row[8] else None,
            "quantidade_paradas": row[9],
            "quantidade_ocorrencias": row[10],
        }
        for row in rows
    ]


def get_viagem(motorista_id, manifesto_guid):
    with read_connection() as connection:
        cursor = connection.cursor()
        cursor.execute(
            """
            SELECT M.CARGM_EMPRESA, M.CARGM_ID, M.CARGM_GUID, M.CARGM_CARGA,
                   M.CARGM_CONFERENCIA, M.CARGM_VERSAO, M.CARGM_STATUS,
                   M.CARGM_DH_GERACAO, M.CARGM_DH_LIBERACAO,
                   C.CARG_DESCRICAO, C.CARG_DT_SAIDA, C.CARG_HORA_SAIDA,
                   C.CARG_PLACA, C.CARG_ORIGEM_LATITUDE, C.CARG_ORIGEM_LONGITUDE,
                   E.EMP_FANTASIA, E.EMP_RAZAO_SOCIAL, E.EMP_CNPJ,
                   D.MOTAPP_GUID, D.MOTAPP_NOME
            FROM TB_CARGA_MANIFESTO M
            JOIN TB_MOTORISTA_APP D ON D.MOTAPP_ID = M.CARGM_MOTORISTA_APP
            JOIN TB_MOTORISTA_APP_EMPRESA ME
              ON ME.MOTAPPE_EMPRESA = M.CARGM_EMPRESA
             AND ME.MOTAPPE_MOTORISTA = M.CARGM_MOTORISTA_APP
             AND ME.MOTAPPE_ATIVO = 'S'
            JOIN TB_CARGA C
              ON C.CARG_EMPRESA = M.CARGM_EMPRESA AND C.CARG_ID = M.CARGM_CARGA
            JOIN TB_EMPRESA E ON E.EMP_ID = M.CARGM_EMPRESA
            WHERE M.CARGM_GUID = ?
              AND M.CARGM_STATUS = 'L'
              AND M.CARGM_MOTORISTA_APP = ?
            """,
            (manifesto_guid, motorista_id),
        )
        header = cursor.fetchone()
        if not header:
            raise ApiError("Viagem não encontrada.", 404)

        empresa, manifesto, _, carga = header[0], header[1], header[2], header[3]
        cursor.execute(
            """
            SELECT P.CARGPA_ID, P.CARGPA_GUID, P.CARGPA_CLIENTE,
                   COALESCE(NULLIF(TRIM(CL.CLI_FANTASIA_APELIDO), ''), CL.CLI_RSOCIAL_NOME),
                   CL.CLI_RSOCIAL_NOME,
                   P.CARGPA_ORDEM_PLANEJADA, P.CARGPA_ORDEM_SUGERIDA,
                   P.CARGPA_ORDEM_REALIZADA, P.CARGPA_STATUS,
                   P.CARGPA_ENDERECO, P.CARGPA_NUMERO, P.CARGPA_COMPLEMENTO,
                   P.CARGPA_BAIRRO, P.CARGPA_CIDADE_NOME, P.CARGPA_UF,
                   P.CARGPA_CEP, P.CARGPA_LATITUDE, P.CARGPA_LONGITUDE
            FROM TB_CARGA_PARADA P
            JOIN TB_CLIENTE CL
              ON CL.CLI_EMPRESA = P.CARGPA_EMPRESA AND CL.CLI_ID = P.CARGPA_CLIENTE
            WHERE P.CARGPA_EMPRESA = ? AND P.CARGPA_CARGA = ?
            ORDER BY COALESCE(P.CARGPA_ORDEM_REALIZADA, P.CARGPA_ORDEM_SUGERIDA,
                              P.CARGPA_ORDEM_PLANEJADA, P.CARGPA_ID), P.CARGPA_ID
            """,
            (empresa, carga),
        )
        stop_rows = cursor.fetchall()

        stops = OrderedDict()
        for row in stop_rows:
            stops[row[0]] = {
                "parada": row[0],
                "guid": row[1],
                "ordem": {
                    "planejada": row[5],
                    "sugerida": row[6],
                    "realizada": row[7],
                },
                "status": row[8],
                "cliente": {
                    "id": row[2],
                    "nome": row[3],
                    "razao_social": row[4],
                },
                "endereco": {
                    "logradouro": row[9],
                    "numero": row[10],
                    "complemento": row[11],
                    "bairro": row[12],
                    "cidade": row[13],
                    "uf": row[14],
                    "cep": row[15],
                    "latitude": _decimal(row[16], 8),
                    "longitude": _decimal(row[17], 8),
                },
                "pedidos": [],
                "ocorrencias": [],
            }

        cursor.execute(
            """
            SELECT CARGPAP_PARADA, CARGPAP_PEDIDO, CARGPAP_CARGI_SEQUENCIA,
                   CARGPAP_ORDEM_ENTREGA_ORIG, CARGPAP_STATUS
            FROM TB_CARGA_PARADA_PEDIDO
            WHERE CARGPAP_EMPRESA = ? AND CARGPAP_CARGA = ?
            ORDER BY CARGPAP_PARADA, CARGPAP_PEDIDO, CARGPAP_CARGI_SEQUENCIA
            """,
            (empresa, carga),
        )
        for row in cursor.fetchall():
            if row[0] in stops:
                stops[row[0]]["pedidos"].append(
                    {
                        "pedido": row[1],
                        "carga_item_sequencia": row[2],
                        "ordem_entrega_origem": row[3],
                        "status": row[4],
                    }
                )

        cursor.execute(
            """
            SELECT CARGMO_ID, CARGMO_GUID, CARGMO_LEITURA_ORIGEM,
                   CARGMO_PARADA, CARGMO_CLIENTE, CARGMO_PEDIDO,
                   CARGMO_ITEM_PEDIDO, CARGMO_PRODUTO, CARGMO_TIPO,
                   CARGMO_CODIGO, CARGMO_ROLO_ID, CARGMO_QUANTIDADE,
                   CARGMO_STATUS, CARGMO_VERSAO_REGISTRO
            FROM TB_CARGA_MANIFESTO_OCORRENCIA
            WHERE CARGMO_EMPRESA = ? AND CARGMO_MANIFESTO = ?
            ORDER BY CARGMO_PARADA, CARGMO_PEDIDO, CARGMO_LEITURA_ORIGEM, CARGMO_ID
            """,
            (empresa, manifesto),
        )
        occurrence_count = 0
        for row in cursor.fetchall():
            occurrence_count += 1
            occurrence = {
                "ocorrencia": row[0],
                "guid": row[1],
                "leitura_origem": row[2],
                "cliente": row[4],
                "pedido": row[5],
                "item_pedido": row[6],
                "produto": row[7],
                "tipo": row[8],
                "codigo": row[9],
                "rolo_id": row[10],
                "quantidade": _decimal(row[11], 4),
                "status": row[12],
                "versao_registro": row[13],
            }
            if row[3] in stops:
                stops[row[3]]["ocorrencias"].append(occurrence)

    stop_list = list(stops.values())
    return {
        "manifesto": {
            "id": header[1],
            "guid": header[2],
            "versao": header[5],
            "status": header[6],
            "conferencia": header[4],
            "gerado_em": _iso(header[7]),
            "liberado_em": _iso(header[8]),
        },
        "carga": {
            "id": header[3],
            "descricao": header[9],
            "saida_data": header[10].isoformat() if header[10] else None,
            "saida_hora": header[11].isoformat() if header[11] else None,
            "placa": header[12],
        },
        "motorista": {"guid": header[18], "nome": header[19]},
        "origem": {
            "empresa": header[0],
            "nome_fantasia": header[15],
            "razao_social": header[16],
            "cnpj": header[17],
            "latitude": _decimal(header[13], 8),
            "longitude": _decimal(header[14], 8),
        },
        "rota": [
            {
                "parada": stop["parada"],
                "ordem": stop["ordem"],
                "cliente": stop["cliente"]["id"],
            }
            for stop in stop_list
        ],
        "paradas": stop_list,
        "quantidade_ocorrencias": occurrence_count,
    }

