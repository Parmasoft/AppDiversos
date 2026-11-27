import hashlib
import json
from datetime import datetime, timezone

from sqlalchemy import and_, select

from .contracts import validate_tracking_event
from .database import get_engine
from .errors import ApiError
from .sql import dialect_insert
from .tables import notification_outbox, tenant, tracking_event


EVENT_TYPES = {"SAIU_PARA_ENTREGA", "PEDIDO_ENTREGUE"}


def logical_event_key(tenant_id, event):
    parts = [
        str(tenant_id),
        event["manifesto_guid"],
        event.get("parada_guid") or "-",
        event.get("pedido_guid") or "-",
        event["tipo"],
        str(event["versao_evento"]),
    ]
    return hashlib.sha256("|".join(parts).encode("utf-8")).hexdigest()


def _datetime(value):
    parsed = value if isinstance(value, datetime) else datetime.fromisoformat(value)
    return parsed if parsed.tzinfo else parsed.replace(tzinfo=timezone.utc)


def _canonical(value):
    return json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":"))


def record_authoritative_event(tenant_id, event):
    """Internal service only. This block deliberately exposes no HTTP event endpoint."""
    validate_tracking_event(event)
    if event.get("fonte_autoritativa") != "FIREBIRD":
        raise ApiError(422, "FONTE_NAO_AUTORITATIVA", "Evento exige confirmacao Firebird")
    if event.get("tipo") not in EVENT_TYPES:
        raise ApiError(422, "EVENTO_INVALIDO", "Tipo de evento nao suportado")
    if event["tipo"] == "PEDIDO_ENTREGUE" and not event.get("operacao_guid"):
        raise ApiError(
            422,
            "OPERACAO_GUID_OBRIGATORIO",
            "Entrega exige OPERACAO_GUID confirmado",
        )

    key = logical_event_key(tenant_id, event)
    canonical_payload = _canonical(event)
    created_at = datetime.now(timezone.utc)
    with get_engine().begin() as connection:
        existing = connection.execute(
            select(tracking_event.c.id, tracking_event.c.payload_json).where(
                and_(
                    tracking_event.c.tenant_id == tenant_id,
                    tracking_event.c.logical_key == key,
                )
            )
        ).mappings().first()
        if existing:
            if _canonical(existing["payload_json"]) != canonical_payload:
                raise ApiError(
                    409,
                    "EVENTO_LOGICO_CONFLITO",
                    "Evento logico ja existe com outro conteudo",
                )
            return {"resultado": "ACEITA", "replay": 1, "evento_id": existing["id"]}

        result = connection.execute(
            tracking_event.insert().values(
                tenant_id=tenant_id,
                logical_key=key,
                event_type=event["tipo"],
                event_version=event["versao_evento"],
                occurred_at=_datetime(event["ocorrido_em"]),
                authoritative_source=event["fonte_autoritativa"],
                operation_guid=event.get("operacao_guid"),
                load_guid=event["carga_guid"],
                manifest_guid=event["manifesto_guid"],
                stop_guid=event.get("parada_guid"),
                order_guid=event.get("pedido_guid"),
                payload_json=event,
                created_at=created_at,
            )
        )
        event_id = result.inserted_primary_key[0]
        activated_at = connection.execute(
            select(tenant.c.tracking_activated_at).where(tenant.c.id == tenant_id)
        ).scalar_one()
        customer = event.get("cliente") or {}
        recipient = customer.get("email_notificacao")
        accepts_email = customer.get("aceita_email", False)
        after_activation = bool(activated_at) and _datetime(event["ocorrido_em"]) >= _datetime(
            activated_at
        )
        if after_activation and recipient and accepts_email:
            idempotency_key = hashlib.sha256(
                f"{key}|EMAIL|{recipient.lower()}".encode("utf-8")
            ).hexdigest()
            statement = dialect_insert(connection, notification_outbox).values(
                tenant_id=tenant_id,
                tracking_event_id=event_id,
                channel="EMAIL",
                recipient=recipient,
                idempotency_key=idempotency_key,
                status="PENDING",
                created_at=created_at,
            )
            connection.execute(
                statement.on_conflict_do_nothing(
                    index_elements=[
                        notification_outbox.c.tenant_id,
                        notification_outbox.c.idempotency_key,
                    ]
                )
            )
        return {"resultado": "ACEITA", "replay": 0, "evento_id": event_id}
