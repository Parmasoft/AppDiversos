import json

import requests


RECOVERABLE_LEASE_CODES = {
    "SNAPSHOT_LEASE_EXPIRADO",
    "SNAPSHOT_FENCING_SUPERADO",
    "SNAPSHOT_LEASE_INVALIDO",
}


class CloudApiError(RuntimeError):
    def __init__(self, status_code, code, message, body=None):
        super().__init__(message)
        self.status_code = status_code
        self.code = code
        self.body = body or {}


class CloudClient:
    def __init__(self, base_url, token, timeout=20, session=None):
        self.base_url = base_url.rstrip("/")
        self.token = token
        self.timeout = timeout
        if session is None:
            session = requests.Session()
            session.trust_env = False
        self.session = session

    def _request(self, method, path, **kwargs):
        headers = {"Authorization": f"Bearer {self.token}", **kwargs.pop("headers", {})}
        response = self.session.request(
            method,
            f"{self.base_url}{path}",
            headers=headers,
            timeout=self.timeout,
            **kwargs,
        )
        try:
            body = response.json()
        except ValueError:
            body = {}
        if not response.ok:
            raise CloudApiError(
                response.status_code,
                body.get("codigo", "HTTP_ERRO"),
                body.get("erro", f"HTTP {response.status_code}"),
                body,
            )
        return body

    def acquire_lease(self, manifesto_guid, agent_instance_guid):
        return self._request(
            "POST",
            f"/api/v1/agente/snapshot-leases/{manifesto_guid}/acquire",
            json={"agent_instance_guid": agent_instance_guid},
        )

    def renew_lease(self, manifesto_guid, agent_instance_guid, fencing_token):
        return self._request(
            "POST",
            f"/api/v1/agente/snapshot-leases/{manifesto_guid}/renew",
            headers={
                "X-Agent-Instance-Guid": agent_instance_guid,
                "X-Snapshot-Fencing-Token": str(fencing_token),
            },
        )

    def publish(self, payload_literal, agent_instance_guid, fencing_token):
        return self._request(
            "POST",
            "/api/v1/agente/snapshots",
            headers={
                "Content-Type": "application/json; charset=utf-8",
                "X-Agent-Instance-Guid": agent_instance_guid,
                "X-Snapshot-Fencing-Token": str(fencing_token),
            },
            data=payload_literal.encode("utf-8"),
        )

    def sync_driver_identities(self, companies, identities):
        return self._request("POST", "/api/v1/agente/motoristas", json={
            "contrato_versao": 1, "empresas": list(companies), "identidades": identities,
        })

    def claim_delivery_returns(self, agent_instance_guid, operation_guid=None):
        payload = {"agent_instance_guid": agent_instance_guid}
        if operation_guid is not None:
            payload["operation_guid"] = operation_guid
        return self._request("POST", "/api/v1/agente/retornos/claim", json=payload)

    def acknowledge_delivery_return(self, result, agent_instance_guid):
        return self._request("POST", "/api/v1/agente/retornos/ack", headers={
            "X-Agent-Instance-Guid": agent_instance_guid,
        }, json=result)


class SnapshotSynchronizer:
    def __init__(self, source, client, state, allowed_scopes):
        self.source = source
        self.client = client
        self.state = state
        self.allowed_scopes = tuple(allowed_scopes)
        self.agent_instance_guid = state.installation_guid()

    def _acquire(self, manifesto_guid):
        lease = self.client.acquire_lease(manifesto_guid, self.agent_instance_guid)
        self.state.sync_lease(lease)
        return lease

    def _publish_pending(self, pending, lease):
        if pending["tenant_key"] != lease["tenant_key"]:
            raise RuntimeError("Tenant do pendente diverge da credencial atual")
        fencing_token = lease["fencing_token"]
        try:
            response = self.client.publish(
                pending["payload_json_literal"], self.agent_instance_guid, fencing_token
            )
            self.state.record_attempt(pending, fencing_token)
        except CloudApiError as error:
            self.state.record_attempt(pending, fencing_token, error)
            if error.code not in RECOVERABLE_LEASE_CODES:
                raise
            lease = self._acquire(pending["manifesto_guid"])
            fencing_token = lease["fencing_token"]
            try:
                response = self.client.publish(
                    pending["payload_json_literal"], self.agent_instance_guid, fencing_token
                )
                self.state.record_attempt(pending, fencing_token)
            except Exception as retry_error:
                self.state.record_attempt(pending, fencing_token, retry_error)
                raise
        except Exception as error:
            self.state.record_attempt(pending, fencing_token, error)
            raise
        self.state.confirm_pending(pending, response, fencing_token)
        return response

    def run_once(self):
        results = []
        if hasattr(self.source, "list_driver_identities"):
            identities = self.source.list_driver_identities(self.allowed_scopes)
            if hasattr(self.client, "sync_driver_identities"):
                companies = sorted({company for company, _load in self.allowed_scopes})
                results.append(self.client.sync_driver_identities(companies, identities))
        released_manifest_guids = tuple(self.source.list_released_manifest_guids(self.allowed_scopes))
        released_manifest_set = set(released_manifest_guids)
        for pending in self.state.list_pending():
            if pending["manifesto_guid"] not in released_manifest_set:
                self.state.discard_pending(pending, "manifesto nao esta mais elegivel")
                results.append({
                    "resultado": "PENDENTE_DESCARTADO_INELEGIVEL",
                    "manifesto_guid": pending["manifesto_guid"],
                })
                continue
            lease = self._acquire(pending["manifesto_guid"])
            results.append(self._publish_pending(pending, lease))

        for manifesto_guid in released_manifest_guids:
            lease = self._acquire(manifesto_guid)
            detail = self.source.read_manifest(manifesto_guid)
            pending = self.state.create_pending(
                lease["tenant_key"],
                manifesto_guid,
                detail,
                lease["current_revision"],
                lease["fencing_token"],
            )
            if pending is None:
                results.append(
                    {
                        "resultado": "SEM_ALTERACAO",
                        "manifesto_guid": manifesto_guid,
                        "current_revision": lease["current_revision"],
                    }
                )
                continue
            results.append(self._publish_pending(pending, lease))
        return results


def payload_from_literal(payload_literal):
    return json.loads(payload_literal)
