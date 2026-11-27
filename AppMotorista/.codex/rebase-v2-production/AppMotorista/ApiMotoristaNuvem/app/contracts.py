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
_DELIVERY_READ_V1_FIELDS = {"operacao_guid", "codigo", "data_hora_aparelho", "fuso_minutos"}
_DELIVERY_READ_V2_FIELDS = _DELIVERY_READ_V1_FIELDS | {"occurrence_guid"}
_MOBILE_LOGIN_FIELDS = {"login", "senha", "dispositivo"}
_DRIVER_IDENTITY_FIELDS = {
    "empresa", "motorista_id", "motorista_guid", "nome", "login",
    "password_verifier", "motorista_ativo", "vinculo_ativo", "transportador",
}
_DELIVERY_RETURN_ACK_FIELDS = {"operation_guid", "resultado", "codigo_resposta", "mensagem", "ocorrencia_guid", "replay"}
_DELIVERY_RETURN_CLAIM_FIELDS = {"agent_instance_guid", "operation_guid"}


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


def validate_delivery_return_claim(payload):
    _require(payload, {"agent_instance_guid"}, "claim de retorno")
    unexpected = sorted(set(payload) - _DELIVERY_RETURN_CLAIM_FIELDS)
    if unexpected:
        raise ApiError(400, "CONTRATO_INVALIDO", f"claim de retorno contem campos nao permitidos: {', '.join(unexpected)}")
    instance_guid = validate_agent_instance(payload["agent_instance_guid"])
    operation_guid = payload.get("operation_guid")
    if operation_guid is None:
        return instance_guid, None
    try:
        return instance_guid, str(UUID(str(operation_guid)))
    except (TypeError, ValueError):
        raise ApiError(400, "CONTRATO_INVALIDO", "operation_guid invalido")


def validate_agent_instance(value):
    try:
        return str(UUID(str(value)))
    except (TypeError, ValueError):
        raise ApiError(400, "CONTRATO_INVALIDO", "agent_instance_guid invalido")


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
    if not isinstance(payload, dict):
        raise ApiError(400, "CONTRATO_INVALIDO", "delivery_read deve ser um objeto")
    fields = set(payload)
    if fields != _DELIVERY_READ_V1_FIELDS and fields != _DELIVERY_READ_V2_FIELDS:
        raise ApiError(400, "CONTRATO_INVALIDO", "delivery_read contem campos invalidos")
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
    normalized = {
        "operacao_guid": str(operation_guid), "codigo": code,
        "data_hora_aparelho": device_time.isoformat(), "fuso_minutos": timezone_offset,
    }
    if "occurrence_guid" in payload:
        try:
            normalized["occurrence_guid"] = str(UUID(str(payload["occurrence_guid"])))
        except (TypeError, ValueError):
            raise ApiError(400, "CONTRATO_INVALIDO", "occurrence_guid invalido")
    return normalized


def validate_delivery_return_ack(payload):
    _require(payload, _DELIVERY_RETURN_ACK_FIELDS, "delivery_return_ack")
    if set(payload) != _DELIVERY_RETURN_ACK_FIELDS:
        raise ApiError(400, "CONTRATO_INVALIDO", "delivery_return_ack contem campos nao permitidos")
    try:
        operation_guid = str(UUID(str(payload["operation_guid"])))
    except (TypeError, ValueError):
        raise ApiError(400, "CONTRATO_INVALIDO", "operation_guid invalido")
    if payload["resultado"] not in {"ACEITA", "RECUSADA", "CONFLITO"}:
        raise ApiError(400, "CONTRATO_INVALIDO", "resultado invalido")
    if not isinstance(payload["codigo_resposta"], str) or not payload["codigo_resposta"].strip():
        raise ApiError(400, "CONTRATO_INVALIDO", "codigo_resposta invalido")
    return {**payload, "operation_guid": operation_guid}


def normalize_login(value):
    normalized = str(value or "").strip().upper()
    if not normalized or len(normalized) > 80:
        raise ApiError(400, "CONTRATO_INVALIDO", "login invalido")
    return normalized


def validate_mobile_login(payload):
    _require(payload, {"login", "senha"}, "login")
    unexpected = sorted(set(payload) - _MOBILE_LOGIN_FIELDS)
    if unexpected:
        raise ApiError(400, "CONTRATO_INVALIDO", f"login: campos nao permitidos: {', '.join(unexpected)}")
    password = str(payload["senha"] or "")
    device = str(payload.get("dispositivo") or "").strip()
    if not password or len(password) > 1024 or len(device) > 100:
        raise ApiError(400, "CONTRATO_INVALIDO", "credenciais ou dispositivo invalidos")
    return normalize_login(payload["login"]), password, device or None


def validate_driver_identity_sync(payload):
    _require(payload, {"contrato_versao", "empresas", "identidades"}, "identidades")
    if set(payload) != {"contrato_versao", "empresas", "identidades"}:
        raise ApiError(400, "CONTRATO_INVALIDO", "identidades: campos nao permitidos")
    if payload["contrato_versao"] != 1 or not isinstance(payload["identidades"], list) or not isinstance(payload["empresas"], list):
        raise ApiError(400, "CONTRATO_INVALIDO", "contrato de identidades invalido")
    try:
        companies = {int(value) for value in payload["empresas"]}
    except (TypeError, ValueError):
        raise ApiError(400, "CONTRATO_INVALIDO", "empresas invalidas")
    if not companies or any(value <= 0 for value in companies):
        raise ApiError(400, "CONTRATO_INVALIDO", "empresas invalidas")
    result = []
    for index, item in enumerate(payload["identidades"]):
        _require(item, _DRIVER_IDENTITY_FIELDS, f"identidades.{index}")
        if set(item) != _DRIVER_IDENTITY_FIELDS:
            raise ApiError(400, "CONTRATO_INVALIDO", "identidade contem campos nao permitidos")
        try:
            company = int(item["empresa"])
            driver_id = int(item["motorista_id"])
        except (TypeError, ValueError):
            raise ApiError(400, "CONTRATO_INVALIDO", "empresa ou motorista_id invalido")
        guid = str(item["motorista_guid"] or "").strip()
        name = str(item["nome"] or "").strip()
        verifier = str(item["password_verifier"] or "").strip()
        transporter = item["transportador"]
        if transporter is not None:
            try:
                transporter = int(transporter)
            except (TypeError, ValueError):
                raise ApiError(400, "CONTRATO_INVALIDO", "transportador invalido")
        if company <= 0 or driver_id <= 0 or not guid or len(guid) > 100 or not name or not verifier or len(verifier) > 255:
            raise ApiError(400, "CONTRATO_INVALIDO", "identidade invalida")
        result.append({
            "company_id": company, "driver_app_id": driver_id, "driver_guid": guid,
            "driver_name": name, "login_normalized": normalize_login(item["login"]),
            "password_verifier": verifier, "driver_active": bool(item["motorista_ativo"]),
            "access_active": bool(item["vinculo_ativo"]), "transporter_id": transporter,
        })
    if any(item["company_id"] not in companies for item in result):
        raise ApiError(400, "CONTRATO_INVALIDO", "identidade fora do escopo de empresa")
    return {"companies": companies, "identities": result}


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
