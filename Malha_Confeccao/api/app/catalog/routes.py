from flask import Blueprint, jsonify, request

from app.auth.service import session
from .service import (
    list_payment_methods_for_empresa,
    list_touch_products_for_empresa,
    search_clients_for_vendedor,
)


blueprint = Blueprint("catalog", __name__, url_prefix="/api/v1/catalogo")


def _current_session():
    scheme, _, token = request.headers.get("Authorization", "").partition(" ")
    if scheme.lower() != "bearer" or not token.strip():
        return None
    return session(token.strip())


def _authorized():
    value = _current_session()
    if value is None:
        return None, (jsonify({"erro": "Sessao nao autenticada ou expirada."}), 401)
    return value, None


@blueprint.get("/clientes")
def clients():
    value, error = _authorized()
    if error:
        return error
    try:
        items = search_clients_for_vendedor(value["empresa"], value["vendedor"], request.args.get("termo"))
    except ValueError as exc:
        return jsonify({"erro": str(exc)}), 400
    return jsonify({"itens": items})


@blueprint.get("/formas-pagamento")
def payment_methods():
    value, error = _authorized()
    if error:
        return error
    return jsonify({"itens": list_payment_methods_for_empresa(value["empresa"])})


@blueprint.get("/produtos-touch")
def touch_products():
    value, error = _authorized()
    if error:
        return error
    return jsonify({"itens": list_touch_products_for_empresa(value["empresa"])})
