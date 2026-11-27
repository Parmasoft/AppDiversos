from flask import Blueprint, jsonify, request
from .service import login, logout

blueprint=Blueprint("auth", __name__, url_prefix="/api/v1/sessoes")

@blueprint.post("")
def create_session():
    data=request.get_json(silent=True) or {}
    user=str(data.get("usuario") or "").strip(); password=str(data.get("senha") or "")
    if not user or not password or len(user)>50 or len(password)>20:
        return jsonify({"erro":"Usuario ou senha invalidos."}),401
    try: return jsonify(login(user,password,request.remote_addr)),201
    except ValueError as error: return jsonify({"erro":str(error)}),409
    except PermissionError as error: return jsonify({"erro":str(error)}),401

@blueprint.delete("/atual")
def close_session():
    scheme, _, token=request.headers.get("Authorization","").partition(" ")
    if scheme.lower()!="bearer" or not token.strip(): return jsonify({"erro":"Sessao nao autenticada."}),401
    logout(token.strip()); return "",204
