import hashlib
import hmac
from datetime import datetime, timezone

from flask import current_app

from sqlalchemy import and_, select

from .database import get_engine
from .errors import ApiError
from .tables import agent_credential, mobile_session, tenant


def utc_now_iso():
    return datetime.now(timezone.utc).isoformat(timespec="seconds")


def token_digest(token):
    return hmac.new(
        current_app.config["TOKEN_HASH_SECRET"].encode("utf-8"),
        token.encode("utf-8"),
        hashlib.sha256,
    ).hexdigest()


def _bearer_token(request):
    value = request.headers.get("Authorization", "")
    if not value.startswith("Bearer ") or not value[7:].strip():
        raise ApiError(401, "NAO_AUTORIZADO", "Token Bearer obrigatorio")
    return value[7:].strip()


def authenticate_agent(request):
    digest = token_digest(_bearer_token(request))
    statement = (
        select(
            agent_credential.c.id,
            agent_credential.c.tenant_id,
            agent_credential.c.agent_guid,
            tenant.c.external_id.label("tenant_external_id"),
        )
        .select_from(agent_credential.join(tenant, tenant.c.id == agent_credential.c.tenant_id))
        .where(
            and_(
                agent_credential.c.token_digest == digest,
                agent_credential.c.active.is_(True),
            )
        )
    )
    with get_engine().connect() as connection:
        row = connection.execute(statement).mappings().first()
    if row is None:
        raise ApiError(401, "AGENTE_NAO_AUTORIZADO", "Credencial do agente invalida")
    return dict(row)


def authenticate_mobile(request):
    digest = token_digest(_bearer_token(request))
    statement = (
        select(
            mobile_session.c.id,
            mobile_session.c.tenant_id,
            mobile_session.c.driver_guid,
            mobile_session.c.expires_at,
            tenant.c.external_id.label("tenant_external_id"),
        )
        .select_from(mobile_session.join(tenant, tenant.c.id == mobile_session.c.tenant_id))
        .where(
            and_(
                mobile_session.c.token_digest == digest,
                mobile_session.c.revoked_at.is_(None),
            )
        )
    )
    with get_engine().connect() as connection:
        row = connection.execute(statement).mappings().first()
    if row is None:
        raise ApiError(401, "SESSAO_INVALIDA", "Sessao invalida")
    expires_at = row["expires_at"]
    if isinstance(expires_at, str):
        expires_at = datetime.fromisoformat(expires_at)
    if expires_at.tzinfo is None:
        expires_at = expires_at.replace(tzinfo=timezone.utc)
    if expires_at <= datetime.now(timezone.utc):
        raise ApiError(401, "SESSAO_EXPIRADA", "Sessao expirada")
    return dict(row)
