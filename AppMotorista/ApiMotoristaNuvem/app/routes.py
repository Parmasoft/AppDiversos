from flask import Blueprint, jsonify, request

from .contracts import validate_agent_instance, validate_delivery_read, validate_delivery_return_ack, validate_delivery_return_claim, validate_driver_identity_sync, validate_fencing_headers, validate_lease_acquire, validate_mobile_login, validate_snapshot
from .security import authenticate_agent, authenticate_mobile
from .service import (
    acquire_snapshot_lease,
    get_trip,
    register_delivery_read,
    list_trips,
    renew_mobile_session,
    publish_snapshot,
    renew_snapshot_lease,
    login_mobile,
    sync_driver_identities,
    claim_delivery_returns,
    acknowledge_delivery_return,
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


@api.post("/agente/motoristas")
def agent_driver_identities():
    agent = authenticate_agent(request)
    projection = validate_driver_identity_sync(request.get_json(silent=False))
    return jsonify(sync_driver_identities(agent, projection))


@api.post("/agente/retornos/claim")
def agent_claim_delivery_returns():
    agent = authenticate_agent(request)
    instance_guid, operation_guid = validate_delivery_return_claim(request.get_json(silent=False))
    return jsonify(claim_delivery_returns(agent, instance_guid, operation_guid=operation_guid))


@api.post("/agente/retornos/ack")
def agent_ack_delivery_return():
    agent = authenticate_agent(request)
    instance_guid = validate_agent_instance(request.headers.get("X-Agent-Instance-Guid", ""))
    result = validate_delivery_return_ack(request.get_json(silent=False))
    return jsonify(acknowledge_delivery_return(agent, instance_guid, result))


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


@api.post("/motorista/sessoes")
def mobile_login():
    login, password, device = validate_mobile_login(request.get_json(silent=False))
    return jsonify(login_mobile(login, password, device)), 201


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
