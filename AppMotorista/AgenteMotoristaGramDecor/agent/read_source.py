from collections import OrderedDict
from decimal import Decimal

import fdb


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


def snapshot_read_only_tpb():
    tpb = fdb.TPB()
    tpb.access_mode = fdb.isc_tpb_read
    tpb.isolation_level = fdb.isc_tpb_concurrency
    tpb.lock_resolution = fdb.isc_tpb_wait
    return tpb.render()


class FirebirdSnapshotSource:
    """Read-only projection of the same released-manifest contract used by the local API."""

    def __init__(self, config, connect=fdb.connect):
        self.config = config
        self._connect = connect

    def _connection(self):
        return self._connect(
            host=self.config.firebird_host,
            port=self.config.firebird_port,
            database=self.config.firebird_database,
            user=self.config.firebird_user,
            password=self.config.firebird_password,
            charset=self.config.firebird_charset,
        )

    def list_released_manifest_guids(self, allowed_scopes):
        if not allowed_scopes:
            return []
        connection = self._connection()
        try:
            connection.begin(tpb=fdb.ISOLATION_LEVEL_READ_COMMITED_RO)
            cursor = connection.cursor()
            scope_conditions = []
            parameters = []
            for company, load in allowed_scopes:
                if load is None:
                    scope_conditions.append("(M.CARGM_EMPRESA = ?)")
                    parameters.append(company)
                else:
                    scope_conditions.append("(M.CARGM_EMPRESA = ? AND M.CARGM_CARGA = ?)")
                    parameters.extend((company, load))
            scope_filter = " OR ".join(scope_conditions)
            cursor.execute(
                f"""
                SELECT DISTINCT M.CARGM_GUID
                  FROM TB_CARGA_MANIFESTO M
                  JOIN TB_MOTORISTA_APP D
                    ON D.MOTAPP_ID = M.CARGM_MOTORISTA_APP
                  JOIN TB_MOTORISTA_APP_EMPRESA ME
                    ON ME.MOTAPPE_EMPRESA = M.CARGM_EMPRESA
                   AND ME.MOTAPPE_MOTORISTA = M.CARGM_MOTORISTA_APP
                   AND ME.MOTAPPE_ATIVO = 'S'
                 WHERE M.CARGM_STATUS = 'L'
                   AND M.CARGM_DH_LIBERACAO IS NOT NULL
                   AND D.MOTAPP_ATIVO = 'S'
                   AND ({scope_filter})
                 ORDER BY M.CARGM_EMPRESA, M.CARGM_ID
                """,
                tuple(parameters),
            )
            return [row[0] for row in cursor.fetchall()]
        finally:
            try:
                connection.rollback()
            finally:
                connection.close()

    def read_manifest(self, manifest_guid):
        connection = self._connection()
        try:
            connection.begin(tpb=snapshot_read_only_tpb())
            return self._read_detail(connection.cursor(), manifest_guid)
        finally:
            try:
                connection.rollback()
            finally:
                connection.close()

    def read_released_manifests(self, allowed_scopes):
        return [
            self.read_manifest(guid)
            for guid in self.list_released_manifest_guids(allowed_scopes)
        ]

    def list_driver_identities(self, allowed_scopes):
        """Full company-scoped credential projection; never returns a raw password."""
        companies = sorted({company for company, _load in allowed_scopes})
        if not companies:
            return []
        connection = self._connection()
        try:
            connection.begin(tpb=fdb.ISOLATION_LEVEL_READ_COMMITED_RO)
            cursor = connection.cursor()
            placeholders = ", ".join("?" for _ in companies)
            cursor.execute(
                f"""
                SELECT ME.MOTAPPE_EMPRESA, D.MOTAPP_ID, D.MOTAPP_GUID,
                       D.MOTAPP_NOME, D.MOTAPP_LOGIN, D.MOTAPP_SENHA_HASH,
                       D.MOTAPP_ATIVO, ME.MOTAPPE_ATIVO, ME.MOTAPPE_TRANSPORTADOR
                 FROM TB_MOTORISTA_APP_EMPRESA ME
                  JOIN TB_MOTORISTA_APP D ON D.MOTAPP_ID = ME.MOTAPPE_MOTORISTA
                 WHERE ME.MOTAPPE_EMPRESA IN ({placeholders})
                   AND D.MOTAPP_LOGIN IS NOT NULL
                   AND D.MOTAPP_SENHA_HASH IS NOT NULL
                 ORDER BY ME.MOTAPPE_EMPRESA, D.MOTAPP_ID
                """,
                tuple(companies),
            )
            return [
                {
                    "empresa": row[0], "motorista_id": row[1], "motorista_guid": row[2],
                    "nome": row[3], "login": row[4].strip().upper(),
                    "password_verifier": row[5], "motorista_ativo": row[6] == "S",
                    "vinculo_ativo": row[7] == "S", "transportador": row[8],
                }
                for row in cursor.fetchall()
            ]
        finally:
            try:
                connection.rollback()
            finally:
                connection.close()

    @staticmethod
    def _read_detail(cursor, manifest_guid):
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
               AND M.CARGM_DH_LIBERACAO IS NOT NULL
               AND D.MOTAPP_ATIVO = 'S'
            """,
            (manifest_guid,),
        )
        header = cursor.fetchone()
        if not header:
            raise RuntimeError(f"Manifesto liberado nao encontrado: {manifest_guid}")
        company_id, manifest_id, _, load_id = header[0], header[1], header[2], header[3]

        cursor.execute(
            """
            SELECT P.CARGPA_ID, P.CARGPA_GUID, P.CARGPA_CLIENTE,
                   COALESCE(NULLIF(TRIM(CL.CLI_FANTASIA_APELIDO), ''), CL.CLI_RSOCIAL_NOME),
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
            (company_id, load_id),
        )
        stops = OrderedDict()
        for row in cursor.fetchall():
            stops[row[0]] = {
                "parada": row[0],
                "guid": row[1],
                "ordem": {"planejada": row[4], "sugerida": row[5], "realizada": row[6]},
                "status": row[7],
                "cliente": {
                    "id": row[2], "nome": row[3],
                    "email_notificacao": None, "aceita_email": False,
                },
                "endereco": {
                    "logradouro": row[8], "numero": row[9], "complemento": row[10],
                    "bairro": row[11], "cidade": row[12], "uf": row[13], "cep": row[14],
                    "latitude": _decimal(row[15], 8), "longitude": _decimal(row[16], 8),
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
            (company_id, load_id),
        )
        for row in cursor.fetchall():
            if row[0] in stops:
                stops[row[0]]["pedidos"].append(
                    {
                        "pedido": row[1], "carga_item_sequencia": row[2],
                        "ordem_entrega_origem": row[3], "status": row[4],
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
            (company_id, manifest_id),
        )
        occurrence_count = 0
        for row in cursor.fetchall():
            occurrence_count += 1
            if row[3] in stops:
                stops[row[3]]["ocorrencias"].append(
                    {
                        "ocorrencia": row[0], "guid": row[1], "leitura_origem": row[2],
                        "cliente": row[4], "pedido": row[5], "item_pedido": row[6],
                        "produto": row[7], "tipo": row[8], "codigo": row[9],
                        "rolo_id": row[10], "quantidade": _decimal(row[11], 4),
                        "status": row[12], "versao_registro": row[13],
                    }
                )

        stop_list = list(stops.values())
        return {
            "manifesto": {
                "id": header[1], "guid": header[2], "versao": header[5],
                "status": header[6], "conferencia": header[4],
                "gerado_em": _iso(header[7]), "liberado_em": _iso(header[8]),
            },
            "carga": {
                "id": header[3], "descricao": header[9],
                "saida_data": header[10].isoformat() if header[10] else None,
                "saida_hora": header[11].isoformat() if header[11] else None,
                "placa": header[12],
            },
            "motorista": {"guid": header[18], "nome": header[19]},
            "origem": {
                "empresa": header[0], "nome_fantasia": header[15],
                "razao_social": header[16], "cnpj": header[17],
                "latitude": _decimal(header[13], 8), "longitude": _decimal(header[14], 8),
            },
            "rota": [
                {"parada": stop["parada"], "ordem": stop["ordem"], "cliente": stop["cliente"]["id"]}
                for stop in stop_list
            ],
            "paradas": stop_list,
            "quantidade_ocorrencias": occurrence_count,
        }
