from flask import Blueprint, jsonify, request

from .contracts import validate_delivery_read, validate_fencing_headers, validate_lease_acquire, validate_snapshot
from .security import authenticate_agent, authenticate_mobile
from .service import (
    acquire_snapshot_lease,
    get_trip,
    register_delivery_read,
    list_trips,
    renew_mobile_session,
    publish_snapshot,
    renew_snapshot_lease,
)


api = Blueprint("api", __name__, url_prefix="/api/v1")


@api.get("/health")
def health():
    return jsonify({"status": "ok", "servico": "api-motorista-nuvem", "contrato": 1})


@api.post("/agente/snapshots")
def agent_snapshot():
    agent = authenticate_agent(request)
    instance_guid, fencing_token = validate_fencing_headers(request)
    payload = request.get_json(silent=False)
    validate_snapshot(payload)
    response, status = publish_snapshot(agent, payload, instance_guid, fencing_token)
    return jsonify(response), status


@api.post("/agente/snapshot-leases/<manifesto_guid>/acquire")
def agent_snapshot_lease_acquire(manifesto_guid):
    agent = authenticate_agent(request)
    instance_guid = validate_lease_acquire(request.get_json(silent=False))
    return jsonify(acquire_snapshot_lease(agent, manifesto_guid, instance_guid))


@api.post("/agente/snapshot-leases/<manifesto_guid>/renew")
def agent_snapshot_lease_renew(manifesto_guid):
    agent = authenticate_agent(request)
    instance_guid, fencing_token = validate_fencing_headers(request)
    return jsonify(renew_snapshot_lease(agent, manifesto_guid, instance_guid, fencing_token))


@api.get("/motorista/viagens")
def mobile_trips():
    session = authenticate_mobile(request)
    return jsonify({"contrato_versao": 1, "viagens": list_trips(session)})


@api.get("/motorista/viagens/<manifest_guid>")
def mobile_trip(manifest_guid):
    session = authenticate_mobile(request)
    return jsonify(get_trip(session, manifest_guid))


@api.post("/motorista/sessoes/renovar")
def mobile_session_renew():
    payload = request.get_json(silent=False)
    return jsonify(renew_mobile_session(payload))


@api.post("/motorista/viagens/<manifest_guid>/paradas/<int:stop_id>/pedidos/<int:order_id>/leituras")
def mobile_delivery_read(manifest_guid, stop_id, order_id):
    session = authenticate_mobile(request)
    payload = validate_delivery_read(request.get_json(silent=False))
    response, status = register_delivery_read(session, manifest_guid, stop_id, order_id, payload)
    return jsonify(response), status
