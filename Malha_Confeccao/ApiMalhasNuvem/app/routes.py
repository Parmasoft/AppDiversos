from flask import Blueprint, jsonify, request
from .service import acknowledge_order, authenticate, catalog_clients, catalog_payments, catalog_products, claim_order, companies, get_order, list_orders, login, receive, renew, receive_catalog_snapshot, receive_sellers_snapshot

api=Blueprint("api",__name__,url_prefix="/api/v1")
@api.get("/health")
def health(): return jsonify({"status":"ok","servico":"api-malhas-nuvem","contrato":1})
@api.post("/sessoes")
def create_session(): return jsonify(login(request.get_json(silent=True))),201
@api.post("/sessoes/renovar")
def refresh_session(): return jsonify(renew(request.get_json(silent=True)))
@api.get("/empresas")
def list_companies(): return jsonify({"empresas":companies(authenticate(request))})
@api.get("/catalogo/clientes")
def catalog_clients_route(): return jsonify({"itens":catalog_clients(authenticate(request),request.args.get("termo", ""))})
@api.get("/catalogo/produtos")
def catalog_products_route(): return jsonify({"itens":catalog_products(authenticate(request))})
@api.get("/catalogo/formas-pagamento")
def catalog_payments_route(): return jsonify({"itens":catalog_payments(authenticate(request))})
@api.post("/pedidos")
def create_order():
    result,repeated=receive(request.get_json(silent=True),authenticate(request)); return jsonify(result),200 if repeated else 201
@api.get("/pedidos")
def orders(): return jsonify({"pedidos":list_orders(authenticate(request))})
@api.get("/pedidos/<cloud_id>")
def order_detail(cloud_id): return jsonify(get_order(authenticate(request),cloud_id))
@api.post("/agente/vendedores/snapshot")
def sellers_snapshot(): return jsonify(receive_sellers_snapshot(request.get_json(silent=True),request))
@api.post("/agente/catalogo/snapshots")
def catalog_snapshot(): return jsonify(receive_catalog_snapshot(request.get_json(silent=True),request))
@api.post("/agente/pedidos/claim")
def claim(): return jsonify(claim_order(request))
@api.post("/agente/pedidos/<cloud_id>/ack")
def ack(cloud_id): return jsonify(acknowledge_order(cloud_id,request.get_json(silent=True),request))
