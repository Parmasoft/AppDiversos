import hashlib
import json
import secrets
from copy import deepcopy
from datetime import datetime, timedelta, timezone

from flask import current_app
from sqlalchemy import and_, delete, select, text, update
from werkzeug.security import check_password_hash

from .canonical import CanonicalizationError, semantic_hash
from .database import database_now, get_engine
from .errors import ApiError
from .security import token_digest
from .sql import dialect_insert
from .tables import (
    agent_credential,
    agent_credential_company_access,
    delivery_read_operation,
    load_projection,
    manifest_projection,
    manifest_snapshot_state,
    occurrence_projection,
    order_projection,
    snapshot_publisher_lease,
    snapshot_receipt,
    stop_projection,
    mobile_session,
    mobile_driver_company_access,
    mobile_driver_identity,
)


def _aware(value):
    if value is None or value.tzinfo is not None:
        return value
    return value.replace(tzinfo=timezone.utc)


def _iso(value):
    return _aware(value).isoformat(timespec="seconds") if value else None


def _advisory_lock(connection, tenant_id, manifesto_guid):
    if connection.dialect.name != "postgresql":
        return
    material = f"{tenant_id}:{manifesto_guid}".encode("utf-8")
    lock_key = int.from_bytes(hashlib.sha256(material).digest()[:8], "big", signed=True)
    connection.execute(
        text("SELECT pg_advisory_xact_lock(:lock_key)"), {"lock_key": lock_key}
    )


def _snapshot_state(connection, tenant_id, manifesto_guid):
    return connection.execute(
        select(manifest_snapshot_state).where(
            and_(
                manifest_snapshot_state.c.tenant_id == tenant_id,
                manifest_snapshot_state.c.manifesto_guid == manifesto_guid,
            )
        )
    ).mappings().first()


def _authorized_company_ids(connection, agent, company_ids):
    """Return only active company scopes persisted for this credential."""
    wanted = {int(company_id) for company_id in company_ids}
    if not wanted:
        return set()
    rows = connection.execute(
        select(agent_credential_company_access.c.company_id).where(and_(
            agent_credential_company_access.c.agent_credential_id == agent["id"],
            agent_credential_company_access.c.active.is_(True),
            agent_credential_company_access.c.company_id.in_(wanted),
        ))
    ).scalars()
    return set(rows)


def _require_authorized_companies(connection, agent, company_ids):
    wanted = {int(company_id) for company_id in company_ids}
    denied = wanted - _authorized_company_ids(connection, agent, wanted)
    if denied:
        raise ApiError(
            403,
            "EMPRESA_NAO_AUTORIZADA",
            "Credencial do agente sem autorizacao para a empresa solicitada",
        )


def _require_agent_company_scope(connection, agent):
    """Deny technical endpoints for a credential with no active company link."""
    has_scope = connection.execute(
        select(agent_credential_company_access.c.company_id)
        .where(and_(
            agent_credential_company_access.c.agent_credential_id == agent["id"],
            agent_credential_company_access.c.active.is_(True),
        ))
        .limit(1)
    ).first()
    if has_scope is None:
        raise ApiError(
            403,
            "EMPRESA_NAO_AUTORIZADA",
            "Credencial do agente nao possui empresa autorizada",
        )


def _lease_response(agent, manifesto_guid, lease, state, result):
    return {
        "resultado": result,
        "tenant_key": agent["tenant_external_id"],
        "manifesto_guid": manifesto_guid,
        "agent_instance_guid": lease["agent_instance_guid"],
        "fencing_token": lease["fencing_token"],
        "current_revision": state["current_revision"] if state else 0,
        "current_semantic_hash": state["current_semantic_hash"] if state else None,
        "current_snapshot_id": state["current_snapshot_id"] if state else None,
        "expires_at": _iso(lease["expires_at"]),
    }


def acquire_snapshot_lease(agent, manifesto_guid, agent_instance_guid):
    with get_engine().begin() as connection:
        _advisory_lock(connection, agent["tenant_id"], manifesto_guid)
        now = database_now(connection)
        lease = connection.execute(
            select(snapshot_publisher_lease).where(
                and_(
                    snapshot_publisher_lease.c.tenant_id == agent["tenant_id"],
                    snapshot_publisher_lease.c.manifesto_guid == manifesto_guid,
                )
            )
        ).mappings().first()
        expires_at = now + timedelta(seconds=current_app.config["SNAPSHOT_LEASE_SECONDS"])
        if lease and _aware(lease["expires_at"]) > _aware(now):
            if (
                lease["agent_id"] != agent["id"]
                or lease["agent_instance_guid"] != agent_instance_guid
            ):
                raise ApiError(
                    409,
                    "SNAPSHOT_LEASE_OCUPADO",
                    f"Lease pertence a outro agente ate {_iso(lease['expires_at'])}",
                )
            connection.execute(
                update(snapshot_publisher_lease)
                .where(
                    and_(
                        snapshot_publisher_lease.c.tenant_id == agent["tenant_id"],
                        snapshot_publisher_lease.c.manifesto_guid == manifesto_guid,
                    )
                )
                .values(expires_at=expires_at, updated_at=now)
            )
            lease = dict(lease)
            lease.update(expires_at=expires_at, updated_at=now)
            result = "LEASE_RENOVADO"
        else:
            fencing_token = (lease["fencing_token"] if lease else 0) + 1
            statement = dialect_insert(connection, snapshot_publisher_lease).values(
                tenant_id=agent["tenant_id"],
                manifesto_guid=manifesto_guid,
                agent_id=agent["id"],
                agent_instance_guid=agent_instance_guid,
                fencing_token=fencing_token,
                expires_at=expires_at,
                updated_at=now,
            )
            statement = statement.on_conflict_do_update(
                index_elements=[
                    snapshot_publisher_lease.c.tenant_id,
                    snapshot_publisher_lease.c.manifesto_guid,
                ],
                set_={
                    "agent_id": statement.excluded.agent_id,
                    "agent_instance_guid": statement.excluded.agent_instance_guid,
                    "fencing_token": statement.excluded.fencing_token,
                    "expires_at": statement.excluded.expires_at,
                    "updated_at": statement.excluded.updated_at,
                },
            )
            connection.execute(statement)
            lease = {
                "agent_id": agent["id"],
                "agent_instance_guid": agent_instance_guid,
                "fencing_token": fencing_token,
                "expires_at": expires_at,
            }
            result = "LEASE_CONCEDIDO"
        state = _snapshot_state(connection, agent["tenant_id"], manifesto_guid)
        return _lease_response(agent, manifesto_guid, lease, state, result)


def _validated_lease(connection, agent, manifesto_guid, agent_instance_guid, fencing_token):
    lease = connection.execute(
        select(snapshot_publisher_lease).where(
            and_(
                snapshot_publisher_lease.c.tenant_id == agent["tenant_id"],
                snapshot_publisher_lease.c.manifesto_guid == manifesto_guid,
            )
        )
    ).mappings().first()
    if lease is None:
        raise ApiError(409, "SNAPSHOT_LEASE_INVALIDO", "Lease de snapshot inexistente")
    if fencing_token < lease["fencing_token"]:
        raise ApiError(409, "SNAPSHOT_FENCING_SUPERADO", "Fencing token foi substituido")
    if (
        fencing_token != lease["fencing_token"]
        or lease["agent_id"] != agent["id"]
        or lease["agent_instance_guid"] != agent_instance_guid
    ):
        raise ApiError(409, "SNAPSHOT_LEASE_INVALIDO", "Titularidade do lease inconsistente")
    now = database_now(connection)
    if _aware(lease["expires_at"]) <= _aware(now):
        raise ApiError(409, "SNAPSHOT_LEASE_EXPIRADO", "Lease de snapshot expirado")
    return lease, now


def renew_snapshot_lease(agent, manifesto_guid, agent_instance_guid, fencing_token):
    with get_engine().begin() as connection:
        _advisory_lock(connection, agent["tenant_id"], manifesto_guid)
        lease, now = _validated_lease(
            connection, agent, manifesto_guid, agent_instance_guid, fencing_token
        )
        expires_at = now + timedelta(seconds=current_app.config["SNAPSHOT_LEASE_SECONDS"])
        connection.execute(
            update(snapshot_publisher_lease)
            .where(
                and_(
                    snapshot_publisher_lease.c.tenant_id == agent["tenant_id"],
                    snapshot_publisher_lease.c.manifesto_guid == manifesto_guid,
                )
            )
            .values(expires_at=expires_at, updated_at=now)
        )
        lease = dict(lease)
        lease.update(expires_at=expires_at, updated_at=now)
        state = _snapshot_state(connection, agent["tenant_id"], manifesto_guid)
        return _lease_response(agent, manifesto_guid, lease, state, "LEASE_RENOVADO")


def _receipt_response(receipt, state, replay):
    return {
        "resultado": "ACEITA",
        "replay": int(replay),
        "aplicado": int(receipt["applied"]),
        "motivo": receipt["reason"],
        "snapshot_id": receipt["snapshot_id"],
        "snapshot_revision": receipt["snapshot_revision"],
        "current_revision": state["current_revision"],
        "current_semantic_hash": state["current_semantic_hash"],
        "current_snapshot_id": state["current_snapshot_id"],
    }


def publish_snapshot(agent, payload, agent_instance_guid, fencing_token):
    manifesto_guid = payload["manifesto"]["guid"]
    with get_engine().begin() as connection:
        _advisory_lock(connection, agent["tenant_id"], manifesto_guid)
        _lease, received_at = _validated_lease(
            connection, agent, manifesto_guid, agent_instance_guid, fencing_token
        )
        _require_authorized_companies(
            connection, agent, {payload["origem"]["empresa"]}
        )
        try:
            computed_hash = semantic_hash(payload)
        except CanonicalizationError as error:
            raise ApiError(400, "CONTRATO_INVALIDO", str(error))
        if computed_hash != payload["semantic_hash"]:
            raise ApiError(400, "SEMANTIC_HASH_INVALIDO", "semantic_hash diverge do payload")

        existing_id = connection.execute(
            select(snapshot_receipt).where(
                and_(
                    snapshot_receipt.c.tenant_id == agent["tenant_id"],
                    snapshot_receipt.c.snapshot_id == payload["snapshot_id"],
                )
            )
        ).mappings().first()
        state = _snapshot_state(connection, agent["tenant_id"], manifesto_guid)
        if existing_id:
            if (
                existing_id["manifesto_guid"] != manifesto_guid
                or existing_id["snapshot_revision"] != payload["snapshot_revision"]
                or existing_id["semantic_hash"] != computed_hash
            ):
                raise ApiError(
                    409,
                    "SNAPSHOT_ID_CONFLITO",
                    "snapshot_id ja recebido com identidade diferente",
                )
            return _receipt_response(existing_id, state, True), 200

        existing_revision = connection.execute(
            select(snapshot_receipt).where(
                and_(
                    snapshot_receipt.c.tenant_id == agent["tenant_id"],
                    snapshot_receipt.c.manifesto_guid == manifesto_guid,
                    snapshot_receipt.c.snapshot_revision == payload["snapshot_revision"],
                )
            )
        ).mappings().first()
        if existing_revision:
            if existing_revision["semantic_hash"] != computed_hash:
                raise ApiError(
                    409,
                    "SNAPSHOT_REVISION_CONFLITO",
                    "snapshot_revision ja recebido com outro conteudo",
                )
            return _receipt_response(existing_revision, state, True), 200

        current_revision = state["current_revision"] if state else 0
        current_hash = state["current_semantic_hash"] if state else None
        applied = False
        reason = None
        if payload["snapshot_revision"] < current_revision:
            reason = "SNAPSHOT_DESATUALIZADO"
        elif payload["snapshot_revision"] == current_revision:
            if computed_hash != current_hash:
                raise ApiError(
                    409,
                    "SNAPSHOT_REVISION_CONFLITO",
                    "snapshot_revision corrente possui outro conteudo",
                )
            reason = "CONTEUDO_JA_CONFIRMADO"
        elif current_hash is not None and computed_hash == current_hash:
            reason = "CONTEUDO_JA_CONFIRMADO"
        else:
            _upsert_projection(connection, agent["tenant_id"], payload, received_at)
            applied = True

        receipt_values = {
            "tenant_id": agent["tenant_id"],
            "manifesto_guid": manifesto_guid,
            "snapshot_id": payload["snapshot_id"],
            "snapshot_revision": payload["snapshot_revision"],
            "contract_version": payload["contrato_versao"],
            "semantic_hash": computed_hash,
            "generated_at": _parse_datetime(payload["gerado_em"]),
            "received_at": received_at,
            "agent_id": agent["id"],
            "accepted_fencing_token": fencing_token,
            "applied": applied,
            "reason": reason,
        }
        connection.execute(snapshot_receipt.insert().values(**receipt_values))

        if payload["snapshot_revision"] > current_revision:
            state_statement = dialect_insert(connection, manifest_snapshot_state).values(
                tenant_id=agent["tenant_id"],
                manifesto_guid=manifesto_guid,
                current_revision=payload["snapshot_revision"],
                current_semantic_hash=computed_hash,
                current_snapshot_id=payload["snapshot_id"],
                updated_at=received_at,
            )
            state_statement = state_statement.on_conflict_do_update(
                index_elements=[
                    manifest_snapshot_state.c.tenant_id,
                    manifest_snapshot_state.c.manifesto_guid,
                ],
                set_={
                    "current_revision": state_statement.excluded.current_revision,
                    "current_semantic_hash": state_statement.excluded.current_semantic_hash,
                    "current_snapshot_id": state_statement.excluded.current_snapshot_id,
                    "updated_at": state_statement.excluded.updated_at,
                },
            )
            connection.execute(state_statement)
            state = {
                "current_revision": payload["snapshot_revision"],
                "current_semantic_hash": computed_hash,
                "current_snapshot_id": payload["snapshot_id"],
            }
        else:
            state = dict(state)

        connection.execute(
            update(agent_credential)
            .where(agent_credential.c.id == agent["id"])
            .values(last_seen_at=received_at)
        )
        return _receipt_response(receipt_values, state, False), 201


def _parse_datetime(value):
    from datetime import datetime

    parsed = datetime.fromisoformat(value)
    return parsed if parsed.tzinfo else parsed.replace(tzinfo=timezone.utc)


def _upsert(connection, table, values, key_columns, update_columns):
    statement = dialect_insert(connection, table).values(**values)
    statement = statement.on_conflict_do_update(
        index_elements=key_columns,
        set_={name: getattr(statement.excluded, name) for name in update_columns},
    )
    connection.execute(statement)


def _tracking_status(occurrences):
    if occurrences and all(item["status"] == "E" for item in occurrences):
        return "ENTREGUE"
    if any(item["status"] != "P" for item in occurrences):
        return "EM_ANDAMENTO"
    return "PENDENTE"


def _projection_stop_guid(tenant_id, company_id, load_id, stop):
    """Returns the durable stop identity used by Cloud projections.

    CARGPA_GUID is nullable in legacy Firebird rows.  The fallback is local to
    the Cloud projection and is deterministic from the immutable natural key;
    it never materializes a value back in Firebird.
    """
    if stop["guid"]:
        return stop["guid"]
    return f"legacy-stop:v1:{tenant_id}:{company_id}:{load_id}:{stop['parada']}"


def _projection_payload(tenant_id, payload):
    """Normalizes only the projection copy, preserving the received payload."""
    normalized = deepcopy(payload)
    company_id = normalized["origem"]["empresa"]
    load_id = normalized["carga"]["id"]
    for stop in normalized["paradas"]:
        stop["guid"] = _projection_stop_guid(tenant_id, company_id, load_id, stop)
    return normalized


def _upsert_projection(connection, tenant_id, payload, updated_at):
    payload = _projection_payload(tenant_id, payload)
    manifest = payload["manifesto"]
    load = payload["carga"]
    driver = payload["motorista"]
    stops = payload["paradas"]
    company_id = payload["origem"]["empresa"]
    load_guid = f"{company_id}:{load['id']}"
    all_occurrences = [item for stop in stops for item in stop["ocorrencias"]]

    order_guids = select(order_projection.c.order_guid).where(
        and_(
            order_projection.c.tenant_id == tenant_id,
            order_projection.c.manifest_guid == manifest["guid"],
        )
    )
    connection.execute(
        delete(occurrence_projection).where(
            and_(
                occurrence_projection.c.tenant_id == tenant_id,
                occurrence_projection.c.order_guid.in_(order_guids),
            )
        )
    )
    connection.execute(
        delete(order_projection).where(
            and_(
                order_projection.c.tenant_id == tenant_id,
                order_projection.c.manifest_guid == manifest["guid"],
            )
        )
    )
    connection.execute(
        delete(stop_projection).where(
            and_(
                stop_projection.c.tenant_id == tenant_id,
                stop_projection.c.manifest_guid == manifest["guid"],
            )
        )
    )

    load_values = {
        "tenant_id": tenant_id,
        "load_guid": load_guid,
        "load_number": load["id"],
        "company_id": company_id,
        "driver_guid": driver["guid"],
        "driver_name": driver["nome"],
        "technical_status": manifest["status"],
        "tracking_status": _tracking_status(all_occurrences),
        "started_at": load.get("saida_data"),
        "completed_at": None,
        "snapshot_id": payload["snapshot_id"],
        "updated_at": updated_at,
    }
    _upsert(
        connection,
        load_projection,
        load_values,
        [load_projection.c.tenant_id, load_projection.c.load_guid],
        [name for name in load_values if name not in {"tenant_id", "load_guid"}],
    )

    manifest_values = {
        "tenant_id": tenant_id,
        "manifest_guid": manifest["guid"],
        "manifest_id": manifest["id"],
        "load_guid": load_guid,
        "load_number": load["id"],
        "company_id": company_id,
        "driver_guid": driver["guid"],
        "technical_status": manifest["status"],
        "tracking_status": _tracking_status(all_occurrences),
        "occurrence_count": len(all_occurrences),
        "detail_json": payload,
        "snapshot_id": payload["snapshot_id"],
        "updated_at": updated_at,
    }
    _upsert(
        connection,
        manifest_projection,
        manifest_values,
        [manifest_projection.c.tenant_id, manifest_projection.c.manifest_guid],
        [name for name in manifest_values if name not in {"tenant_id", "manifest_guid"}],
    )

    for stop in stops:
        stop_values = {
            "tenant_id": tenant_id,
            "stop_guid": stop["guid"],
            "manifest_guid": manifest["guid"],
            "stop_id": stop["parada"],
            "sequence_number": stop["ordem"].get("realizada")
            or stop["ordem"].get("sugerida")
            or stop["ordem"].get("planejada")
            or stop["parada"],
            "technical_status": stop["status"],
            "tracking_status": _tracking_status(stop["ocorrencias"]),
            "completed_at": None,
            "snapshot_id": payload["snapshot_id"],
            "updated_at": updated_at,
        }
        _upsert(
            connection,
            stop_projection,
            stop_values,
            [stop_projection.c.tenant_id, stop_projection.c.stop_guid],
            [name for name in stop_values if name not in {"tenant_id", "stop_guid"}],
        )
        for order in stop["pedidos"]:
            order_occurrences = [
                item for item in stop["ocorrencias"] if item["pedido"] == order["pedido"]
            ]
            customer = stop["cliente"]
            order_guid = f"{company_id}:{manifest['id']}:{order['pedido']}"
            order_values = {
                "tenant_id": tenant_id,
                "order_guid": order_guid,
                "stop_guid": stop["guid"],
                "manifest_guid": manifest["guid"],
                "order_id": order["pedido"],
                "order_number": order["pedido"],
                "customer_id": customer["id"],
                "customer_name": customer["nome"],
                "notification_email": customer.get("email_notificacao"),
                "accepts_email": bool(customer.get("aceita_email", False)),
                "technical_status": order["status"],
                "tracking_status": _tracking_status(order_occurrences),
                "delivered_at": None,
                "snapshot_id": payload["snapshot_id"],
                "updated_at": updated_at,
            }
            _upsert(
                connection,
                order_projection,
                order_values,
                [order_projection.c.tenant_id, order_projection.c.order_guid],
                [name for name in order_values if name not in {"tenant_id", "order_guid"}],
            )
            for occurrence in order_occurrences:
                occurrence_values = {
                    "tenant_id": tenant_id,
                    "occurrence_guid": occurrence["guid"],
                    "order_guid": order_guid,
                    "occurrence_id": occurrence["ocorrencia"],
                    "occurrence_type": occurrence["tipo"],
                    "technical_status": occurrence["status"],
                    "version_number": occurrence["versao_registro"],
                    "occurred_at": None,
                    "snapshot_id": payload["snapshot_id"],
                    "updated_at": updated_at,
                }
                _upsert(
                    connection,
                    occurrence_projection,
                    occurrence_values,
                    [occurrence_projection.c.tenant_id, occurrence_projection.c.occurrence_guid],
                    [
                        name
                        for name in occurrence_values
                        if name not in {"tenant_id", "occurrence_guid"}
                    ],
                )


def _detail(value):
    return json.loads(value) if isinstance(value, str) else dict(value)


def _company_allowed(connection, session, company_id):
    identity_exists = connection.execute(select(mobile_driver_identity.c.driver_guid).where(and_(
        mobile_driver_identity.c.tenant_id == session["tenant_id"],
        mobile_driver_identity.c.driver_guid == session["driver_guid"],
    )).limit(1)).first()
    if identity_exists is None:  # QR legado provisionado antes da identidade.
        return True
    return connection.execute(select(mobile_driver_company_access.c.driver_guid).where(and_(
        mobile_driver_company_access.c.tenant_id == session["tenant_id"],
        mobile_driver_company_access.c.driver_guid == session["driver_guid"],
        mobile_driver_company_access.c.company_id == company_id,
        mobile_driver_company_access.c.active.is_(True),
    )).limit(1)).first() is not None


def list_trips(session):
    statement = (
        select(manifest_projection.c.detail_json)
        .where(
            and_(
                manifest_projection.c.tenant_id == session["tenant_id"],
                manifest_projection.c.driver_guid == session["driver_guid"],
            )
        )
        .order_by(manifest_projection.c.load_number, manifest_projection.c.manifest_id)
    )
    with get_engine().connect() as connection:
        rows = connection.execute(statement).scalars().all()
    result = []
    for value in rows:
        detail = _detail(value)
        with get_engine().connect() as connection:
            if not _company_allowed(connection, session, detail["origem"]["empresa"]):
                continue
        result.append(
            {
                "manifesto_guid": detail["manifesto"]["guid"],
                "empresa": detail["origem"]["empresa"],
                "manifesto": detail["manifesto"]["id"],
                "carga": detail["carga"]["id"],
                "versao": detail["manifesto"]["versao"],
                "liberado_em": detail["manifesto"].get("liberado_em"),
                "descricao": detail["carga"].get("descricao"),
                "saida_data": detail["carga"].get("saida_data"),
                "saida_hora": detail["carga"].get("saida_hora"),
                "quantidade_paradas": len(detail["paradas"]),
                "quantidade_ocorrencias": detail["quantidade_ocorrencias"],
            }
        )
    return result


def get_trip(session, manifesto_guid):
    statement = select(manifest_projection.c.detail_json).where(
        and_(
            manifest_projection.c.tenant_id == session["tenant_id"],
            manifest_projection.c.driver_guid == session["driver_guid"],
            manifest_projection.c.manifest_guid == manifesto_guid,
        )
    )
    with get_engine().connect() as connection:
        value = connection.execute(statement).scalar_one_or_none()
    if value is None:
        raise ApiError(404, "VIAGEM_NAO_ENCONTRADA", "Viagem nao encontrada")
    detail = _detail(value)
    with get_engine().connect() as connection:
        if not _company_allowed(connection, session, detail["origem"]["empresa"]):
            raise ApiError(404, "VIAGEM_NAO_ENCONTRADA", "Viagem nao encontrada")
    for field in (
        "contrato_versao",
        "snapshot_id",
        "snapshot_revision",
        "semantic_hash",
        "gerado_em",
    ):
        detail.pop(field, None)
    return detail


def renew_mobile_session(payload):
    if not isinstance(payload, dict) or set(payload) != {"refresh_token"}:
        raise ApiError(400, "CONTRATO_INVALIDO", "refresh_token obrigatorio")
    raw_token = str(payload["refresh_token"]).strip()
    if not raw_token:
        raise ApiError(400, "CONTRATO_INVALIDO", "refresh_token obrigatorio")
    from .security import token_digest

    with get_engine().begin() as connection:
        session = connection.execute(
            select(mobile_session).where(
                and_(
                    mobile_session.c.refresh_token_digest == token_digest(raw_token),
                    mobile_session.c.revoked_at.is_(None),
                )
            )
        ).mappings().first()
        if session is None:
            raise ApiError(401, "SESSAO_INVALIDA", "Refresh token invalido")
        if _aware(session["expires_at"]) <= _aware(database_now(connection)):
            raise ApiError(401, "SESSAO_EXPIRADA", "Sessao expirada")
        access_token = secrets.token_urlsafe(32)
        now = database_now(connection)
        access_expires_at = min(
            _aware(session["expires_at"]),
            _aware(now) + timedelta(seconds=current_app.config["MOBILE_ACCESS_TOKEN_SECONDS"]),
        )
        connection.execute(
            update(mobile_session)
            .where(mobile_session.c.id == session["id"])
            .values(token_digest=token_digest(access_token))
        )
        return {
            "access_token": access_token,
            "refresh_token": raw_token,
            "access_expires_at": _iso(access_expires_at),
            "motorista": {"guid": session["driver_guid"], "nome": ""},
        }


def sync_driver_identities(agent, projection):
    """Replace the Agent's company scopes while preserving no secret in logs."""
    now = None
    changed_drivers = set()
    identities = projection["identities"]
    companies = projection["companies"]
    with get_engine().begin() as connection:
        now = database_now(connection)
        _require_authorized_companies(connection, agent, companies)
        for item in identities:
            existing = connection.execute(select(mobile_driver_identity).where(and_(
                mobile_driver_identity.c.tenant_id == agent["tenant_id"],
                mobile_driver_identity.c.driver_guid == item["driver_guid"],
            ))).mappings().first()
            changed = existing is not None and any(existing[key] != item[source] for key, source in (
                ("password_verifier", "password_verifier"), ("active", "driver_active"),
                ("login_normalized", "login_normalized"),
            ))
            if existing is None:
                connection.execute(mobile_driver_identity.insert().values(
                    tenant_id=agent["tenant_id"], driver_guid=item["driver_guid"],
                    driver_app_id=item["driver_app_id"], driver_name=item["driver_name"],
                    login_normalized=item["login_normalized"], password_verifier=item["password_verifier"],
                    active=item["driver_active"], updated_at=now,
                ))
            else:
                connection.execute(update(mobile_driver_identity).where(and_(
                    mobile_driver_identity.c.tenant_id == agent["tenant_id"],
                    mobile_driver_identity.c.driver_guid == item["driver_guid"],
                )).values(driver_app_id=item["driver_app_id"], driver_name=item["driver_name"],
                    login_normalized=item["login_normalized"], password_verifier=item["password_verifier"],
                    active=item["driver_active"], updated_at=now))
            if changed or not item["driver_active"]:
                changed_drivers.add(item["driver_guid"])
            access = connection.execute(select(mobile_driver_company_access).where(and_(
                mobile_driver_company_access.c.tenant_id == agent["tenant_id"],
                mobile_driver_company_access.c.company_id == item["company_id"],
                mobile_driver_company_access.c.driver_guid == item["driver_guid"],
            ))).mappings().first()
            if access is not None and (access["active"] != item["access_active"] or access["transporter_id"] != item["transporter_id"]):
                changed_drivers.add(item["driver_guid"])
            statement = dialect_insert(connection, mobile_driver_company_access).values(
                tenant_id=agent["tenant_id"], company_id=item["company_id"], driver_guid=item["driver_guid"],
                transporter_id=item["transporter_id"], active=item["access_active"], updated_at=now,
            )
            statement = statement.on_conflict_do_update(
                index_elements=["tenant_id", "company_id", "driver_guid"],
                set_={"transporter_id": statement.excluded.transporter_id, "active": statement.excluded.active, "updated_at": statement.excluded.updated_at},
            )
            connection.execute(statement)
        if companies:
            active_keys = {(item["company_id"], item["driver_guid"]) for item in identities}
            previous = connection.execute(select(mobile_driver_company_access).where(and_(
                mobile_driver_company_access.c.tenant_id == agent["tenant_id"],
                mobile_driver_company_access.c.company_id.in_(companies),
                mobile_driver_company_access.c.active.is_(True),
            ))).mappings().all()
            for access in previous:
                if (access["company_id"], access["driver_guid"]) not in active_keys:
                    connection.execute(update(mobile_driver_company_access).where(and_(
                        mobile_driver_company_access.c.tenant_id == agent["tenant_id"],
                        mobile_driver_company_access.c.company_id == access["company_id"],
                        mobile_driver_company_access.c.driver_guid == access["driver_guid"],
                    )).values(active=False, updated_at=now))
                    changed_drivers.add(access["driver_guid"])
        if changed_drivers:
            connection.execute(update(mobile_session).where(and_(
                mobile_session.c.tenant_id == agent["tenant_id"],
                mobile_session.c.driver_guid.in_(changed_drivers), mobile_session.c.revoked_at.is_(None),
            )).values(revoked_at=now))
    return {"resultado": "IDENTIDADES_SINCRONIZADAS", "quantidade": len(identities)}


def login_mobile(login_normalized, password, device=None):
    with get_engine().begin() as connection:
        rows = connection.execute(select(mobile_driver_identity).where(and_(
            mobile_driver_identity.c.login_normalized == login_normalized,
            mobile_driver_identity.c.active.is_(True),
        ))).mappings().all()
        rows = [row for row in rows if connection.execute(select(mobile_driver_company_access.c.driver_guid).where(and_(
            mobile_driver_company_access.c.tenant_id == row["tenant_id"],
            mobile_driver_company_access.c.driver_guid == row["driver_guid"],
            mobile_driver_company_access.c.active.is_(True),
        )).limit(1)).first()]
        if len(rows) != 1 or not check_password_hash(rows[0]["password_verifier"] if rows else _dummy_password_hash(), password):
            raise ApiError(401, "CREDENCIAIS_INVALIDAS", "Usuario ou senha invalidos")
        identity = rows[0]
        now = database_now(connection)
        expires_at = now + timedelta(seconds=current_app.config["MOBILE_SESSION_SECONDS"])
        access_token, refresh_token = secrets.token_urlsafe(32), secrets.token_urlsafe(32)
        connection.execute(mobile_session.insert().values(
            tenant_id=identity["tenant_id"], driver_guid=identity["driver_guid"],
            token_digest=token_digest(access_token),
            refresh_token_digest=token_digest(refresh_token),
            expires_at=expires_at, created_at=now,
        ))
        return {"token_type": "Bearer", "access_token": access_token, "refresh_token": refresh_token,
                "access_expires_at": _iso(min(_aware(expires_at), _aware(now) + timedelta(seconds=current_app.config["MOBILE_ACCESS_TOKEN_SECONDS"]))),
                "expires_in": current_app.config["MOBILE_ACCESS_TOKEN_SECONDS"],
                "motorista": {"guid": identity["driver_guid"], "nome": identity["driver_name"]}}


def _dummy_password_hash():
    from werkzeug.security import generate_password_hash
    return generate_password_hash("credencial-inexistente")


def _delivery_response(result, code, message, operation_guid, occurrence=None, pending_order=None, pending_stop=None, replay=False):
    return {
        "resultado": result, "codigo": code, "codigo_resposta": code, "mensagem": message,
        "operacao": operation_guid, "ocorrencia_guid": occurrence,
        "tipo": None, "pedido": None, "pendentes_pedido": pending_order,
        "pendentes_parada": pending_stop, "replay": replay,
    }


def _read_hash(manifest_guid, stop_id, order_id, payload):
    material = json.dumps(
        {"manifesto_guid": manifest_guid, "stop_id": stop_id, "order_id": order_id, **payload},
        sort_keys=True, separators=(",", ":"), ensure_ascii=True,
    )
    return hashlib.sha256(material.encode("utf-8")).hexdigest()


def register_delivery_read(session, manifest_guid, stop_id, order_id, payload):
    request_hash = _read_hash(manifest_guid, stop_id, order_id, payload)
    with get_engine().begin() as connection:
        _advisory_lock(connection, session["tenant_id"], manifest_guid)
        existing = connection.execute(
            select(delivery_read_operation).where(and_(
                delivery_read_operation.c.tenant_id == session["tenant_id"],
                delivery_read_operation.c.operation_guid == payload["operacao_guid"],
            ))
        ).mappings().first()
        if existing:
            if existing["request_hash"] != request_hash:
                response = _delivery_response("CONFLITO", "OPERACAO_GUID_CONFLITO", "operacao_guid ja utilizado com outro payload", payload["operacao_guid"])
                return response, 409
            response = dict(existing["response_json"])
            response["replay"] = True
            return response, 200

        row = connection.execute(select(manifest_projection).where(and_(
            manifest_projection.c.tenant_id == session["tenant_id"],
            manifest_projection.c.driver_guid == session["driver_guid"],
            manifest_projection.c.manifest_guid == manifest_guid,
        ))).mappings().first()
        if row is None:
            raise ApiError(404, "VIAGEM_NAO_ENCONTRADA", "Viagem nao encontrada")
        detail = _detail(row["detail_json"])
        if detail["carga"]["id"] in current_app.config["DELIVERY_DENIED_LOAD_IDS"]:
            raise ApiError(403, "CARGA_NAO_AUTORIZADA", "Carga nao autorizada para delivery_read")
        stop = next((value for value in detail["paradas"] if value["parada"] == stop_id), None)
        occurrence_guid = payload.get("occurrence_guid")
        occurrence = next(
            (
                value
                for candidate_stop in detail["paradas"]
                for value in candidate_stop["ocorrencias"]
                if occurrence_guid and value.get("guid") == occurrence_guid
            ),
            None,
        )
        if occurrence_guid is None:
            response = _delivery_response(
                "RECUSADA", "OCORRENCIA_GUID_OBRIGATORIA",
                "occurrence_guid e obrigatorio para novas operacoes",
                payload["operacao_guid"],
            )
        elif occurrence is None:
            response = _delivery_response(
                "RECUSADA", "OCORRENCIA_NAO_ENCONTRADA",
                "Ocorrencia nao pertence a esta viagem",
                payload["operacao_guid"],
            )
        elif stop is None:
            response = _delivery_response("RECUSADA", "OUTRA_PARADA", "Parada nao pertence a esta viagem", payload["operacao_guid"])
        elif occurrence not in stop["ocorrencias"] or occurrence.get("pedido") != order_id:
            response = _delivery_response(
                "RECUSADA", "OCORRENCIA_FORA_DO_ESCOPO",
                "Ocorrencia nao pertence a esta parada ou pedido",
                payload["operacao_guid"],
            )
        elif str(occurrence.get("codigo", "")).strip().upper() != payload["codigo"]:
            response = _delivery_response(
                "RECUSADA", "CODIGO_DIVERGENTE",
                "Codigo nao corresponde a ocorrencia informada",
                payload["operacao_guid"],
            )
        elif occurrence.get("status") != "P":
            response = _delivery_response(
                "RECUSADA", "OCORRENCIA_JA_ENTREGUE",
                "Ocorrencia ja recepcionada",
                payload["operacao_guid"], occurrence["guid"],
            )
        else:
            occurrence["status"] = "E"
            pending_order = sum(1 for value in stop["ocorrencias"] if value["pedido"] == order_id and value["status"] == "P")
            pending_stop = sum(1 for value in stop["ocorrencias"] if value["status"] == "P")
            for order in stop["pedidos"]:
                if order["pedido"] == order_id and pending_order == 0:
                    order["status"] = "E"
            if pending_stop == 0:
                stop["status"] = "E"
            response = _delivery_response("ACEITA", "LEITURA_CONFIRMADA", "Leitura confirmada", payload["operacao_guid"], occurrence["guid"], pending_order, pending_stop)
            # Nesta etapa a projeção continua estritamente read-only. O ledger
            # registra a intenção idempotente, mas a confirmação operacional e
            # qualquer alteração de projeção pertencem a um bloco posterior.

        connection.execute(delivery_read_operation.insert().values(
            tenant_id=session["tenant_id"], operation_guid=payload["operacao_guid"], driver_guid=session["driver_guid"], manifest_guid=manifest_guid,
            stop_id=stop_id, order_id=order_id, request_hash=request_hash, request_json=payload,
            response_json=response, created_at=database_now(connection),
            return_contract_version=1, return_payload_hash=request_hash,
            return_state="PENDING" if response["resultado"] == "ACEITA" else "REJECTED",
            return_attempt_count=0,
        ))
        return response, 200


def _return_payload(row):
    request = row["request_json"]
    return {
        "empresa": row["empresa"],
        "contrato_versao": row["return_contract_version"],
        "payload_hash": row["return_payload_hash"],
        "operation_guid": row["operation_guid"],
        "manifest_guid": row["manifest_guid"],
        "stop_id": row["stop_id"],
        "order_id": row["order_id"],
        "codigo": request["codigo"],
        "data_hora_aparelho": request["data_hora_aparelho"],
        "fuso_minutos": request["fuso_minutos"],
        "expected_occurrence_guid": row["response_json"].get("ocorrencia_guid"),
    }


def claim_delivery_returns(agent, instance_guid, limit=20, operation_guid=None):
    """Lease pending mobile ledger rows to one technical Agent instance."""
    claimed = []
    with get_engine().begin() as connection:
        _require_agent_company_scope(connection, agent)
        now = database_now(connection)
        expires_at = now + timedelta(seconds=current_app.config["DELIVERY_RETURN_CLAIM_SECONDS"])
        conditions = [
                delivery_read_operation.c.tenant_id == agent["tenant_id"],
                delivery_read_operation.c.return_state.in_(("PENDING", "CLAIMED")),
                (delivery_read_operation.c.return_state == "PENDING") |
                (delivery_read_operation.c.claim_expires_at < now),
        ]
        if operation_guid is not None:
            conditions.append(delivery_read_operation.c.operation_guid == operation_guid)
        candidates = connection.execute(
            select(
                delivery_read_operation,
                manifest_projection.c.company_id.label("empresa"),
            )
            .join(manifest_projection, and_(
                manifest_projection.c.tenant_id == delivery_read_operation.c.tenant_id,
                manifest_projection.c.manifest_guid == delivery_read_operation.c.manifest_guid,
            ))
            .join(agent_credential_company_access, and_(
                agent_credential_company_access.c.agent_credential_id == agent["id"],
                agent_credential_company_access.c.company_id == manifest_projection.c.company_id,
                agent_credential_company_access.c.active.is_(True),
            ))
            .where(and_(*conditions))
            .order_by(delivery_read_operation.c.created_at)
            .limit(1 if operation_guid is not None else limit)
            .with_for_update(skip_locked=True)
        ).mappings().all()
        for row in candidates:
            connection.execute(update(delivery_read_operation).where(
                delivery_read_operation.c.id == row["id"]
            ).values(
                return_state="CLAIMED", claimed_by_agent_id=agent["id"],
                claimed_instance_guid=instance_guid, claim_expires_at=expires_at,
                return_attempt_count=delivery_read_operation.c.return_attempt_count + 1,
            ))
            claimed.append(_return_payload(row))
    return {"operacoes": claimed, "claim_expires_at": _iso(expires_at)}


def acknowledge_delivery_return(agent, instance_guid, result):
    terminal = "APPLIED" if result["resultado"] == "ACEITA" else "REJECTED"
    with get_engine().begin() as connection:
        _require_agent_company_scope(connection, agent)
        row = connection.execute(
            select(delivery_read_operation)
            .select_from(
                delivery_read_operation
                .join(manifest_projection, and_(
                    manifest_projection.c.tenant_id == delivery_read_operation.c.tenant_id,
                    manifest_projection.c.manifest_guid == delivery_read_operation.c.manifest_guid,
                ))
                .join(agent_credential_company_access, and_(
                    agent_credential_company_access.c.agent_credential_id == agent["id"],
                    agent_credential_company_access.c.company_id == manifest_projection.c.company_id,
                    agent_credential_company_access.c.active.is_(True),
                ))
            )
            .where(and_(
                delivery_read_operation.c.tenant_id == agent["tenant_id"],
                delivery_read_operation.c.operation_guid == result["operation_guid"],
            ))
            .with_for_update()
        ).mappings().first()
        if row is None:
            raise ApiError(404, "OPERACAO_NAO_ENCONTRADA", "Operacao de retorno nao encontrada")
        if row["return_state"] in {"APPLIED", "REJECTED"}:
            return {"resultado": row["return_state"], "replay": True}
        if row["claimed_by_agent_id"] != agent["id"] or row["claimed_instance_guid"] != instance_guid:
            raise ApiError(409, "CLAIM_INVALIDO", "Operacao nao pertence a esta instancia do Agent")
        connection.execute(update(delivery_read_operation).where(
            delivery_read_operation.c.id == row["id"]
        ).values(return_state=terminal, return_result_json=result, returned_at=database_now(connection)))
    return {"resultado": terminal, "replay": False}
