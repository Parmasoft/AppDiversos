import os
import sys

sys.path.insert(0, r"E:\Jorginho\AppMotorista\ApiMotorista")

for line in open(r"E:\Jorginho\AppMotorista\ApiMotorista\.env", encoding="utf-8"):
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
    SELECT T.TRANSP_EMPRESA, T.TRANSP_ID, T.TRANSP_RSOCIAL_NOME,
           COUNT(ME.MOTAPPE_MOTORISTA)
      FROM TB_TRANSPORTADOR T
      LEFT JOIN TB_MOTORISTA_APP_EMPRESA ME
        ON ME.MOTAPPE_EMPRESA = T.TRANSP_EMPRESA
       AND ME.MOTAPPE_TRANSPORTADOR = T.TRANSP_ID
     WHERE T.TRANSP_EMPRESA = 10
       AND T.TRANSP_ID = 22
     GROUP BY T.TRANSP_EMPRESA, T.TRANSP_ID, T.TRANSP_RSOCIAL_NOME
    """
    )
    print("TRANSPORTADOR_22", cursor.fetchall())
    cursor.execute(
    """
    SELECT M.MOTAPP_ID, M.MOTAPP_LOGIN, M.MOTAPP_ATIVO,
           ME.MOTAPPE_EMPRESA, ME.MOTAPPE_TRANSPORTADOR, ME.MOTAPPE_ATIVO
      FROM TB_MOTORISTA_APP M
      LEFT JOIN TB_MOTORISTA_APP_EMPRESA ME
        ON ME.MOTAPPE_MOTORISTA = M.MOTAPP_ID
     WHERE M.MOTAPP_ID = 1
    """
    )
    print("MOTAPP_1", cursor.fetchall())
    connection.rollback()
    connection.close()
