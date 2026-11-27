import hmac
import secrets
from datetime import datetime, timedelta, timezone

from app.database import read_connection

_sessions = {}
_attempts = {}
_ttl = timedelta(minutes=15)

def _now(): return datetime.now(timezone.utc)

def login(login_value, password, remote_address=""):
    key = (remote_address or "local", (login_value or "").strip().upper())
    record = _attempts.get(key, {"count": 0, "until": _now()})
    if record["until"] > _now() and record["count"] >= 5:
        raise ValueError("Muitas tentativas. Aguarde alguns minutos.")
    with read_connection() as connection:
        cursor = connection.cursor()
        try:
            cursor.execute("""
                SELECT VDR_EMPRESA, VDR_ID, VDR_STATUS, VDR_SENHA, VDR_RSOCIAL_NOME
                FROM TB_VENDEDOR
                WHERE UPPER(TRIM(VDR_LOGIN)) = ?
            """, ((login_value or "").strip().upper(),))
            rows = cursor.fetchall()
        finally: cursor.close()
    active = [row for row in rows if (row[2] or "").strip().upper() == "A"]
    if len(active) > 1:
        raise ValueError("Login associado a mais de uma empresa. Selecione a empresa no cadastro administrativo.")
    if not active:
        if rows: raise PermissionError("Vendedor inativo.")
        _fail(key); raise PermissionError("Usuario ou senha invalidos.")
    seller = active[0]
    if not hmac.compare_digest(str(seller[3] or ""), str(password or "")):
        _fail(key); raise PermissionError("Usuario ou senha invalidos.")
    _attempts.pop(key, None)
    token = secrets.token_urlsafe(48); expires = _now() + _ttl
    _sessions[token] = {"empresa": int(seller[0]), "vendedor": int(seller[1]), "nome": seller[4] or "", "expires": expires}
    return {"access_token": token, "token_type": "Bearer", "expires_in": int(_ttl.total_seconds()), "vendedor": {"empresa": int(seller[0]), "id": int(seller[1]), "nome": seller[4] or ""}}

def _fail(key):
    record=_attempts.get(key,{"count":0,"until":_now()}); record["count"]+=1
    if record["count"]>=5: record["until"]=_now()+timedelta(minutes=5)
    _attempts[key]=record

def session(token):
    value=_sessions.get(token or "")
    if not value or value["expires"] <= _now():
        _sessions.pop(token or "", None); return None
    return value

def logout(token): _sessions.pop(token or "", None)
