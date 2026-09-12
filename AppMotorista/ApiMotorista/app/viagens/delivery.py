import hashlib
import json
import math
from datetime import datetime
from decimal import Decimal, InvalidOperation
from uuid import UUID

from app.api_errors import ApiError
from .repository import register_delivery_operation


PAYLOAD_VERSION = 1
_ALLOWED_FIELDS = {
    "operacao_guid",
    "codigo",
    "data_hora_aparelho",
    "fuso_minutos",
    "latitude",
    "longitude",
    "precisao",
}


def _uuid(value, field_name):
    if not isinstance(value, str):
        raise ApiError(f"{field_name} invalido.", 400)
    try:
        return str(UUID(value.strip())).upper()
    except (ValueError, AttributeError):
        raise ApiError(f"{field_name} invalido.", 400)


def _optional_integer(value, field_name):
    if value is None:
        return None
    if isinstance(value, bool) or not isinstance(value, int):
        raise ApiError(f"{field_name} invalido.", 400)
    return value


def _optional_decimal(value, field_name, integer_digits, scale):
    if value is None:
        return None
    if isinstance(value, bool) or not isinstance(value, (int, float, str, Decimal)):
        raise ApiError(f"{field_name} invalido.", 400)
    if isinstance(value, float) and not math.isfinite(value):
        raise ApiError(f"{field_name} invalido.", 400)
    try:
        result = Decimal(str(value).strip())
    except (InvalidOperation, ValueError):
        raise ApiError(f"{field_name} invalido.", 400)
    if not result.is_finite():
        raise ApiError(f"{field_name} invalido.", 400)
    maximum = Decimal(10) ** integer_digits
    if abs(result) >= maximum:
        raise ApiError(f"{field_name} fora do intervalo suportado.", 400)
    quantum = Decimal(1).scaleb(-scale)
    return result.quantize(quantum)


def _canonical_decimal(value):
    if value is None:
        return None
    if value == 0:
        return "0"
    return format(value.normalize(), "f")


def _device_datetime(value, fuso_minutos):
    if value is None:
        return None, fuso_minutos
    if not isinstance(value, str) or not value.strip():
        raise ApiError("data_hora_aparelho invalida.", 400)

    source = value.strip()
    if source.endswith(("Z", "z")):
        source = source[:-1] + "+00:00"
    try:
        parsed = datetime.fromisoformat(source)
    except ValueError:
        raise ApiError("data_hora_aparelho invalida.", 400)

    if parsed.tzinfo is not None:
        offset = parsed.utcoffset()
        if offset is None or offset.total_seconds() % 60:
            raise ApiError("data_hora_aparelho possui fuso invalido.", 400)
        timestamp_offset = int(offset.total_seconds() // 60)
        if fuso_minutos is not None and fuso_minutos != timestamp_offset:
            raise ApiError("fuso_minutos diverge de data_hora_aparelho.", 400)
        fuso_minutos = timestamp_offset
        parsed = parsed.replace(tzinfo=None)

    return parsed, fuso_minutos


def _payload_hash(canonical_payload):
    serialized = json.dumps(
        canonical_payload,
        ensure_ascii=False,
        separators=(",", ":"),
        sort_keys=True,
    ).encode("utf-8")
    return hashlib.sha256(serialized).hexdigest().upper()


def register_delivery(
    motorista_id,
    sessao_id,
    dispositivo,
    manifesto_guid,
    parada,
    pedido,
    payload,
):
    if not isinstance(payload, dict):
        raise ApiError("Payload JSON invalido.", 400)

    unexpected = set(payload) - _ALLOWED_FIELDS
    if unexpected:
        raise ApiError("O payload contem campos nao permitidos.", 400)

    if isinstance(parada, bool) or parada <= 0 or isinstance(pedido, bool) or pedido <= 0:
        raise ApiError("Parada ou pedido invalido.", 400)

    manifesto_guid = _uuid(manifesto_guid, "manifesto_guid")
    operacao_guid = _uuid(payload.get("operacao_guid"), "operacao_guid")

    codigo = payload.get("codigo")
    if not isinstance(codigo, str):
        raise ApiError("codigo invalido.", 400)
    codigo = codigo.strip().upper()
    if not codigo or len(codigo) > 60:
        raise ApiError("codigo invalido.", 400)

    fuso_minutos = _optional_integer(payload.get("fuso_minutos"), "fuso_minutos")
    if fuso_minutos is not None and not -32768 <= fuso_minutos <= 32767:
        raise ApiError("fuso_minutos fora do intervalo suportado.", 400)
    data_hora_aparelho, fuso_minutos = _device_datetime(
        payload.get("data_hora_aparelho"), fuso_minutos
    )

    latitude = _optional_decimal(payload.get("latitude"), "latitude", 10, 8)
    longitude = _optional_decimal(payload.get("longitude"), "longitude", 10, 8)
    precisao = _optional_decimal(payload.get("precisao"), "precisao", 13, 2)

    canonical_payload = {
        "codigo": codigo,
        "data_hora_aparelho": (
            data_hora_aparelho.isoformat(timespec="microseconds")
            if data_hora_aparelho
            else None
        ),
        "dispositivo": dispositivo,
        "fuso_minutos": fuso_minutos,
        "latitude": _canonical_decimal(latitude),
        "longitude": _canonical_decimal(longitude),
        "manifesto_guid": manifesto_guid,
        "motorista": motorista_id,
        "parada": parada,
        "pedido": pedido,
        "precisao": _canonical_decimal(precisao),
        "sessao": sessao_id,
    }

    return register_delivery_operation(
        manifesto_guid=manifesto_guid,
        motorista_id=motorista_id,
        sessao_id=sessao_id,
        parada=parada,
        pedido=pedido,
        operacao_guid=operacao_guid,
        payload_versao=PAYLOAD_VERSION,
        payload_hash=_payload_hash(canonical_payload),
        codigo=codigo,
        data_hora_aparelho=data_hora_aparelho,
        fuso_minutos=fuso_minutos,
        latitude=latitude,
        longitude=longitude,
        precisao=precisao,
        dispositivo=dispositivo,
    )
