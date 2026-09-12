import os
import sys

sys.path.insert(0, r"E:\Jorginho\AppMotorista\ApiMotorista")

with open(r"E:\Jorginho\AppMotorista\ApiMotorista\.env", encoding="utf-8") as env_file:
    for line in env_file:
        line = line.strip()
        if line and not line.startswith("#") and "=" in line:
            key, value = line.split("=", 1)
            os.environ.setdefault(key.strip(), value.strip())

from app import create_app
from app.database import connect


def fetch_one(cursor, sql, params=()):
    cursor.execute(sql, params)
    return cursor.fetchone()


def fetch_all(cursor, sql, params=()):
    cursor.execute(sql, params)
    return cursor.fetchall()


app = create_app()
with app.app_context():
    connection = connect()
    cursor = connection.cursor()
    try:
        driver_before = fetch_one(
            cursor,
            """
            SELECT MOTAPP_ID, MOTAPP_NOME, MOTAPP_LOGIN, MOTAPP_ATIVO
              FROM TB_MOTORISTA_APP
             WHERE MOTAPP_ID = 1
            WITH LOCK
            """,
        )
        if driver_before is None:
            raise RuntimeError("MOTAPP_ID 1 nao encontrado.")
        if driver_before[0] != 1 or driver_before[2].strip().upper() != "A":
            raise RuntimeError("MOTAPP_ID 1 nao corresponde ao login temporario A.")

        manifesto_before = fetch_one(
            cursor,
            "SELECT * FROM TB_CARGA_MANIFESTO WHERE CARGM_EMPRESA = 10 AND CARGM_ID = 5",
        )
        carga_before = fetch_one(
            cursor,
            "SELECT * FROM TB_CARGA WHERE CARG_EMPRESA = 10 AND CARG_ID = 504",
        )
        if manifesto_before is None or carga_before is None:
            raise RuntimeError("Manifesto 5 ou Carga 504 nao encontrados; operacao cancelada.")

        cursor.execute(
            """
            UPDATE TB_MOTORISTA_APP
               SET MOTAPP_ATIVO = 'N',
                   MOTAPP_DH_ALTERACAO = CURRENT_TIMESTAMP
             WHERE MOTAPP_ID = 1
               AND MOTAPP_ATIVO = 'S'
            """
        )
        motorista_alterado = cursor.rowcount

        cursor.execute(
            """
            UPDATE TB_MOTORISTA_APP_EMPRESA
               SET MOTAPPE_ATIVO = 'N',
                   MOTAPPE_DH_ALTERACAO = CURRENT_TIMESTAMP
             WHERE MOTAPPE_MOTORISTA = 1
               AND MOTAPPE_ATIVO = 'S'
            """
        )
        vinculos_alterados = cursor.rowcount

        cursor.execute(
            """
            UPDATE TB_MOTORISTA_APP_SESSAO
               SET MOTAPPS_STATUS = 'R',
                   MOTAPPS_DH_REVOGACAO = CURRENT_TIMESTAMP
             WHERE MOTAPPS_MOTORISTA = 1
               AND MOTAPPS_STATUS = 'A'
            """
        )
        sessoes_revogadas = cursor.rowcount

        active_driver = fetch_one(
            cursor,
            "SELECT COUNT(*) FROM TB_MOTORISTA_APP WHERE MOTAPP_ID = 1 AND MOTAPP_ATIVO = 'S'",
        )[0]
        active_links = fetch_one(
            cursor,
            "SELECT COUNT(*) FROM TB_MOTORISTA_APP_EMPRESA WHERE MOTAPPE_MOTORISTA = 1 AND MOTAPPE_ATIVO = 'S'",
        )[0]
        active_sessions = fetch_one(
            cursor,
            "SELECT COUNT(*) FROM TB_MOTORISTA_APP_SESSAO WHERE MOTAPPS_MOTORISTA = 1 AND MOTAPPS_STATUS = 'A'",
        )[0]
        if active_driver or active_links or active_sessions:
            raise RuntimeError("Censuras de desativacao nao foram integralmente aplicadas.")

        connection.commit()
    except Exception:
        connection.rollback()
        raise
    finally:
        connection.close()

    verify_connection = connect()
    verify_cursor = verify_connection.cursor()
    try:
        driver_after = fetch_one(
            verify_cursor,
            "SELECT MOTAPP_ID, MOTAPP_NOME, MOTAPP_LOGIN, MOTAPP_ATIVO FROM TB_MOTORISTA_APP WHERE MOTAPP_ID = 1",
        )
        links_after = fetch_all(
            verify_cursor,
            """
            SELECT MOTAPPE_EMPRESA, MOTAPPE_MOTORISTA, MOTAPPE_TRANSPORTADOR, MOTAPPE_ATIVO
              FROM TB_MOTORISTA_APP_EMPRESA
             WHERE MOTAPPE_MOTORISTA = 1
             ORDER BY MOTAPPE_EMPRESA
            """,
        )
        valid_sessions_after = fetch_one(
            verify_cursor,
            """
            SELECT COUNT(*)
              FROM TB_MOTORISTA_APP_SESSAO
             WHERE MOTAPPS_MOTORISTA = 1
               AND MOTAPPS_STATUS = 'A'
               AND (MOTAPPS_DH_ACCESS_EXPIRA > CURRENT_TIMESTAMP
                    OR MOTAPPS_DH_REFRESH_EXPIRA > CURRENT_TIMESTAMP)
            """,
        )[0]
        session_status_after = fetch_all(
            verify_cursor,
            """
            SELECT MOTAPPS_STATUS, COUNT(*)
              FROM TB_MOTORISTA_APP_SESSAO
             WHERE MOTAPPS_MOTORISTA = 1
             GROUP BY MOTAPPS_STATUS
             ORDER BY MOTAPPS_STATUS
            """,
        )
        manifesto_after = fetch_one(
            verify_cursor,
            "SELECT * FROM TB_CARGA_MANIFESTO WHERE CARGM_EMPRESA = 10 AND CARGM_ID = 5",
        )
        carga_after = fetch_one(
            verify_cursor,
            "SELECT * FROM TB_CARGA WHERE CARG_EMPRESA = 10 AND CARG_ID = 504",
        )
    finally:
        verify_connection.rollback()
        verify_connection.close()

    client = app.test_client()
    login_response = client.post(
        "/api/v1/motorista/sessoes",
        json={"login": "A", "senha": "A", "dispositivo": "validacao-retirada"},
    )

    final_connection = connect()
    final_cursor = final_connection.cursor()
    try:
        final_active_sessions = fetch_one(
            final_cursor,
            "SELECT COUNT(*) FROM TB_MOTORISTA_APP_SESSAO WHERE MOTAPPS_MOTORISTA = 1 AND MOTAPPS_STATUS = 'A'",
        )[0]
    finally:
        final_connection.rollback()
        final_connection.close()

    print("MOTORISTA_ALTERADO", motorista_alterado)
    print("VINCULOS_DESATIVADOS", vinculos_alterados)
    print("SESSOES_REVOGADAS", sessoes_revogadas)
    print("MOTORISTA_FINAL", driver_after)
    print("VINCULOS_FINAIS", links_after)
    print("SESSOES_POR_STATUS", session_status_after)
    print("SESSOES_VALIDAS", valid_sessions_after)
    print("LOGIN_A_HTTP_STATUS", login_response.status_code)
    print("SESSOES_ATIVAS_APOS_TESTE_LOGIN", final_active_sessions)
    print("MANIFESTO_5_PRESERVADO", manifesto_before == manifesto_after)
    print("CARGA_504_PRESERVADA", carga_before == carga_after)
