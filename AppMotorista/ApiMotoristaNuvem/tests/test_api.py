import tempfile
import unittest
import uuid
from datetime import datetime, timedelta, timezone
from pathlib import Path
from unittest.mock import patch

from sqlalchemy import func, select, update

from app import create_app
from app.database import dispose_database, get_engine, initialize_database
from app.provisioning import (
    provision_agent,
    provision_agent_company_access,
    provision_mobile_session,
    provision_tenant,
)
from app.provisioning import provision_temporary_mobile_session, revoke_mobile_session
from app.tables import (
    load_projection,
    manifest_snapshot_state,
    manifest_projection,
    notification_outbox,
    order_projection,
    snapshot_publisher_lease,
    snapshot_receipt,
    stop_projection,
    tracking_event,
    delivery_read_operation,
    occurrence_projection,
    mobile_session,
)

from .helpers import clone, occurrence_guid, rehash, snapshot


INSTANCE_A = "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa"
INSTANCE_B = "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb"


class CloudApiTest(unittest.TestCase):
    def setUp(self):
        self.temp_dir = tempfile.TemporaryDirectory()
        database_path = Path(self.temp_dir.name) / "test.sqlite3"
        self.app = create_app(
            {
                "TESTING": True,
                "DATABASE_URL": f"sqlite+pysqlite:///{database_path.as_posix()}",
                "TOKEN_HASH_SECRET": "test-secret-with-enough-entropy",
                "SNAPSHOT_LEASE_SECONDS": 60,
            }
        )
        with self.app.app_context():
            initialize_database()
            tenant_a = provision_tenant(
                "GRAMDECOR", "GramDecor", "2026-09-03T00:00:00+00:00"
            )
            tenant_b = provision_tenant(
                "OUTRA", "Outra empresa", "2026-09-03T00:00:00+00:00"
            )
            agent_a = provision_agent(tenant_a, "AGENT-A", "agent-token-a")
            agent_b = provision_agent(tenant_b, "AGENT-B", "agent-token-b")
            provision_agent_company_access(agent_a, 10)
            provision_agent_company_access(agent_b, 10)
            expiry = datetime.now(timezone.utc) + timedelta(hours=1)
            provision_mobile_session(tenant_a, "MOT-A", "mobile-token-a", expiry, "mobile-refresh-a")
            provision_mobile_session(tenant_b, "MOT-B", "mobile-token-b", expiry)
            provision_mobile_session(
                tenant_a,
                "MOT-A",
                "mobile-token-expired",
                datetime.now(timezone.utc) - timedelta(minutes=1),
            )
            self.tenant_a = tenant_a
        self.client = self.app.test_client()

    def tearDown(self):
        with self.app.app_context():
            dispose_database()
        self.temp_dir.cleanup()

    @staticmethod
    def auth(token):
        return {"Authorization": f"Bearer {token}"}

    def acquire(self, manifesto_guid="MAN-A", token="agent-token-a", instance=INSTANCE_A):
        response = self.client.post(
            f"/api/v1/agente/snapshot-leases/{manifesto_guid}/acquire",
            json={"agent_instance_guid": instance},
            headers=self.auth(token),
        )
        self.assertEqual(200, response.status_code, response.get_json())
        return response.get_json()

    def publish(self, body, lease, token="agent-token-a"):
        headers = {
            **self.auth(token),
            "X-Agent-Instance-Guid": lease["agent_instance_guid"],
            "X-Snapshot-Fencing-Token": str(lease["fencing_token"]),
        }
        return self.client.post("/api/v1/agente/snapshots", json=body, headers=headers)

    def test_identity_revision_and_a_b_a(self):
        lease = self.acquire()
        body_a = snapshot(revision=1)
        first = self.publish(body_a, lease)
        self.assertEqual(201, first.status_code)
        self.assertEqual(1, first.get_json()["aplicado"])

        body_b = clone(body_a)
        body_b["snapshot_id"] = str(uuid.uuid4())
        body_b["snapshot_revision"] = 2
        body_b["paradas"][0]["pedidos"][0]["status"] = "E"
        rehash(body_b)
        second = self.publish(body_b, lease)
        self.assertEqual(201, second.status_code)

        body_a_again = clone(body_a)
        body_a_again["snapshot_id"] = str(uuid.uuid4())
        body_a_again["snapshot_revision"] = 3
        rehash(body_a_again)
        third = self.publish(body_a_again, lease)
        self.assertEqual(201, third.status_code)
        self.assertNotEqual(body_a["snapshot_id"], body_a_again["snapshot_id"])
        self.assertEqual(body_a["semantic_hash"], body_a_again["semantic_hash"])
        self.assertEqual(1, third.get_json()["aplicado"])

    def test_revision_policy_replay_conflict_stale_and_same_content_recovery(self):
        lease = self.acquire()
        first = snapshot(revision=1)
        self.assertEqual(201, self.publish(first, lease).status_code)
        replay = self.publish(clone(first), lease)
        self.assertEqual(200, replay.status_code)
        self.assertEqual(1, replay.get_json()["replay"])

        reconciled = clone(first)
        reconciled["snapshot_id"] = str(uuid.uuid4())
        rehash(reconciled)
        reconciliation = self.publish(reconciled, lease)
        self.assertEqual(200, reconciliation.status_code)
        self.assertEqual(first["snapshot_id"], reconciliation.get_json()["snapshot_id"])

        same_revision = clone(first)
        same_revision["snapshot_id"] = str(uuid.uuid4())
        same_revision["paradas"][0]["status"] = "E"
        rehash(same_revision)
        conflict = self.publish(same_revision, lease)
        self.assertEqual(409, conflict.status_code)
        self.assertEqual("SNAPSHOT_REVISION_CONFLITO", conflict.get_json()["codigo"])

        recovery = clone(first)
        recovery["snapshot_id"] = str(uuid.uuid4())
        recovery["snapshot_revision"] = 5
        rehash(recovery)
        recovered = self.publish(recovery, lease)
        self.assertEqual(201, recovered.status_code)
        self.assertEqual(0, recovered.get_json()["aplicado"])
        self.assertEqual("CONTEUDO_JA_CONFIRMADO", recovered.get_json()["motivo"])

        stale = clone(first)
        stale["snapshot_id"] = str(uuid.uuid4())
        stale["snapshot_revision"] = 4
        stale["paradas"][0]["status"] = "E"
        rehash(stale)
        stale_response = self.publish(stale, lease)
        self.assertEqual(201, stale_response.status_code)
        self.assertEqual(0, stale_response.get_json()["aplicado"])
        self.assertEqual("SNAPSHOT_DESATUALIZADO", stale_response.get_json()["motivo"])

    def test_snapshot_id_conflict_and_hash_validation(self):
        lease = self.acquire()
        body = snapshot(revision=1)
        self.assertEqual(201, self.publish(body, lease).status_code)
        changed_identity = clone(body)
        changed_identity["snapshot_revision"] = 2
        response = self.publish(changed_identity, lease)
        self.assertEqual(409, response.status_code)
        self.assertEqual("SNAPSHOT_ID_CONFLITO", response.get_json()["codigo"])

        invalid_hash = snapshot(revision=2)
        invalid_hash["semantic_hash"] = "f" * 64
        response = self.publish(invalid_hash, lease)
        self.assertEqual(400, response.status_code)
        self.assertEqual("SEMANTIC_HASH_INVALIDO", response.get_json()["codigo"])

    def test_projection_failure_rolls_back_receipt_state_and_projection(self):
        lease = self.acquire()
        from app import service

        original = service._upsert_projection

        def fail_after_projection(connection, tenant_id, payload, received_at):
            original(connection, tenant_id, payload, received_at)
            raise RuntimeError("falha controlada depois da projecao")

        with patch("app.service._upsert_projection", side_effect=fail_after_projection):
            with self.assertRaisesRegex(RuntimeError, "falha controlada"):
                self.publish(snapshot(revision=1), lease)

        with self.app.app_context(), get_engine().connect() as connection:
            self.assertEqual(
                0,
                connection.execute(select(func.count()).select_from(load_projection)).scalar_one(),
            )
            self.assertEqual(
                0,
                connection.execute(select(func.count()).select_from(snapshot_receipt)).scalar_one(),
            )
            self.assertEqual(
                0,
                connection.execute(
                    select(func.count()).select_from(manifest_snapshot_state)
                ).scalar_one(),
            )

    def test_stop_projection_uses_stable_legacy_guid_without_changing_normal_guid(self):
        normal_lease = self.acquire("MAN-NORMAL")
        normal = snapshot(suffix="NORMAL")
        normal["manifesto"]["guid"] = "MAN-NORMAL"
        rehash(normal)
        self.assertEqual(201, self.publish(normal, normal_lease).status_code)

        legacy_lease = self.acquire("MAN-LEGACY-A")
        legacy = snapshot(suffix="LEGACY-A")
        legacy["manifesto"]["guid"] = "MAN-LEGACY-A"
        legacy["paradas"][0]["guid"] = None
        rehash(legacy)
        self.assertEqual(201, self.publish(legacy, legacy_lease).status_code)
        self.assertEqual(200, self.publish(clone(legacy), legacy_lease).status_code)

        other_lease = self.acquire("MAN-LEGACY-B")
        other = snapshot(suffix="LEGACY-B")
        other["manifesto"]["guid"] = "MAN-LEGACY-B"
        other["carga"]["id"] = 901
        other["paradas"][0]["parada"] = 32
        other["paradas"][0]["guid"] = None
        rehash(other)
        self.assertEqual(201, self.publish(other, other_lease).status_code)

        with self.app.app_context(), get_engine().connect() as connection:
            normal_guid = connection.execute(
                select(stop_projection.c.stop_guid).where(
                    stop_projection.c.manifest_guid == "MAN-NORMAL"
                )
            ).scalar_one()
            legacy_guid = connection.execute(
                select(stop_projection.c.stop_guid).where(
                    stop_projection.c.manifest_guid == "MAN-LEGACY-A"
                )
            ).scalar_one()
            other_guid = connection.execute(
                select(stop_projection.c.stop_guid).where(
                    stop_projection.c.manifest_guid == "MAN-LEGACY-B"
                )
            ).scalar_one()
            detail = connection.execute(
                select(manifest_projection.c.detail_json).where(
                    manifest_projection.c.manifest_guid == "MAN-LEGACY-A"
                )
            ).scalar_one()

        self.assertEqual("PAR-NORMAL", normal_guid)
        self.assertEqual("legacy-stop:v1:1:10:900:31", legacy_guid)
        self.assertEqual(legacy_guid, detail["paradas"][0]["guid"])
        self.assertNotEqual(legacy_guid, other_guid)

    def test_lease_renewal_takeover_and_old_fencing(self):
        lease = self.acquire()
        renewed = self.client.post(
            "/api/v1/agente/snapshot-leases/MAN-A/renew",
            headers={
                **self.auth("agent-token-a"),
                "X-Agent-Instance-Guid": INSTANCE_A,
                "X-Snapshot-Fencing-Token": str(lease["fencing_token"]),
            },
        )
        self.assertEqual(200, renewed.status_code)
        self.assertEqual(lease["fencing_token"], renewed.get_json()["fencing_token"])

        occupied = self.client.post(
            "/api/v1/agente/snapshot-leases/MAN-A/acquire",
            json={"agent_instance_guid": INSTANCE_B},
            headers=self.auth("agent-token-a"),
        )
        self.assertEqual(409, occupied.status_code)
        self.assertEqual("SNAPSHOT_LEASE_OCUPADO", occupied.get_json()["codigo"])

        with self.app.app_context(), get_engine().begin() as connection:
            connection.execute(
                update(snapshot_publisher_lease).values(
                    expires_at=datetime.now(timezone.utc) - timedelta(seconds=1)
                )
            )
        expired = self.publish(snapshot(revision=1), lease)
        self.assertEqual(409, expired.status_code)
        self.assertEqual("SNAPSHOT_LEASE_EXPIRADO", expired.get_json()["codigo"])

        takeover = self.acquire(instance=INSTANCE_B)
        self.assertGreater(takeover["fencing_token"], lease["fencing_token"])
        rejected = self.publish(snapshot(revision=1), lease)
        self.assertEqual(409, rejected.status_code)
        self.assertEqual("SNAPSHOT_FENCING_SUPERADO", rejected.get_json()["codigo"])
        with self.app.app_context(), get_engine().connect() as connection:
            self.assertEqual(
                0,
                connection.execute(select(func.count()).select_from(snapshot_receipt)).scalar_one(),
            )

    def test_tenant_projection_and_existing_event_guarantees(self):
        lease_a = self.acquire("MAN-A", "agent-token-a", INSTANCE_A)
        lease_b = self.acquire("MAN-B", "agent-token-b", INSTANCE_B)
        self.assertEqual(201, self.publish(snapshot(suffix="A"), lease_a).status_code)
        self.assertEqual(
            201,
            self.publish(snapshot(suffix="B"), lease_b, "agent-token-b").status_code,
        )
        list_a = self.client.get(
            "/api/v1/motorista/viagens", headers=self.auth("mobile-token-a")
        )
        self.assertEqual(["MAN-A"], [item["manifesto_guid"] for item in list_a.get_json()["viagens"]])
        detail = self.client.get(
            "/api/v1/motorista/viagens/MAN-A", headers=self.auth("mobile-token-a")
        ).get_json()
        self.assertNotIn("snapshot_revision", detail)
        self.assertNotIn("semantic_hash", detail)
        forbidden = self.client.get(
            "/api/v1/motorista/viagens/MAN-B", headers=self.auth("mobile-token-a")
        )
        self.assertEqual(404, forbidden.status_code)

        with self.app.app_context(), get_engine().connect() as connection:
            order_statuses = connection.execute(
                select(order_projection.c.tracking_status)
            ).scalars().all()
            self.assertEqual(["PENDENTE", "PENDENTE"], sorted(order_statuses))
            self.assertEqual(0, connection.execute(select(func.count()).select_from(tracking_event)).scalar_one())
            self.assertEqual(0, connection.execute(select(func.count()).select_from(notification_outbox)).scalar_one())
            self.assertEqual(2, connection.execute(select(func.count()).select_from(snapshot_receipt)).scalar_one())

    def test_unknown_and_expired_tokens_are_rejected(self):
        self.assertEqual(
            401,
            self.client.post(
                "/api/v1/agente/snapshot-leases/MAN-A/acquire",
                json={"agent_instance_guid": INSTANCE_A},
                headers=self.auth("invalid"),
            ).status_code,
        )
        expired = self.client.get(
            "/api/v1/motorista/viagens", headers=self.auth("mobile-token-expired")
        )
        self.assertEqual(401, expired.status_code)
        self.assertEqual("SESSAO_EXPIRADA", expired.get_json()["codigo"])

    def test_delivery_read_is_transactional_idempotent_and_session_scoped(self):
        lease = self.acquire()
        self.assertEqual(201, self.publish(snapshot(), lease).status_code)
        operation_guid = "11111111-1111-4111-8111-111111111111"
        path = "/api/v1/motorista/viagens/MAN-A/paradas/31/pedidos/1001/leituras"
        payload = {
            "operacao_guid": operation_guid,
            "occurrence_guid": occurrence_guid("A"),
            "codigo": "CONTROLADO",
            "data_hora_aparelho": "2026-09-07T12:00:00-03:00",
            "fuso_minutos": -180,
        }
        first = self.client.post(path, json=payload, headers=self.auth("mobile-token-a"))
        self.assertEqual(200, first.status_code, first.get_json())
        self.assertEqual("ACEITA", first.get_json()["resultado"])
        replay = self.client.post(path, json=payload, headers=self.auth("mobile-token-a"))
        self.assertEqual(200, replay.status_code)
        self.assertTrue(replay.get_json()["replay"])
        changed = dict(payload)
        changed["codigo"] = "OUTRO"
        conflict = self.client.post(path, json=changed, headers=self.auth("mobile-token-a"))
        self.assertEqual(409, conflict.status_code)
        self.assertEqual("OPERACAO_GUID_CONFLITO", conflict.get_json()["codigo"])
        foreign = self.client.post(path, json={**payload, "operacao_guid": "22222222-2222-4222-8222-222222222222"}, headers=self.auth("mobile-token-b"))
        self.assertEqual(404, foreign.status_code)

        renewed = self.client.post("/api/v1/motorista/sessoes/renovar", json={"refresh_token": "mobile-refresh-a"})
        self.assertEqual(200, renewed.status_code, renewed.get_json())
        self.assertNotEqual("mobile-token-a", renewed.get_json()["access_token"])
        self.assertEqual("mobile-refresh-a", renewed.get_json()["refresh_token"])
        old_access = self.client.get("/api/v1/motorista/viagens", headers=self.auth("mobile-token-a"))
        self.assertEqual(401, old_access.status_code)

        with self.app.app_context(), get_engine().connect() as connection:
            self.assertEqual(1, connection.execute(select(func.count()).select_from(delivery_read_operation)).scalar_one())
            self.assertEqual("P", connection.execute(select(occurrence_projection.c.technical_status)).scalar_one())

    def test_delivery_read_v2_identifies_exact_occurrence_and_rejects_legacy_new_operations(self):
        lease = self.acquire()
        body = snapshot()
        selected_guid = "33333333-3333-4333-8333-333333333333"
        body["paradas"][0]["ocorrencias"].append({
            **body["paradas"][0]["ocorrencias"][0],
            "ocorrencia": 62,
            "guid": selected_guid,
        })
        body["quantidade_ocorrencias"] = 2
        rehash(body)
        self.assertEqual(201, self.publish(body, lease).status_code)
        path = "/api/v1/motorista/viagens/MAN-A/paradas/31/pedidos/1001/leituras"
        payload = {
            "operacao_guid": "11111111-1111-4111-8111-111111111111",
            "occurrence_guid": selected_guid,
            "codigo": "CONTROLADO",
            "data_hora_aparelho": "2026-09-07T12:00:00-03:00",
            "fuso_minutos": -180,
        }

        accepted = self.client.post(path, json=payload, headers=self.auth("mobile-token-a"))
        self.assertEqual(200, accepted.status_code, accepted.get_json())
        self.assertEqual("ACEITA", accepted.get_json()["resultado"])
        self.assertEqual(selected_guid, accepted.get_json()["ocorrencia_guid"])

        replay = self.client.post(path, json=payload, headers=self.auth("mobile-token-a"))
        self.assertEqual(200, replay.status_code)
        self.assertTrue(replay.get_json()["replay"])

        conflict = self.client.post(
            path, json={**payload, "codigo": "ALTERADO"}, headers=self.auth("mobile-token-a")
        )
        self.assertEqual(409, conflict.status_code)
        self.assertEqual("OPERACAO_GUID_CONFLITO", conflict.get_json()["codigo"])

        cases = [
            (
                {**payload, "operacao_guid": "22222222-2222-4222-8222-222222222222", "occurrence_guid": "44444444-4444-4444-8444-444444444444"},
                path,
                "OCORRENCIA_NAO_ENCONTRADA",
            ),
            (
                {**payload, "operacao_guid": "55555555-5555-4555-8555-555555555555"},
                "/api/v1/motorista/viagens/MAN-A/paradas/31/pedidos/9999/leituras",
                "OCORRENCIA_FORA_DO_ESCOPO",
            ),
            (
                {**payload, "operacao_guid": "66666666-6666-4666-8666-666666666666", "codigo": "ALTERADO"},
                path,
                "CODIGO_DIVERGENTE",
            ),
            (
                {
                    "operacao_guid": "77777777-7777-4777-8777-777777777777",
                    "codigo": "CONTROLADO",
                    "data_hora_aparelho": "2026-09-07T12:00:00-03:00",
                    "fuso_minutos": -180,
                },
                path,
                "OCORRENCIA_GUID_OBRIGATORIA",
            ),
        ]
        for request, request_path, code in cases:
            response = self.client.post(
                request_path, json=request, headers=self.auth("mobile-token-a")
            )
            self.assertEqual(200, response.status_code, response.get_json())
            self.assertEqual("RECUSADA", response.get_json()["resultado"])
            self.assertEqual(code, response.get_json()["codigo"])

        legacy_replay = self.client.post(
            path, json=cases[-1][0], headers=self.auth("mobile-token-a")
        )
        self.assertEqual(200, legacy_replay.status_code, legacy_replay.get_json())
        self.assertTrue(legacy_replay.get_json()["replay"])
        self.assertEqual("OCORRENCIA_GUID_OBRIGATORIA", legacy_replay.get_json()["codigo"])

    def test_delivery_return_claim_can_be_limited_to_one_operation_guid(self):
        lease = self.acquire()
        self.assertEqual(201, self.publish(snapshot(), lease).status_code)
        path = "/api/v1/motorista/viagens/MAN-A/paradas/31/pedidos/1001/leituras"
        operation_a = "11111111-1111-4111-8111-111111111111"
        operation_b = "22222222-2222-4222-8222-222222222222"
        payload = {
            "occurrence_guid": occurrence_guid("A"),
            "codigo": "CONTROLADO",
            "data_hora_aparelho": "2026-09-07T12:00:00-03:00",
            "fuso_minutos": -180,
        }
        self.assertEqual(200, self.client.post(
            path, json={**payload, "operacao_guid": operation_a},
            headers=self.auth("mobile-token-a"),
        ).status_code)
        self.assertEqual(200, self.client.post(
            path, json={**payload, "operacao_guid": operation_b},
            headers=self.auth("mobile-token-a"),
        ).status_code)

        filtered = self.client.post(
            "/api/v1/agente/retornos/claim",
            json={"agent_instance_guid": INSTANCE_A, "operation_guid": operation_b},
            headers=self.auth("agent-token-a"),
        )
        self.assertEqual(200, filtered.status_code, filtered.get_json())
        filtered_operations = filtered.get_json()["operacoes"]
        self.assertEqual(1, len(filtered_operations))
        self.assertEqual(operation_b, filtered_operations[0]["operation_guid"])
        self.assertEqual(10, filtered_operations[0]["empresa"])

        normal = self.client.post(
            "/api/v1/agente/retornos/claim",
            json={"agent_instance_guid": INSTANCE_A},
            headers=self.auth("agent-token-a"),
        )
        self.assertEqual(200, normal.status_code, normal.get_json())
        self.assertEqual([operation_a], [value["operation_guid"] for value in normal.get_json()["operacoes"]])

    def test_agent_company_scope_denies_claim_and_ack_outside_persisted_scope(self):
        """Company authorization comes from the server projection, never request JSON."""
        with self.app.app_context():
            agent_other = provision_agent(self.tenant_a, "AGENT-OTHER", "agent-token-other")
            provision_agent_company_access(agent_other, 11)

        allowed_lease = self.acquire("MAN-SCOPE-10")
        allowed_snapshot = snapshot(suffix="SCOPE-10")
        allowed_snapshot["manifesto"]["guid"] = "MAN-SCOPE-10"
        allowed_snapshot["origem"]["empresa"] = 10
        allowed_snapshot["motorista"]["guid"] = "MOT-A"
        rehash(allowed_snapshot)
        self.assertEqual(201, self.publish(allowed_snapshot, allowed_lease).status_code)

        other_lease = self.acquire("MAN-SCOPE-11", token="agent-token-other")
        other_snapshot = snapshot(suffix="SCOPE-11")
        other_snapshot["manifesto"]["guid"] = "MAN-SCOPE-11"
        other_snapshot["origem"]["empresa"] = 11
        other_snapshot["motorista"]["guid"] = "MOT-A"
        rehash(other_snapshot)
        self.assertEqual(
            201,
            self.publish(other_snapshot, other_lease, token="agent-token-other").status_code,
        )

        payload = {
            "occurrence_guid": occurrence_guid("SCOPE-10"),
            "codigo": "CONTROLADO",
            "data_hora_aparelho": "2026-09-07T12:00:00-03:00",
            "fuso_minutos": -180,
        }
        path_10 = "/api/v1/motorista/viagens/MAN-SCOPE-10/paradas/31/pedidos/1001/leituras"
        path_11 = "/api/v1/motorista/viagens/MAN-SCOPE-11/paradas/31/pedidos/1001/leituras"
        operation_10 = "88888888-8888-4888-8888-888888888888"
        operation_11 = "99999999-9999-4999-8999-999999999999"
        self.assertEqual(200, self.client.post(path_10, json={**payload, "operacao_guid": operation_10}, headers=self.auth("mobile-token-a")).status_code)
        self.assertEqual(200, self.client.post(path_11, json={**payload, "occurrence_guid": occurrence_guid("SCOPE-11"), "operacao_guid": operation_11}, headers=self.auth("mobile-token-a")).status_code)

        denied_claim = self.client.post(
            "/api/v1/agente/retornos/claim",
            json={"agent_instance_guid": INSTANCE_A, "operation_guid": operation_11},
            headers=self.auth("agent-token-a"),
        )
        self.assertEqual(200, denied_claim.status_code, denied_claim.get_json())
        self.assertEqual([], denied_claim.get_json()["operacoes"])

        claimed = self.client.post(
            "/api/v1/agente/retornos/claim",
            json={"agent_instance_guid": INSTANCE_B, "operation_guid": operation_11},
            headers=self.auth("agent-token-other"),
        )
        self.assertEqual(200, claimed.status_code, claimed.get_json())
        self.assertEqual([operation_11], [item["operation_guid"] for item in claimed.get_json()["operacoes"]])
        ack = {
            "operation_guid": operation_11,
            "resultado": "ACEITA",
            "codigo_resposta": "ENTREGA_REGISTRADA",
            "mensagem": "teste",
            "ocorrencia_guid": occurrence_guid("SCOPE-11"),
            "replay": False,
        }
        denied_ack = self.client.post(
            "/api/v1/agente/retornos/ack",
            json=ack,
            headers={**self.auth("agent-token-a"), "X-Agent-Instance-Guid": INSTANCE_A},
        )
        self.assertEqual(404, denied_ack.status_code, denied_ack.get_json())

        accepted_ack = self.client.post(
            "/api/v1/agente/retornos/ack",
            json=ack,
            headers={**self.auth("agent-token-other"), "X-Agent-Instance-Guid": INSTANCE_B},
        )
        self.assertEqual(200, accepted_ack.status_code, accepted_ack.get_json())
        self.assertFalse(accepted_ack.get_json()["replay"])

        replay = self.client.post(
            "/api/v1/agente/retornos/ack",
            json=ack,
            headers={**self.auth("agent-token-other"), "X-Agent-Instance-Guid": INSTANCE_B},
        )
        self.assertEqual(200, replay.status_code, replay.get_json())
        self.assertTrue(replay.get_json()["replay"])

    def test_agent_credential_without_company_scope_is_denied_by_default(self):
        with self.app.app_context():
            provision_agent(self.tenant_a, "AGENT-EMPTY", "agent-token-empty")
        lease = self.acquire("MAN-EMPTY", token="agent-token-empty")
        body = snapshot(suffix="EMPTY")
        body["manifesto"]["guid"] = "MAN-EMPTY"
        rehash(body)
        denied_publish = self.publish(body, lease, token="agent-token-empty")
        self.assertEqual(403, denied_publish.status_code, denied_publish.get_json())

        claim = self.client.post(
            "/api/v1/agente/retornos/claim",
            json={"agent_instance_guid": INSTANCE_A},
            headers=self.auth("agent-token-empty"),
        )
        self.assertEqual(403, claim.status_code, claim.get_json())
        self.assertEqual("EMPRESA_NAO_AUTORIZADA", claim.get_json()["codigo"])

    def test_refresh_qr_is_hashed_expiring_revocable_and_tenant_scoped(self):
        with self.app.app_context():
            session_id, access, refresh, expiry = provision_temporary_mobile_session(
                self.tenant_a, "MOT-A", datetime.now(timezone.utc) + timedelta(minutes=5)
            )
            self.assertNotEqual(access, refresh)
            with get_engine().connect() as connection:
                row = connection.execute(select(mobile_session).where(mobile_session.c.id == session_id)).mappings().one()
            self.assertNotEqual(access, row["token_digest"])
            self.assertNotEqual(refresh, row["refresh_token_digest"])
            self.assertEqual(expiry.replace(tzinfo=None), row["expires_at"].replace(tzinfo=None))

        invalid = self.client.post("/api/v1/motorista/sessoes/renovar", json={"refresh_token": "invalido"})
        self.assertEqual(401, invalid.status_code)
        self.assertEqual("SESSAO_INVALIDA", invalid.get_json()["codigo"])
        valid = self.client.post("/api/v1/motorista/sessoes/renovar", json={"refresh_token": refresh})
        self.assertEqual(200, valid.status_code)
        token = valid.get_json()["access_token"]
        self.assertEqual(404, self.client.get("/api/v1/motorista/viagens/MAN-B", headers=self.auth(token)).status_code)
        with self.app.app_context():
            self.assertTrue(revoke_mobile_session(session_id))
        revoked = self.client.post("/api/v1/motorista/sessoes/renovar", json={"refresh_token": refresh})
        self.assertEqual(401, revoked.status_code)
        self.assertEqual("SESSAO_INVALIDA", revoked.get_json()["codigo"])

    def test_delivery_read_rejects_missing_bearer_denied_load_and_rolls_back(self):
        lease = self.acquire("MAN-530")
        body = snapshot(suffix="530")
        body["manifesto"]["guid"] = "MAN-530"
        body["carga"]["id"] = 530
        body["motorista"]["guid"] = "MOT-A"
        rehash(body)
        self.assertEqual(201, self.publish(body, lease).status_code)
        path = "/api/v1/motorista/viagens/MAN-530/paradas/31/pedidos/1001/leituras"
        payload = {"operacao_guid": "33333333-3333-4333-8333-333333333333", "occurrence_guid": occurrence_guid("530"), "codigo": "CONTROLADO", "data_hora_aparelho": "2026-09-07T12:00:00-03:00", "fuso_minutos": -180}
        self.assertEqual(401, self.client.post(path, json=payload).status_code)
        denied = self.client.post(path, json=payload, headers=self.auth("mobile-token-a"))
        self.assertEqual(403, denied.status_code)
        self.assertEqual("CARGA_NAO_AUTORIZADA", denied.get_json()["codigo"])

        lease = self.acquire("MAN-ROLLBACK")
        body = snapshot(suffix="ROLLBACK")
        body["manifesto"]["guid"] = "MAN-ROLLBACK"
        body["motorista"]["guid"] = "MOT-A"
        rehash(body)
        self.assertEqual(201, self.publish(body, lease).status_code)
        rollback_path = "/api/v1/motorista/viagens/MAN-ROLLBACK/paradas/31/pedidos/1001/leituras"
        with patch("app.service.delivery_read_operation.insert", side_effect=RuntimeError("rollback controlado")):
            with self.assertRaisesRegex(RuntimeError, "rollback controlado"):
                self.client.post(rollback_path, json={**payload, "operacao_guid": "44444444-4444-4444-8444-444444444444"}, headers=self.auth("mobile-token-a"))
        with self.app.app_context(), get_engine().connect() as connection:
            self.assertEqual(0, connection.execute(select(func.count()).select_from(delivery_read_operation)).scalar_one())


if __name__ == "__main__":
    unittest.main()
