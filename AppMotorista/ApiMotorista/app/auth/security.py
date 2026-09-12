import hashlib
import secrets
from functools import wraps

from flask import g, request

from app.api_errors import ApiError
from app.database import read_connection


def new_token():
    return secrets.token_urlsafe(48)


def token_hash(token):
    return hashlib.sha256(token.encode("utf-8")).hexdigest().upper()


def authenticated_motorista(view):
    @wraps(view)
    def wrapped(*args, **kwargs):
        authorization = request.headers.get("Authorization", "")
        scheme, separator, raw_token = authorization.partition(" ")
        if separator != " " or scheme.lower() != "bearer" or not raw_token.strip():
            raise ApiError("Sessão não autenticada.", 401)

        digest = token_hash(raw_token.strip())
        with read_connection() as connection:
            cursor = connection.cursor()
            cursor.execute(
                """
                SELECT S.MOTAPPS_ID, D.MOTAPP_ID, D.MOTAPP_GUID, D.MOTAPP_NOME,
                       S.MOTAPPS_DISPOSITIVO
                FROM TB_MOTORISTA_APP_SESSAO S
                JOIN TB_MOTORISTA_APP D ON D.MOTAPP_ID = S.MOTAPPS_MOTORISTA
                WHERE S.MOTAPPS_ACCESS_HASH = ?
                  AND S.MOTAPPS_STATUS = 'A'
                  AND S.MOTAPPS_DH_ACCESS_EXPIRA > CURRENT_TIMESTAMP
                  AND D.MOTAPP_ATIVO = 'S'
                """,
                (digest,),
            )
            row = cursor.fetchone()

        if not row:
            raise ApiError("Sessão inválida ou expirada.", 401)

        g.sessao_id = row[0]
        g.motorista_id = row[1]
        g.motorista_guid = row[2]
        g.motorista_nome = row[3]
        g.dispositivo = row[4]
        return view(*args, **kwargs)

    return wrapped
