from datetime import datetime, timedelta
from uuid import uuid4

from flask import current_app
from werkzeug.security import check_password_hash, generate_password_hash

from app.api_errors import ApiError
from app.database import read_connection, transaction
from .security import new_token, token_hash


_DUMMY_HASH = generate_password_hash("credencial-inexistente")


def _token_response(access_token, refresh_token, access_expires, motorista):
    return {
        "token_type": "Bearer",
        "access_token": access_token,
        "access_expires_at": access_expires.isoformat(timespec="seconds"),
        "expires_in": current_app.config["ACCESS_TOKEN_MINUTES"] * 60,
        "refresh_token": refresh_token,
        "motorista": motorista,
    }


def create_session(login, password, dispositivo=None, ip=None):
    with read_connection() as connection:
        cursor = connection.cursor()
        cursor.execute(
            """
            SELECT MOTAPP_ID, MOTAPP_GUID, MOTAPP_NOME, MOTAPP_SENHA_HASH, MOTAPP_ATIVO
            FROM TB_MOTORISTA_APP
            WHERE UPPER(TRIM(MOTAPP_LOGIN)) = UPPER(TRIM(?))
            """,
            (login,),
        )
        driver = cursor.fetchone()

    stored_hash = driver[3] if driver else _DUMMY_HASH
    password_ok = check_password_hash(stored_hash, password)
    if not driver or driver[4] != "S" or not password_ok:
        raise ApiError("Usuario ou senha invalidos.", 401)

    now = datetime.now()
    access_expires = now + timedelta(minutes=current_app.config["ACCESS_TOKEN_MINUTES"])
    refresh_expires = now + timedelta(days=current_app.config["REFRESH_TOKEN_DAYS"])
    access_token = new_token()
    refresh_token = new_token()

    with transaction() as connection:
        cursor = connection.cursor()
        cursor.execute("SELECT GEN_ID(GEN_MOTORISTA_APP_SESSAO_ID, 1) FROM RDB$DATABASE")
        session_id = cursor.fetchone()[0]
        cursor.execute(
            """
            INSERT INTO TB_MOTORISTA_APP_SESSAO (
              MOTAPPS_ID, MOTAPPS_GUID, MOTAPPS_MOTORISTA,
              MOTAPPS_ACCESS_HASH, MOTAPPS_REFRESH_HASH, MOTAPPS_STATUS,
              MOTAPPS_DH_CRIACAO, MOTAPPS_DH_ACCESS_EXPIRA,
              MOTAPPS_DH_REFRESH_EXPIRA, MOTAPPS_DISPOSITIVO, MOTAPPS_IP_CRIACAO)
            VALUES (?, ?, ?, ?, ?, 'A', ?, ?, ?, ?, ?)
            """,
            (
                session_id,
                str(uuid4()).upper(),
                driver[0],
                token_hash(access_token),
                token_hash(refresh_token),
                now,
                access_expires,
                refresh_expires,
                dispositivo,
                ip,
            ),
        )
        cursor.execute(
            "UPDATE TB_MOTORISTA_APP SET MOTAPP_DH_ULTIMO_LOGIN = ? WHERE MOTAPP_ID = ?",
            (now, driver[0]),
        )

    motorista = {"guid": driver[1], "nome": driver[2]}
    return _token_response(access_token, refresh_token, access_expires, motorista)


def renew_session(refresh_token):
    digest = token_hash(refresh_token)
    now = datetime.now()

    with transaction() as connection:
        cursor = connection.cursor()
        cursor.execute(
            """
            SELECT MOTAPPS_ID, MOTAPPS_MOTORISTA
            FROM TB_MOTORISTA_APP_SESSAO
            WHERE MOTAPPS_REFRESH_HASH = ?
              AND MOTAPPS_STATUS = 'A'
              AND MOTAPPS_DH_REFRESH_EXPIRA > CURRENT_TIMESTAMP
            WITH LOCK
            """,
            (digest,),
        )
        session = cursor.fetchone()
        if not session:
            raise ApiError("Token de renovacao invalido ou expirado.", 401)

        cursor.execute(
            """
            SELECT MOTAPP_ID, MOTAPP_GUID, MOTAPP_NOME
            FROM TB_MOTORISTA_APP
            WHERE MOTAPP_ID = ? AND MOTAPP_ATIVO = 'S'
            """,
            (session[1],),
        )
        driver = cursor.fetchone()
        if not driver:
            raise ApiError("Token de renovacao invalido ou expirado.", 401)

        access_token = new_token()
        new_refresh_token = new_token()
        access_expires = now + timedelta(minutes=current_app.config["ACCESS_TOKEN_MINUTES"])
        refresh_expires = now + timedelta(days=current_app.config["REFRESH_TOKEN_DAYS"])
        cursor.execute(
            """
            UPDATE TB_MOTORISTA_APP_SESSAO SET
              MOTAPPS_ACCESS_HASH = ?,
              MOTAPPS_REFRESH_HASH = ?,
              MOTAPPS_DH_ACCESS_EXPIRA = ?,
              MOTAPPS_DH_REFRESH_EXPIRA = ?,
              MOTAPPS_DH_RENOVACAO = ?
            WHERE MOTAPPS_ID = ? AND MOTAPPS_STATUS = 'A'
            """,
            (
                token_hash(access_token),
                token_hash(new_refresh_token),
                access_expires,
                refresh_expires,
                now,
                session[0],
            ),
        )
        if cursor.rowcount != 1:
            raise ApiError("Sessao alterada por outra requisicao.", 409)

    motorista = {"guid": driver[1], "nome": driver[2]}
    return _token_response(access_token, new_refresh_token, access_expires, motorista)
