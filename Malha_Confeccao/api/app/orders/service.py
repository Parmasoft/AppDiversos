import hashlib
import json
from datetime import date, datetime
from decimal import Decimal, InvalidOperation, ROUND_HALF_UP

from app.database import read_connection, write_connection

ORIGIN = "FLUTTER"
MONEY = Decimal("0.0001")
QUANTITY = Decimal("0.000001")


class OrderValidationError(ValueError):
    pass


class OrderConflict(ValueError):
    pass


def _text(value, field, maximum, required=True):
    value = "" if value is None else str(value).strip()
    if required and not value:
        raise OrderValidationError(f"{field} e obrigatorio.")
    if len(value) > maximum:
        raise OrderValidationError(f"{field} excede o limite permitido.")
    return value


def _integer(value, field, required=True):
    if value is None or value == "":
        if required:
            raise OrderValidationError(f"{field} e obrigatorio.")
        return None
    try:
        result = int(str(value))
    except (TypeError, ValueError) as error:
        raise OrderValidationError(f"{field} invalido.") from error
    if result <= 0:
        raise OrderValidationError(f"{field} invalido.")
    return result


def _decimal(value, field, scale, positive=False):
    try:
        result = Decimal(str(value))
    except (InvalidOperation, ValueError, TypeError) as error:
        raise OrderValidationError(f"{field} invalido.") from error
    if not result.is_finite() or result.as_tuple().exponent < -scale:
        raise OrderValidationError(f"{field} possui precisao invalida.")
    if result < 0 or (positive and result <= 0):
        raise OrderValidationError(f"{field} invalido.")
    return result.quantize(Decimal(1).scaleb(-scale))


def _date(value, field):
    try:
        return date.fromisoformat(_text(value, field, 10))
    except ValueError as error:
        raise OrderValidationError(f"{field} invalida.") from error


def _timestamp(value):
    value = _text(value, "created_at", 40)
    try:
        return datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError as error:
        raise OrderValidationError("created_at invalido.") from error


def _canonical_decimal(value):
    return format(value, "f")


def normalize(payload):
    local_id = _text(payload.get("local_id"), "local_id", 100)
    created_at = _timestamp(payload.get("created_at"))
    client = payload.get("cliente")
    if not isinstance(client, dict):
        raise OrderValidationError("cliente e obrigatorio.")
    kind = _text(client.get("tipo"), "cliente.tipo", 12).lower()
    if kind not in ("oficial", "provisorio"):
        raise OrderValidationError("cliente.tipo invalido.")
    official_id = _integer(client.get("id"), "cliente.id", required=False) if kind == "oficial" else None
    provisional = None
    if kind == "oficial" and official_id is None:
        raise OrderValidationError("cliente.id e obrigatorio.")
    if kind == "provisorio":
        source = client.get("provisorio")
        if not isinstance(source, dict):
            raise OrderValidationError("cliente.provisorio e obrigatorio.")
        person_type = _text(source.get("tipo_pessoa"), "cliente.provisorio.tipo_pessoa", 2).upper()
        if person_type not in ("PF", "PJ"):
            raise OrderValidationError("cliente.provisorio.tipo_pessoa invalido.")
        provisional = {
            "local_id": _text(source.get("local_id"), "cliente.provisorio.local_id", 100),
            "person_type": person_type,
            "name": _text(source.get("nome"), "cliente.provisorio.nome", 100),
            "fantasy": _text(source.get("fantasia"), "cliente.provisorio.fantasia", 100, False),
            "document": _text(source.get("cpf_cnpj"), "cliente.provisorio.cpf_cnpj", 14, False),
            "phone": _text(source.get("telefone"), "cliente.provisorio.telefone", 20, False),
            "state_registration": _text(source.get("inscricao_estadual"), "cliente.provisorio.inscricao_estadual", 30, False),
            "email": _text(source.get("email"), "cliente.provisorio.email", 254, False),
            "whatsapp": _text(source.get("whatsapp"), "cliente.provisorio.whatsapp", 20, False),
            "zip_code": _text(source.get("cep"), "cliente.provisorio.cep", 8, False),
            "street": _text(source.get("logradouro"), "cliente.provisorio.logradouro", 150, False),
            "number": _text(source.get("numero"), "cliente.provisorio.numero", 20, False),
            "complement": _text(source.get("complemento"), "cliente.provisorio.complemento", 100, False),
            "neighborhood": _text(source.get("bairro"), "cliente.provisorio.bairro", 100, False),
            "city": _text(source.get("cidade"), "cliente.provisorio.cidade", 100, False),
            "state": _text(source.get("uf"), "cliente.provisorio.uf", 2, False),
        }
    items_raw = payload.get("itens")
    if not isinstance(items_raw, list) or not items_raw or len(items_raw) > 999:
        raise OrderValidationError("itens deve conter entre 1 e 999 registros.")
    items = []
    for position, value in enumerate(items_raw, 1):
        if not isinstance(value, dict):
            raise OrderValidationError("item invalido.")
        quantity = _decimal(value.get("quantidade"), "item.quantidade", 6, True)
        unit_price = _decimal(value.get("valor_unitario"), "item.valor_unitario", 4)
        subtotal = _decimal(value.get("subtotal"), "item.subtotal", 4)
        calculated = (quantity * unit_price).quantize(MONEY, rounding=ROUND_HALF_UP)
        if subtotal != calculated:
            raise OrderValidationError("item.subtotal diverge de quantidade x valor_unitario.")
        items.append({"position": position, "product": _integer(value.get("produto_id"), "item.produto_id"), "description": _text(value.get("descricao"), "item.descricao", 120), "unit": _text(value.get("unidade"), "item.unidade", 6), "quantity": quantity, "unit_price": unit_price, "subtotal": subtotal})
    total = _decimal(payload.get("valor_total"), "valor_total", 4)
    if total != sum((item["subtotal"] for item in items), Decimal("0.0000")):
        raise OrderValidationError("valor_total diverge dos itens.")
    managerial = payload.get("gerencial")
    if not isinstance(managerial, bool):
        raise OrderValidationError("gerencial invalido.")
    result = {"local_id": local_id, "created_at": created_at, "client_kind": kind, "official_id": official_id, "provisional": provisional, "client_name": _text(client.get("nome"), "cliente.nome", 100), "payment": _integer(payload.get("forma_pagamento_id"), "forma_pagamento_id"), "days": _integer(payload.get("prazo_dias"), "prazo_dias"), "delivery": _date(payload.get("previsao_entrega"), "previsao_entrega"), "managerial": managerial, "notes": _text(payload.get("observacoes"), "observacoes", 20000, False), "items": items, "total": total}
    return result


def content_hash(order):
    value = {"origin": ORIGIN, "local_id": order["local_id"], "created_at": order["created_at"].isoformat(), "client_kind": order["client_kind"], "official_id": order["official_id"], "provisional": order["provisional"], "client_name": order["client_name"], "payment": order["payment"], "days": order["days"], "delivery": order["delivery"].isoformat(), "managerial": order["managerial"], "notes": order["notes"], "total": _canonical_decimal(order["total"]), "items": [{**item, "quantity": _canonical_decimal(item["quantity"]), "unit_price": _canonical_decimal(item["unit_price"]), "subtotal": _canonical_decimal(item["subtotal"])} for item in order["items"]]}
    return hashlib.sha256(json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":")).encode("utf-8")).hexdigest()


def _existing(cursor, empresa, local_id):
    cursor.execute("SELECT MPR_ID, MPR_HASH_CONTEUDO, MPR_DT_RECEBIMENTO FROM TB_MALHA_PEDIDO_RECEBIDO WHERE MPR_EMPRESA=? AND MPR_ORIGEM=? AND MPR_ID_LOCAL_PEDIDO=?", (empresa, ORIGIN, local_id))
    return cursor.fetchone()


def _receipt(row, repeated):
    return {"pedido_recebido_id": int(row[0]), "recebido_em": row[2].isoformat() if hasattr(row[2], "isoformat") else str(row[2]), "status": "RECEBIDO"}, repeated


def _require_references(cursor, empresa, vendedor, order):
    cursor.execute("SELECT 1 FROM TB_VENDEDOR WHERE VDR_EMPRESA=? AND VDR_ID=? AND VDR_STATUS='A'", (empresa, vendedor))
    if cursor.fetchone() is None: raise OrderValidationError("Vendedor autenticado nao esta ativo.")
    if order["official_id"]:
        cursor.execute("SELECT 1 FROM TB_CLIENTE WHERE CLI_EMPRESA=? AND CLI_ID=? AND CLI_VENDEDOR=? AND CLI_STATUS='A'", (empresa, order["official_id"], vendedor))
        if cursor.fetchone() is None: raise OrderValidationError("Cliente oficial nao autorizado.")
    cursor.execute("SELECT 1 FROM TB_FORMA_PAGTO WHERE FPG_EMPRESA=? AND FPG_ID=? AND FPG_STATUS='A'", (empresa, order["payment"]))
    if cursor.fetchone() is None: raise OrderValidationError("Forma de pagamento invalida.")
    for item in order["items"]:
        cursor.execute("SELECT 1 FROM TB_PRODUTO WHERE PRD_EMPRESA=? AND PRD_ID=? AND PRD_STATUS<>'I'", (empresa, item["product"]))
        if cursor.fetchone() is None: raise OrderValidationError("Produto invalido.")


def _provisional_id(cursor, empresa, vendedor, client):
    cursor.execute("SELECT MCPR_ID FROM TB_MALHA_CLIENTE_PROV_REC WHERE MCPR_EMPRESA=? AND MCPR_VENDEDOR=? AND MCPR_ORIGEM=? AND MCPR_ID_LOCAL_CLIENTE=?", (empresa, vendedor, ORIGIN, client["local_id"]))
    row = cursor.fetchone()
    if row: return int(row[0])
    cursor.execute("INSERT INTO TB_MALHA_CLIENTE_PROV_REC (MCPR_EMPRESA,MCPR_VENDEDOR,MCPR_ORIGEM,MCPR_ID_LOCAL_CLIENTE,MCPR_TIPO_PESSOA,MCPR_NOME_RAZAO,MCPR_NOME_FANTASIA,MCPR_CPF_CNPJ,MCPR_TELEFONE,MCPR_INSCRICAO_ESTADUAL,MCPR_EMAIL,MCPR_WHATSAPP,MCPR_CEP,MCPR_LOGRADOURO,MCPR_NUMERO,MCPR_COMPLEMENTO,MCPR_BAIRRO,MCPR_CIDADE,MCPR_UF,MCPR_DT_RECEBIMENTO,MCPR_SITUACAO) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,CURRENT_TIMESTAMP,'PENDENTE') RETURNING MCPR_ID", (empresa,vendedor,ORIGIN,client["local_id"],client["person_type"],client["name"],client["fantasy"] or None,client["document"] or None,client["phone"] or None,client["state_registration"] or None,client["email"] or None,client["whatsapp"] or None,client["zip_code"] or None,client["street"] or None,client["number"] or None,client["complement"] or None,client["neighborhood"] or None,client["city"] or None,client["state"] or None))
    return int(cursor.fetchone()[0])


def _is_unique(error):
    return "UNIQUE" in str(error).upper() or "PRIMARY KEY" in str(error).upper()


def receive_order(payload, current_session):
    order = normalize(payload); digest = content_hash(order); empresa = int(current_session["empresa"]); vendedor = int(current_session["vendedor"])
    try:
        with write_connection() as connection:
            cursor = connection.cursor()
            try:
                existing = _existing(cursor, empresa, order["local_id"])
                if existing:
                    if str(existing[1]).strip() != digest: raise OrderConflict()
                    return _receipt(existing, True)
                _require_references(cursor, empresa, vendedor, order)
                provisional_id = _provisional_id(cursor, empresa, vendedor, order["provisional"]) if order["provisional"] else None
                cursor.execute("INSERT INTO TB_MALHA_PEDIDO_RECEBIDO (MPR_EMPRESA,MPR_VENDEDOR,MPR_ORIGEM,MPR_ID_LOCAL_PEDIDO,MPR_HASH_CONTEUDO,MPR_DT_CRIADO_APP,MPR_DT_RECEBIMENTO,MPR_CLIENTE,MPR_CLIENTE_PROVISORIO,MPR_CLIENTE_NOME_SNAPSHOT,MPR_FORMA_PAGTO,MPR_PRAZO_DIAS,MPR_PREVISAO_ENTREGA,MPR_GERENCIAL,MPR_OBSERVACAO,MPR_VALOR_TOTAL,MPR_STATUS) VALUES (?,?,?,?,?,?,CURRENT_TIMESTAMP,?,?,?,?,?,?,?, ?,?,'RECEBIDO') RETURNING MPR_ID,MPR_DT_RECEBIMENTO", (empresa,vendedor,ORIGIN,order["local_id"],digest,order["created_at"],order["official_id"],provisional_id,order["client_name"],order["payment"],order["days"],order["delivery"],'S' if order["managerial"] else 'N',order["notes"] or None,order["total"]))
                inserted = cursor.fetchone(); order_id = int(inserted[0])
                for item in order["items"]:
                    cursor.execute("INSERT INTO TB_MALHA_PEDIDO_RECEBIDO_ITEM (MPRI_EMPRESA,MPRI_PEDIDO,MPRI_SEQUENCIA,MPRI_PRODUTO,MPRI_DESCRICAO_ORIGINAL,MPRI_UNIDADE,MPRI_QUANTIDADE,MPRI_VALOR_UNITARIO,MPRI_SUBTOTAL) VALUES (?,?,?,?,?,?,?,?,?)", (empresa,order_id,item["position"],item["product"],item["description"],item["unit"],item["quantity"],item["unit_price"],item["subtotal"]))
                cursor.execute("INSERT INTO TB_MALHA_PEDIDO_EVENTO (MPE_EMPRESA,MPE_PEDIDO,MPE_DT_EVENTO,MPE_TIPO_EVENTO,MPE_STATUS_POSTERIOR,MPE_DESCRICAO) VALUES (?,?,CURRENT_TIMESTAMP,'RECEBIDO','RECEBIDO','Pedido recebido pelo aplicativo.')", (empresa,order_id))
                return _receipt(inserted, False)
            finally:
                cursor.close()
    except OrderConflict:
        raise
    except Exception as error:
        if not _is_unique(error): raise
    with read_connection() as connection:
        cursor = connection.cursor()
        try:
            existing = _existing(cursor, empresa, order["local_id"])
            if not existing or str(existing[1]).strip() != digest: raise OrderConflict()
            return _receipt(existing, True)
        finally: cursor.close()
