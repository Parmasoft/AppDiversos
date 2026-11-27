"""Durable cloud-to-Firebird delivery return; disabled unless explicitly configured."""
import json
from uuid import UUID


def canonical_uuid(value, field_name):
    """Validate a UUID without changing the persisted return payload."""
    try:
        return str(UUID(str(value)))
    except (TypeError, ValueError, AttributeError) as error:
        raise RuntimeError(f"{field_name} invalido no retorno") from error


class DeliveryReturnSynchronizer:
    def __init__(self, source, client, state, operation_guid=None, allowed_companies=None):
        self.source, self.client, self.state = source, client, state
        self.agent_instance_guid = state.installation_guid()
        self.operation_guid = canonical_uuid(operation_guid, "operation_guid") if operation_guid else None
        self.allowed_companies = None if allowed_companies is None else frozenset(allowed_companies)

    def _validate_claimed_payload(self, payload):
        operation_guid = canonical_uuid(payload.get("operation_guid"), "operation_guid")
        if self.operation_guid and operation_guid != self.operation_guid:
            raise RuntimeError("Claim retornou operacao fora da autorizacao unitária")
        if self.allowed_companies is not None and payload.get("empresa") not in self.allowed_companies:
            raise RuntimeError("Claim retornou empresa fora do escopo autorizado")

    def _is_authorized_pending(self, pending):
        payload = json.loads(pending["payload_json"])
        if self.allowed_companies is not None and payload.get("empresa") not in self.allowed_companies:
            return False
        return not self.operation_guid or canonical_uuid(
            payload.get("operation_guid"), "operation_guid"
        ) == self.operation_guid

    def run_once(self):
        claimed = self.client.claim_delivery_returns(self.agent_instance_guid, self.operation_guid)
        claimed_operations = claimed.get("operacoes", [])
        if self.operation_guid and len(claimed_operations) > 1:
            raise RuntimeError("Claim unitario retornou mais de uma operacao")
        for payload in claimed_operations:
            self._validate_claimed_payload(payload)
            self.state.receive_delivery_return(payload)
        results = []
        for pending in self.state.pending_delivery_returns():
            if not self._is_authorized_pending(pending):
                continue
            payload = json.loads(pending["payload_json"])
            try:
                # Validate canonical UUID form but keep the literal inbox identity for
                # SQLite lookup, ACK payload, hashes, and idempotent replay.
                canonical_uuid(payload.get("operation_guid"), "operation_guid")
                operation_guid = payload["operation_guid"]
                expected_occurrence_guid = payload.get("expected_occurrence_guid")
                if expected_occurrence_guid:
                    expected_occurrence_guid = canonical_uuid(
                        expected_occurrence_guid, "expected_occurrence_guid"
                    )
                result = json.loads(pending["firebird_result_json"]) if pending["state"] == "APPLIED" else self.source.apply(payload)
                if expected_occurrence_guid and canonical_uuid(
                    result.get("ocorrencia_guid"), "occurrence_guid Firebird"
                ) != expected_occurrence_guid:
                    raise RuntimeError("Ocorrencia Firebird diverge da operacao confirmada na nuvem")
                if pending["state"] != "APPLIED":
                    self.state.mark_delivery_applied(operation_guid, result)
                acknowledgement = {
                    "operation_guid": operation_guid,
                    "resultado": result["resultado"], "codigo_resposta": result["codigo_resposta"],
                    "mensagem": result["mensagem"], "ocorrencia_guid": result["ocorrencia_guid"],
                    "replay": bool(result["replay"]),
                }
                self.client.acknowledge_delivery_return(acknowledgement, self.agent_instance_guid)
                self.state.mark_delivery_acked(operation_guid)
                results.append(result)
            except Exception as error:
                self.state.record_delivery_error(payload.get("operation_guid", ""), error)
                raise
        return results
