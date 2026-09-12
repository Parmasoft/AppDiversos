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


app = create_app()
with app.app_context():
    connection = connect()
    cursor = connection.cursor()

    cursor.execute(
        """
        SELECT MOTAPP_ID, MOTAPP_NOME, MOTAPP_LOGIN, MOTAPP_ATIVO,
               MOTAPP_DH_ALTERACAO, MOTAPP_USUARIO_ALTERACAO
          FROM TB_MOTORISTA_APP
         WHERE MOTAPP_ID = 1
        """
    )
    print("MOTORISTA", cursor.fetchall())

    cursor.execute(
        """
        SELECT MOTAPPE_EMPRESA, MOTAPPE_MOTORISTA, MOTAPPE_TRANSPORTADOR,
               MOTAPPE_ATIVO
          FROM TB_MOTORISTA_APP_EMPRESA
         WHERE MOTAPPE_MOTORISTA = 1
         ORDER BY MOTAPPE_EMPRESA
        """
    )
    print("VINCULOS", cursor.fetchall())

    cursor.execute(
        """
        SELECT MOTAPPS_STATUS,
               COUNT(*),
               SUM(CASE WHEN MOTAPPS_DH_ACCESS_EXPIRA > CURRENT_TIMESTAMP THEN 1 ELSE 0 END),
               SUM(CASE WHEN MOTAPPS_DH_REFRESH_EXPIRA > CURRENT_TIMESTAMP THEN 1 ELSE 0 END)
          FROM TB_MOTORISTA_APP_SESSAO
         WHERE MOTAPPS_MOTORISTA = 1
         GROUP BY MOTAPPS_STATUS
         ORDER BY MOTAPPS_STATUS
        """
    )
    print("SESSOES_POR_STATUS_TOTAL_ACCESS_VALIDO_REFRESH_VALIDO", cursor.fetchall())

    cursor.execute(
        """
        SELECT
          SUM(CASE WHEN MOTAPPS_STATUS = 'A'
                    AND MOTAPPS_DH_ACCESS_EXPIRA > CURRENT_TIMESTAMP THEN 1 ELSE 0 END),
          SUM(CASE WHEN MOTAPPS_STATUS = 'A'
                    AND MOTAPPS_DH_REFRESH_EXPIRA > CURRENT_TIMESTAMP THEN 1 ELSE 0 END),
          SUM(CASE WHEN MOTAPPS_STATUS = 'R'
                    AND MOTAPPS_DH_REVOGACAO IS NULL THEN 1 ELSE 0 END)
          FROM TB_MOTORISTA_APP_SESSAO
         WHERE MOTAPPS_MOTORISTA = 1
        """
    )
    print("ACCESS_VALIDOS_REFRESH_VALIDOS_REVOGADAS_SEM_DATA", cursor.fetchall())

    cursor.execute(
        """
        SELECT CARGM_EMPRESA, CARGM_ID, CARGM_CARGA, CARGM_STATUS,
               CARGM_MOTORISTA_APP, CARGM_DH_LIBERACAO
          FROM TB_CARGA_MANIFESTO
         WHERE CARGM_EMPRESA = 10
           AND CARGM_ID = 5
        """
    )
    print("MANIFESTO_5", cursor.fetchall())

    cursor.execute(
        """
        SELECT CARG_EMPRESA, CARG_ID, CARG_STATUS, CARG_TRANSPORTADOR
          FROM TB_CARGA
         WHERE CARG_EMPRESA = 10
           AND CARG_ID = 504
        """
    )
    print("CARGA_504", cursor.fetchall())

    connection.rollback()
    connection.close()
