from flask import Blueprint, g, jsonify, request

from app.api_errors import ApiError
from app.auth.security import authenticated_motorista
from .delivery import register_delivery
from .service import get_viagem, list_viagens


blueprint = Blueprint("motorista_viagens", __name__, url_prefix="/api/v1/motorista/viagens")


@blueprint.errorhandler(ApiError)
def handle_api_error(error):
    return jsonify({"erro": error.message}), error.status_code


def _reject_identity_filters():
    forbidden = {"motorista", "motorista_id", "empresa"}.intersection(request.args)
    if forbidden:
        raise ApiError("A identidade e as empresas vêm da sessão autenticada.", 400)


@blueprint.get("")
@authenticated_motorista
def viagens():
    _reject_identity_filters()
    return jsonify({"viagens": list_viagens(g.motorista_id)}), 200


@blueprint.get("/<manifesto_guid>")
@authenticated_motorista
def viagem(manifesto_guid):
    _reject_identity_filters()
    return jsonify(get_viagem(g.motorista_id, manifesto_guid)), 200


@blueprint.post(
    "/<manifesto_guid>/paradas/<int:parada>/pedidos/<int:pedido>/leituras"
)
@authenticated_motorista
def registrar_leitura(manifesto_guid, parada, pedido):
    result = register_delivery(
        motorista_id=g.motorista_id,
        sessao_id=g.sessao_id,
        dispositivo=g.dispositivo,
        manifesto_guid=manifesto_guid,
        parada=parada,
        pedido=pedido,
        payload=request.get_json(silent=True),
    )
    status_code = 409 if result["resultado"] == "CONFLITO" else 200
    return jsonify(result), status_code
