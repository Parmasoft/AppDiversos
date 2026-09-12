import hashlib
import json
import secrets
from copy import deepcopy
from datetime import datetime, timedelta, timezone

from flask import current_app
from sqlalchemy import and_, delete, select, text, update

from .canonical import CanonicalizationError, semantic_hash
from .database import database_now, get_engine
from .errors import ApiError
from .sql import dialect_insert
from .tables import (
    agent_credential,
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
        candidates = [] if stop is None else [
            value for value in stop["ocorrencias"]
            if value["pedido"] == order_id
            and str(value.get("codigo", "")).strip().upper() == payload["codigo"]
        ]
        occurrence = next((value for value in candidates if value["status"] == "P"), None)
        if stop is None:
            response = _delivery_response("RECUSADA", "OUTRA_PARADA", "Parada nao pertence a esta viagem", payload["operacao_guid"])
        elif not candidates:
            same_stop = any(str(value.get("codigo", "")).strip().upper() == payload["codigo"] for value in stop["ocorrencias"])
            same_manifest = any(str(value.get("codigo", "")).strip().upper() == payload["codigo"] for candidate in detail["paradas"] for value in candidate["ocorrencias"])
            code = "OUTRO_PEDIDO" if same_stop else "OUTRA_PARADA" if same_manifest else "CODIGO_NAO_DISPONIVEL"
            response = _delivery_response("RECUSADA", code, "Codigo nao disponivel para este pedido", payload["operacao_guid"])
        elif occurrence is None:
            code = "ROLO_JA_RECEPCIONADO" if any(value.get("tipo") == "R" for value in candidates) else "MULTIPLICIDADE_ESGOTADA"
            response = _delivery_response("RECUSADA", code, "Ocorrencia ja recepcionada", payload["operacao_guid"])
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
        ))
        return response, 200
