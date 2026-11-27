import secrets
import base64
import json
from datetime import datetime, timezone

from sqlalchemy import select, update

from .database import get_engine
from .security import token_digest
from .sql import dialect_insert
from .tables import agent_credential, agent_credential_company_access, mobile_session, tenant


def _as_datetime(value):
    if value is None or isinstance(value, datetime):
        return value
    parsed = datetime.fromisoformat(value)
    return parsed if parsed.tzinfo else parsed.replace(tzinfo=timezone.utc)


def provision_tenant(external_id, name, tracking_activated_at=None):
    with get_engine().begin() as connection:
        statement = dialect_insert(connection, tenant).values(
            external_id=external_id,
            name=name,
            tracking_activated_at=_as_datetime(tracking_activated_at),
        )
        statement = statement.on_conflict_do_update(
            index_elements=[tenant.c.external_id],
            set_={"name": statement.excluded.name},
        )
        connection.execute(statement)
        return connection.execute(
            select(tenant.c.id).where(tenant.c.external_id == external_id)
        ).scalar_one()


def provision_agent(tenant_id, agent_guid, raw_token):
    with get_engine().begin() as connection:
        result = connection.execute(
            agent_credential.insert().values(
                tenant_id=tenant_id,
                agent_guid=agent_guid,
                token_digest=token_digest(raw_token),
                active=True,
                created_at=datetime.now(timezone.utc),
            )
        )
        return result.inserted_primary_key[0]


def provision_agent_company_access(agent_credential_id, company_id, active=True):
    """Test/provisioning helper; production authorization is provisioned by SQL."""
    with get_engine().begin() as connection:
        statement = dialect_insert(connection, agent_credential_company_access).values(
            agent_credential_id=agent_credential_id,
            company_id=company_id,
            active=active,
        )
        statement = statement.on_conflict_do_update(
            index_elements=["agent_credential_id", "company_id"],
            set_={"active": statement.excluded.active},
        )
        connection.execute(statement)


def provision_mobile_session(
    tenant_id, driver_guid, raw_token, expires_at, refresh_token=None
):
    with get_engine().begin() as connection:
        result = connection.execute(
            mobile_session.insert().values(
                tenant_id=tenant_id,
                driver_guid=driver_guid,
                token_digest=token_digest(raw_token),
                refresh_token_digest=token_digest(refresh_token) if refresh_token else None,
                expires_at=_as_datetime(expires_at),
                created_at=datetime.now(timezone.utc),
            )
        )
        return result.inserted_primary_key[0]


def provision_temporary_mobile_session(tenant_id, driver_guid, expires_at):
    """Cria token efemero; o chamador deve transferi-lo sem persistencia."""
    raw_token = secrets.token_urlsafe(32)
    refresh_token = secrets.token_urlsafe(32)
    session_id = provision_mobile_session(
        tenant_id, driver_guid, raw_token, expires_at, refresh_token
    )
    return session_id, raw_token, refresh_token, _as_datetime(expires_at)


def mobile_bootstrap_qr_payload(raw_token, refresh_token, expires_at, driver_guid, driver_name):
    """Representacao efemera para QR; nunca deve ser gravada ou registrada."""
    value = {
        "token": raw_token,
        "refresh_token": refresh_token,
        "expires_at": _as_datetime(expires_at).isoformat(),
        "motorista": {"guid": driver_guid, "nome": driver_name},
    }
    encoded = base64.urlsafe_b64encode(
        json.dumps(value, separators=(",", ":")).encode("utf-8")
    ).decode("ascii").rstrip("=")
    return f"motorista-bootstrap:v1:{encoded}"


def revoke_mobile_session(session_id, revoked_at=None):
    with get_engine().begin() as connection:
        result = connection.execute(
            update(mobile_session)
            .where(mobile_session.c.id == session_id)
            .values(revoked_at=revoked_at or datetime.now(timezone.utc))
        )
    return result.rowcount == 1
