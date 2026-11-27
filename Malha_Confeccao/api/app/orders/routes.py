from flask import Blueprint, jsonify, request

from app.auth.service import session
from .service import OrderConflict, OrderValidationError, receive_order

blueprint = Blueprint("malha_orders", __name__, url_prefix="/api/v1/pedidos-malhas")


def _session():
    scheme, _, token = request.headers.get("Authorization", "").partition(" ")
    return session(token.strip()) if scheme.lower() == "bearer" and token.strip() else None


@blueprint.post("/recepcao")
def receive():
    current = _session()
    if current is None:
        return jsonify({"erro": "Sessao nao autenticada ou expirada."}), 401
    body = request.get_json(silent=True)
    if not isinstance(body, dict):
        return jsonify({"erro": "Corpo JSON invalido."}), 400
    try:
        receipt, repeated = receive_order(body, current)
        return jsonify({"recibo": receipt, "reenvio": repeated}), 200 if repeated else 201
    except OrderValidationError as error:
        return jsonify({"erro": str(error)}), 400
    except OrderConflict:
        return jsonify({"erro": "Identificador local ja recebido com conteudo diferente."}), 409
