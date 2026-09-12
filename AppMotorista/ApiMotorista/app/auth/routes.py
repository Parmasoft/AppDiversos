from flask import Blueprint, jsonify, request

from app.api_errors import ApiError
from .service import create_session, renew_session


blueprint = Blueprint("motorista_auth", __name__, url_prefix="/api/v1/motorista/sessoes")


@blueprint.errorhandler(ApiError)
def handle_api_error(error):
    return jsonify({"erro": error.message}), error.status_code


@blueprint.post("")
def login():
    payload = request.get_json(silent=True) or {}
    login_value = str(payload.get("login") or "").strip()
    password = str(payload.get("senha") or "")
    dispositivo = str(payload.get("dispositivo") or "").strip() or None

    if not login_value or not password:
        raise ApiError("Login e senha são obrigatórios.", 400)
    if len(login_value) > 80 or len(password) > 1024:
        raise ApiError("Credenciais inválidas.", 400)
    if dispositivo and len(dispositivo) > 100:
        raise ApiError("Identificação do dispositivo é muito longa.", 400)

    result = create_session(login_value, password, dispositivo, request.remote_addr)
    return jsonify(result), 201


@blueprint.post("/renovar")
def renew():
    payload = request.get_json(silent=True) or {}
    refresh_token = str(payload.get("refresh_token") or "").strip()
    if not refresh_token:
        raise ApiError("Token de renovação é obrigatório.", 400)
    return jsonify(renew_session(refresh_token)), 200

