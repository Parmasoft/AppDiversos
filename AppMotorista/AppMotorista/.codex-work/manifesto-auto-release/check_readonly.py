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
        SELECT C.CARG_EMPRESA, C.CARG_ID, C.CARG_TRANSPORTADOR
          FROM TB_CARGA C
         WHERE C.CARG_EMPRESA = 10
           AND C.CARG_ID = 526
        """
    )
    print("CARGA_526", cursor.fetchall())

    cursor.execute(
        """
        SELECT E.MOTAPPE_MOTORISTA, E.MOTAPPE_ATIVO, M.MOTAPP_ATIVO
          FROM TB_MOTORISTA_APP_EMPRESA E
          JOIN TB_MOTORISTA_APP M
            ON M.MOTAPP_ID = E.MOTAPPE_MOTORISTA
         WHERE E.MOTAPPE_EMPRESA = 10
           AND E.MOTAPPE_TRANSPORTADOR = 22
           AND E.MOTAPPE_ATIVO = 'S'
        """
    )
    print("VINCULOS_ATIVOS_TRANSPORTADOR_22", cursor.fetchall())

    cursor.execute(
        """
        SELECT M.CARGM_ID, M.CARGM_CARGA, M.CARGM_CONFERENCIA,
               M.CARGM_STATUS, M.CARGM_MOTORISTA_APP
          FROM TB_CARGA_MANIFESTO M
         WHERE M.CARGM_EMPRESA = 10
           AND M.CARGM_CARGA = 526
         ORDER BY M.CARGM_ID
        """
    )
    print("MANIFESTOS_CARGA_526", cursor.fetchall())

    cursor.execute(
        """
        SELECT TRIM(P.RDB$PARAMETER_NAME), P.RDB$PARAMETER_TYPE,
               P.RDB$PARAMETER_NUMBER
          FROM RDB$PROCEDURE_PARAMETERS P
         WHERE P.RDB$PROCEDURE_NAME = 'SP_LIBERA_CARGA_MANIFESTO'
         ORDER BY P.RDB$PARAMETER_TYPE, P.RDB$PARAMETER_NUMBER
        """
    )
    print("PARAMETROS_SP_LIBERA", cursor.fetchall())

    connection.rollback()
    connection.close()
