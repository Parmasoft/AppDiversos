from datetime import datetime
import re
from uuid import UUID

from .errors import ApiError


_TOP_LEVEL = {
    "contrato_versao", "snapshot_id", "snapshot_revision", "semantic_hash",
    "gerado_em", "manifesto", "carga", "motorista", "origem", "rota",
    "paradas", "quantidade_ocorrencias",
}
_EVENT_FIELDS = {
    "contrato_versao", "tipo", "versao_evento", "ocorrido_em",
    "fonte_autoritativa", "operacao_guid", "carga_guid", "manifesto_guid",
    "parada_guid", "pedido_guid", "cliente",
}
_DELIVERY_READ_FIELDS = {"operacao_guid", "codigo", "data_hora_aparelho", "fuso_minutos"}


def _require(mapping, fields, location):
    if not isinstance(mapping, dict):
        raise ApiError(400, "CONTRATO_INVALIDO", f"{location} deve ser objeto")
    missing = sorted(set(fields) - set(mapping))
    if missing:
        raise ApiError(400, "CONTRATO_INVALIDO", f"{location}: campos ausentes: {', '.join(missing)}")


def validate_snapshot(payload):
    _require(payload, _TOP_LEVEL, "raiz")
    unexpected = sorted(set(payload) - _TOP_LEVEL)
    if unexpected:
        raise ApiError(400, "CONTRATO_INVALIDO", f"raiz: campos nao permitidos: {', '.join(unexpected)}")
    if payload["contrato_versao"] != 1:
        raise ApiError(422, "VERSAO_NAO_SUPORTADA", "Somente contrato_versao 1 e aceito")
    try:
        snapshot_uuid = UUID(str(payload["snapshot_id"]))
        datetime.fromisoformat(str(payload["gerado_em"]))
    except (TypeError, ValueError):
        raise ApiError(400, "CONTRATO_INVALIDO", "snapshot_id ou gerado_em invalido")
    if snapshot_uuid.version != 4:
        raise ApiError(400, "CONTRATO_INVALIDO", "snapshot_id deve ser UUIDv4")
    revision = payload["snapshot_revision"]
    if isinstance(revision, bool) or not isinstance(revision, int) or revision <= 0:
        raise ApiError(400, "CONTRATO_INVALIDO", "snapshot_revision deve ser inteiro positivo")
    if not isinstance(payload["semantic_hash"], str) or not re.fullmatch(
        r"[0-9a-f]{64}", payload["semantic_hash"]
    ):
        raise ApiError(400, "CONTRATO_INVALIDO", "semantic_hash deve ser SHA-256 hexadecimal")
    _require(payload["manifesto"], {"id", "guid", "versao", "status"}, "manifesto")
    _require(payload["carga"], {"id", "descricao"}, "carga")
    _require(payload["motorista"], {"guid", "nome"}, "motorista")
    _require(payload["origem"], {"empresa", "nome_fantasia"}, "origem")
    if not isinstance(payload["paradas"], list):
        raise ApiError(400, "CONTRATO_INVALIDO", "paradas deve ser lista")
    occurrence_count = 0
    for stop_index, stop in enumerate(payload["paradas"]):
        location = f"paradas.{stop_index}"
        _require(stop, {"parada", "guid", "ordem", "status", "cliente", "pedidos", "ocorrencias"}, location)
        _require(stop["cliente"], {"id", "nome"}, f"{location}.cliente")
        if not isinstance(stop["pedidos"], list) or not isinstance(stop["ocorrencias"], list):
            raise ApiError(400, "CONTRATO_INVALIDO", f"{location}: pedidos/ocorrencias devem ser listas")
        for order_index, order in enumerate(stop["pedidos"]):
            _require(order, {"pedido", "status"}, f"{location}.pedidos.{order_index}")
        for occurrence_index, occurrence in enumerate(stop["ocorrencias"]):
            _require(
                occurrence,
                {"ocorrencia", "guid", "pedido", "produto", "tipo", "status", "versao_registro"},
                f"{location}.ocorrencias.{occurrence_index}",
            )
            occurrence_count += 1
    if payload["quantidade_ocorrencias"] != occurrence_count:
        raise ApiError(400, "CONTRATO_INVALIDO", "quantidade_ocorrencias diverge do conteudo")


def validate_lease_acquire(payload):
    _require(payload, {"agent_instance_guid"}, "lease")
    unexpected = sorted(set(payload) - {"agent_instance_guid"})
    if unexpected:
        raise ApiError(400, "CONTRATO_INVALIDO", "lease contem campos nao permitidos")
    try:
        value = UUID(str(payload["agent_instance_guid"]))
    except (TypeError, ValueError):
        raise ApiError(400, "CONTRATO_INVALIDO", "agent_instance_guid invalido")
    return str(value)


def validate_fencing_headers(request):
    instance_guid = request.headers.get("X-Agent-Instance-Guid", "")
    raw_fencing = request.headers.get("X-Snapshot-Fencing-Token", "")
    try:
        instance_guid = str(UUID(instance_guid))
        fencing_token = int(raw_fencing)
    except (TypeError, ValueError):
        raise ApiError(400, "CONTRATO_INVALIDO", "headers de lease/fencing invalidos")
    if fencing_token <= 0:
        raise ApiError(400, "CONTRATO_INVALIDO", "fencing_token deve ser positivo")
    return instance_guid, fencing_token


def validate_delivery_read(payload):
    _require(payload, _DELIVERY_READ_FIELDS, "delivery_read")
    unexpected = sorted(set(payload) - _DELIVERY_READ_FIELDS)
    if unexpected:
        raise ApiError(400, "CONTRATO_INVALIDO", f"delivery_read: campos nao permitidos: {', '.join(unexpected)}")
    try:
        operation_guid = UUID(str(payload["operacao_guid"]))
        device_time = datetime.fromisoformat(str(payload["data_hora_aparelho"]))
        timezone_offset = int(payload["fuso_minutos"])
    except (TypeError, ValueError):
        raise ApiError(400, "CONTRATO_INVALIDO", "delivery_read contem GUID, data ou fuso invalido")
    if operation_guid.version != 4:
        raise ApiError(400, "CONTRATO_INVALIDO", "operacao_guid deve ser UUIDv4")
    code = str(payload["codigo"]).strip().upper()
    if not code or len(code) > 200 or not -840 <= timezone_offset <= 840:
        raise ApiError(400, "CONTRATO_INVALIDO", "codigo ou fuso invalido")
    return {
        "operacao_guid": str(operation_guid), "codigo": code,
        "data_hora_aparelho": device_time.isoformat(), "fuso_minutos": timezone_offset,
    }


def validate_tracking_event(event):
    _require(
        event,
        {"contrato_versao", "tipo", "versao_evento", "ocorrido_em", "fonte_autoritativa", "carga_guid", "manifesto_guid"},
        "evento",
    )
    unexpected = sorted(set(event) - _EVENT_FIELDS)
    if unexpected:
        raise ApiError(400, "CONTRATO_INVALIDO", f"evento: campos nao permitidos: {', '.join(unexpected)}")
    if event["contrato_versao"] != 1:
        raise ApiError(422, "VERSAO_NAO_SUPORTADA", "Somente contrato_versao 1 e aceito")
    try:
        datetime.fromisoformat(str(event["ocorrido_em"]))
    except (TypeError, ValueError):
        raise ApiError(400, "CONTRATO_INVALIDO", "ocorrido_em invalido")
