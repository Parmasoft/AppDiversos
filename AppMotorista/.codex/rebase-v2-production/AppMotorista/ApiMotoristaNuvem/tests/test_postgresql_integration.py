import os
import time
import unittest
import uuid
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime, timedelta, timezone
from threading import Event, Barrier
from unittest.mock import patch

from sqlalchemy import delete, func, select, text, update
from sqlalchemy.exc import IntegrityError

from app import create_app
from app.database import dispose_database, get_engine
from app.provisioning import provision_agent, provision_mobile_session, provision_tenant
from app.tables import (
    load_projection,
    manifest_projection,
    manifest_snapshot_state,
    order_projection,
    snapshot_publisher_lease,
    snapshot_receipt,
    stop_projection,
    delivery_read_operation,
    delivery_confirmation_projection,
    occurrence_projection,
)

from .helpers import clone, occurrence_guid, rehash, snapshot


INSTANCE_A = "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa"
INSTANCE_B = "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb"


class PostgreSQLIntegrationTest(unittest.TestCase):
    """Integration tests that must run against the disposable PostgreSQL database."""

    def setUp(self):
        database_url = os.environ.get("DATABASE_URL", "")
        if not database_url.startswith("postgresql+psycopg://"):
            self.fail("DATABASE_URL PostgreSQL descartavel obrigatoria")

        self.app = create_app(
            {
                "TESTING": True,
                "DATABASE_URL": database_url,
                "TOKEN_HASH_SECRET": "test-secret-with-enough-entropy",
                "SNAPSHOT_LEASE_SECONDS": 60,
            }
        )
        with self.app.app_context():
            engine = get_engine()
            self.assertEqual("postgresql", engine.dialect.name)
            with engine.begin() as connection:
                connection.execute(
                    text(
                        "TRUNCATE TABLE tenant RESTART IDENTITY CASCADE"
                    )
                )
            tenant_a = provision_tenant(
                "GRAMDECOR", "GramDecor", "2026-09-03T00:00:00+00:00"
            )
            tenant_b = provision_tenant(
                "OUTRA", "Outra empresa", "2026-09-03T00:00:00+00:00"
            )
            provision_agent(tenant_a, "AGENT-A", "agent-token-a")
            provision_agent(tenant_b, "AGENT-B", "agent-token-b")
            expiry = datetime.now(timezone.utc) + timedelta(hours=1)
            provision_mobile_session(tenant_a, "MOT-A", "mobile-token-a", expiry, "mobile-refresh-a")
            provision_mobile_session(tenant_b, "MOT-B", "mobile-token-b", expiry, "mobile-refresh-b")
            self.tenant_a = tenant_a
        self.client = self.app.test_client()

    def tearDown(self):
        with self.app.app_context():
            dispose_database()

    @staticmethod
    def auth(token="agent-token-a"):
        return {"Authorization": f"Bearer {token}"}

    def acquire(self, manifesto_guid="MAN-A", instance=INSTANCE_A):
        response = self.client.post(
            f"/api/v1/agente/snapshot-leases/{manifesto_guid}/acquire",
            json={"agent_instance_guid": instance},
            headers=self.auth(),
        )
        self.assertEqual(200, response.status_code, response.get_json())
        return response.get_json()

    def publish_with_client(self, client, body, lease):
        return client.post(
            "/api/v1/agente/snapshots",
            json=body,
            headers={
                **self.auth(),
                "X-Agent-Instance-Guid": lease["agent_instance_guid"],
                "X-Snapshot-Fencing-Token": str(lease["fencing_token"]),
            },
        )

    def publish(self, body, lease):
        return self.publish_with_client(self.client, body, lease)

    def test_commit_native_types_constraints_and_indexes(self):
        lease = self.acquire()
        body = snapshot(revision=1)
        response = self.publish(body, lease)
        self.assertEqual(201, response.status_code, response.get_json())

        with self.app.app_context(), get_engine().connect() as connection:
            native_types = connection.execute(
                text(
                    "SELECT pg_typeof(r.snapshot_id)::text, "
                    "pg_typeof(m.detail_json)::text, pg_typeof(r.received_at)::text, "
                    "m.detail_json->'manifesto'->>'guid' "
                    "FROM snapshot_receipt r "
                    "JOIN manifest_projection m "
                    "ON m.tenant_id = r.tenant_id AND m.manifest_guid = r.manifesto_guid"
                )
            ).one()
            self.assertEqual(
                ("uuid", "jsonb", "timestamp with time zone", "MAN-A"),
                tuple(native_types),
            )
            self.assertEqual(
                1,
                connection.execute(
                    select(func.count()).select_from(snapshot_receipt)
                ).scalar_one(),
            )
            index_names = set(
                connection.execute(
                    text(
                        "SELECT indexname FROM pg_indexes "
                        "WHERE schemaname='public'"
                    )
                ).scalars()
            )
            self.assertTrue(
                {
                    "uq_snapshot_receipt_tenant_snapshot",
                    "uq_snapshot_receipt_tenant_manifest_revision",
                    "ix_manifest_driver",
                    "ix_order_tracking",
                }.issubset(index_names)
            )

        with self.assertRaises(IntegrityError):
            with self.app.app_context(), get_engine().begin() as connection:
                connection.execute(
                    snapshot_publisher_lease.insert().values(
                        tenant_id=self.tenant_a,
                        manifesto_guid="MAN-CONSTRAINT",
                        agent_id=1,
                        agent_instance_guid=str(uuid.uuid4()),
                        fencing_token=0,
                        expires_at=datetime.now(timezone.utc) + timedelta(minutes=1),
                        updated_at=datetime.now(timezone.utc),
                    )
                )

        with self.app.app_context(), get_engine().connect() as connection:
            self.assertEqual(
                0,
                connection.execute(
                    select(func.count())
                    .select_from(snapshot_publisher_lease)
                    .where(snapshot_publisher_lease.c.manifesto_guid == "MAN-CONSTRAINT")
                ).scalar_one(),
            )

    def test_application_failure_rolls_back_everything(self):
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
            for table in (load_projection, snapshot_receipt, manifest_snapshot_state):
                self.assertEqual(
                    0,
                    connection.execute(select(func.count()).select_from(table)).scalar_one(),
                )

    def test_legacy_stop_guid_is_varchar_stable_and_referenced_by_orders(self):
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
        other["manifesto"]["id"] = 13
        other["carga"]["id"] = 901
        other["paradas"][0]["parada"] = 32
        other["paradas"][0]["guid"] = None
        rehash(other)
        self.assertEqual(201, self.publish(other, other_lease).status_code)

        with self.app.app_context(), get_engine().connect() as connection:
            columns = connection.execute(
                text(
                    "SELECT table_name, data_type, character_maximum_length "
                    "FROM information_schema.columns "
                    "WHERE table_schema='public' AND column_name='stop_guid' "
                    "ORDER BY table_name"
                )
            ).all()
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
            order_stop_guid = connection.execute(
                select(order_projection.c.stop_guid).where(
                    order_projection.c.manifest_guid == "MAN-LEGACY-A"
                )
            ).scalar_one()

        self.assertEqual(
            [
                ("order_projection", "character varying", 100),
                ("stop_projection", "character varying", 100),
                ("tracking_event", "character varying", 100),
            ],
            [tuple(column) for column in columns],
        )
        self.assertEqual("PAR-NORMAL", normal_guid)
        self.assertEqual("legacy-stop:v1:1:10:900:31", legacy_guid)
        self.assertEqual(legacy_guid, order_stop_guid)
        self.assertNotEqual(legacy_guid, other_guid)

    def test_replay_is_idempotent_and_conflict_is_preserved(self):
        lease = self.acquire()
        first = snapshot(revision=1)
        created = self.publish(first, lease)
        replay = self.publish(clone(first), lease)
        self.assertEqual(201, created.status_code)
        self.assertEqual(200, replay.status_code)
        self.assertEqual(1, replay.get_json()["replay"])

        conflict = clone(first)
        conflict["snapshot_id"] = str(uuid.uuid4())
        conflict["paradas"][0]["status"] = "E"
        rehash(conflict)
        rejected = self.publish(conflict, lease)
        self.assertEqual(409, rejected.status_code)
        self.assertEqual("SNAPSHOT_REVISION_CONFLITO", rejected.get_json()["codigo"])

        with self.app.app_context(), get_engine().connect() as connection:
            self.assertEqual(
                1,
                connection.execute(
                    select(func.count()).select_from(snapshot_receipt)
                ).scalar_one(),
            )
            state = connection.execute(select(manifest_snapshot_state)).mappings().one()
            self.assertEqual(first["snapshot_id"], state["current_snapshot_id"])

    def test_advisory_transaction_lock_excludes_second_connection(self):
        with self.app.app_context():
            engine = get_engine()
            connection_a = engine.connect()
            connection_b = engine.connect()
            transaction_a = connection_a.begin()
            transaction_b = connection_b.begin()
            try:
                lock_key = 918273645
                connection_a.execute(
                    text("SELECT pg_advisory_xact_lock(:key)"), {"key": lock_key}
                )
                self.assertFalse(
                    connection_b.execute(
                        text("SELECT pg_try_advisory_xact_lock(:key)"),
                        {"key": lock_key},
                    ).scalar_one()
                )
                transaction_a.rollback()
                self.assertTrue(
                    connection_b.execute(
                        text("SELECT pg_try_advisory_xact_lock(:key)"),
                        {"key": lock_key},
                    ).scalar_one()
                )
            finally:
                if transaction_a.is_active:
                    transaction_a.rollback()
                if transaction_b.is_active:
                    transaction_b.rollback()
                connection_a.close()
                connection_b.close()

    def test_concurrent_replay_has_one_commit(self):
        lease = self.acquire()
        body = snapshot(revision=1)
        barrier = Barrier(2)

        def submit():
            with self.app.test_client() as client:
                barrier.wait(timeout=5)
                response = self.publish_with_client(client, clone(body), lease)
                return response.status_code, response.get_json()["replay"]

        with ThreadPoolExecutor(max_workers=2) as executor:
            futures = [executor.submit(submit) for _ in range(2)]
            results = sorted([future.result(timeout=10) for future in futures])

        self.assertEqual([(200, 1), (201, 0)], results)
        with self.app.app_context(), get_engine().connect() as connection:
            self.assertEqual(
                1,
                connection.execute(
                    select(func.count()).select_from(snapshot_receipt)
                ).scalar_one(),
            )

    def test_concurrent_rollback_releases_lock_for_next_writer(self):
        lease = self.acquire()
        failing = snapshot(revision=1)
        succeeding = clone(failing)
        succeeding["snapshot_id"] = str(uuid.uuid4())
        succeeding["paradas"][0]["status"] = "E"
        rehash(succeeding)
        projection_written = Event()
        allow_failure = Event()

        from app import service

        original = service._upsert_projection

        def controlled_projection(connection, tenant_id, payload, received_at):
            original(connection, tenant_id, payload, received_at)
            if payload["snapshot_id"] == failing["snapshot_id"]:
                projection_written.set()
                if not allow_failure.wait(timeout=10):
                    raise RuntimeError("timeout no teste controlado")
                raise RuntimeError("rollback concorrente controlado")

        def submit(body):
            try:
                with self.app.test_client() as client:
                    response = self.publish_with_client(client, body, lease)
                    return response.status_code, response.get_json()
            except RuntimeError as error:
                return "rollback", str(error)

        with patch("app.service._upsert_projection", side_effect=controlled_projection):
            with ThreadPoolExecutor(max_workers=2) as executor:
                first_future = executor.submit(submit, failing)
                self.assertTrue(projection_written.wait(timeout=5))
                second_future = executor.submit(submit, succeeding)
                time.sleep(0.25)
                self.assertFalse(second_future.done())
                allow_failure.set()
                first_result = first_future.result(timeout=10)
                second_result = second_future.result(timeout=10)

        self.assertEqual("rollback", first_result[0])
        self.assertIn("rollback concorrente controlado", first_result[1])
        self.assertEqual(201, second_result[0])
        with self.app.app_context(), get_engine().connect() as connection:
            receipt = connection.execute(select(snapshot_receipt)).mappings().one()
            projection = connection.execute(select(manifest_projection)).mappings().one()
            self.assertEqual(succeeding["snapshot_id"], receipt["snapshot_id"])
            self.assertEqual(succeeding["snapshot_id"], projection["snapshot_id"])

    def test_lease_takeover_and_fencing_reject_old_owner(self):
        lease_a = self.acquire(instance=INSTANCE_A)
        occupied = self.client.post(
            "/api/v1/agente/snapshot-leases/MAN-A/acquire",
            json={"agent_instance_guid": INSTANCE_B},
            headers=self.auth(),
        )
        self.assertEqual(409, occupied.status_code)
        self.assertEqual("SNAPSHOT_LEASE_OCUPADO", occupied.get_json()["codigo"])

        with self.app.app_context(), get_engine().begin() as connection:
            connection.execute(
                update(snapshot_publisher_lease)
                .where(snapshot_publisher_lease.c.manifesto_guid == "MAN-A")
                .values(expires_at=datetime.now(timezone.utc) - timedelta(seconds=1))
            )

        lease_b = self.acquire(instance=INSTANCE_B)
        self.assertGreater(lease_b["fencing_token"], lease_a["fencing_token"])
        rejected = self.publish(snapshot(revision=1), lease_a)
        self.assertEqual(409, rejected.status_code)
        self.assertEqual("SNAPSHOT_FENCING_SUPERADO", rejected.get_json()["codigo"])
        accepted = self.publish(snapshot(revision=1), lease_b)
        self.assertEqual(201, accepted.status_code, accepted.get_json())

    def test_delivery_read_v2_occurrence_scope_v1_replay_and_invalid_guid(self):
        lease = self.acquire()
        body = snapshot()
        selected = "33333333-3333-4333-8333-333333333333".upper()
        body["paradas"][0]["ocorrencias"].append({
            **body["paradas"][0]["ocorrencias"][0], "ocorrencia": 62, "guid": selected,
        })
        body["quantidade_ocorrencias"] = 2
        rehash(body)
        self.assertEqual(201, self.publish(body, lease).status_code)
        path = "/api/v1/motorista/viagens/MAN-A/paradas/31/pedidos/1001/leituras"
        headers = {"Authorization": "Bearer mobile-token-a"}
        payload = {"operacao_guid": "11111111-1111-4111-8111-111111111111", "occurrence_guid": selected.lower(), "codigo": "CONTROLADO", "data_hora_aparelho": "2026-09-07T12:00:00-03:00", "fuso_minutos": -180}
        accepted = self.client.post(path, json=payload, headers=headers)
        self.assertEqual("ACEITA", accepted.get_json()["resultado"])
        self.assertEqual(selected, accepted.get_json()["ocorrencia_guid"])
        self.assertTrue(self.client.post(path, json=payload, headers=headers).get_json()["replay"])
        conflict = self.client.post(path, json={**payload, "codigo": "OUTRO"}, headers=headers)
        self.assertEqual(409, conflict.status_code)
        self.assertEqual("OPERACAO_GUID_CONFLITO", conflict.get_json()["codigo"])
        missing = {key: value for key, value in payload.items() if key != "occurrence_guid"}
        missing["operacao_guid"] = "22222222-2222-4222-8222-222222222222"
        rejected = self.client.post(path, json=missing, headers=headers)
        self.assertEqual("OCORRENCIA_GUID_OBRIGATORIA", rejected.get_json()["codigo"])
        self.assertTrue(self.client.post(path, json=missing, headers=headers).get_json()["replay"])
        invalid = self.client.post(path, json={**payload, "operacao_guid": "44444444-4444-4444-8444-444444444444", "occurrence_guid": "invalido"}, headers=headers)
        self.assertEqual(400, invalid.status_code)
        outside = self.client.post(path, json={**payload, "operacao_guid": "55555555-5555-4555-8555-555555555555", "occurrence_guid": "44444444-4444-4444-8444-444444444444"}, headers=headers)
        self.assertEqual("OCORRENCIA_NAO_ENCONTRADA", outside.get_json()["codigo"])

    def test_delivery_read_refresh_replay_conflict_rollback_and_projections_read_only(self):
        lease = self.acquire()
        self.assertEqual(201, self.publish(snapshot(), lease).status_code)
        path = "/api/v1/motorista/viagens/MAN-A/paradas/31/pedidos/1001/leituras"
        payload = {
            "operacao_guid": "11111111-1111-4111-8111-111111111111",
            "occurrence_guid": occurrence_guid("A"),
            "codigo": "CONTROLADO",
            "data_hora_aparelho": "2026-09-07T12:00:00-03:00",
            "fuso_minutos": -180,
        }
        headers = {"Authorization": "Bearer mobile-token-a"}
        with self.app.app_context(), get_engine().connect() as connection:
            original_status = connection.execute(select(occurrence_projection.c.technical_status)).scalar_one()
        accepted = self.client.post(path, json=payload, headers=headers)
        self.assertEqual(200, accepted.status_code, accepted.get_json())
        self.assertEqual("ACEITA", accepted.get_json()["resultado"])
        replay = self.client.post(path, json=payload, headers=headers)
        self.assertEqual(200, replay.status_code)
        self.assertTrue(replay.get_json()["replay"])
        conflict = self.client.post(path, json={**payload, "codigo": "ALTERADO"}, headers=headers)
        self.assertEqual(409, conflict.status_code)
        self.assertEqual("OPERACAO_GUID_CONFLITO", conflict.get_json()["codigo"])
        forbidden = self.client.post(path, json={**payload, "operacao_guid": "22222222-2222-4222-8222-222222222222"}, headers={"Authorization": "Bearer mobile-token-b"})
        self.assertEqual(404, forbidden.status_code)
        refreshed = self.client.post("/api/v1/motorista/sessoes/renovar", json={"refresh_token": "mobile-refresh-a"})
        self.assertEqual(200, refreshed.status_code, refreshed.get_json())
        self.assertEqual(401, self.client.get("/api/v1/motorista/viagens", headers=headers).status_code)
        with self.app.app_context(), get_engine().connect() as connection:
            self.assertEqual(1, connection.execute(select(func.count()).select_from(delivery_read_operation)).scalar_one())
            self.assertEqual(original_status, connection.execute(select(occurrence_projection.c.technical_status)).scalar_one())

        rollback_payload = {**payload, "operacao_guid": "33333333-3333-4333-8333-333333333333"}
        from app import service
        with patch.object(service.delivery_read_operation, "insert", side_effect=RuntimeError("rollback controlado")):
            with self.assertRaisesRegex(RuntimeError, "rollback controlado"):
                self.client.post(path, json=rollback_payload, headers={"Authorization": f"Bearer {refreshed.get_json()['access_token']}"})
        with self.app.app_context(), get_engine().connect() as connection:
            self.assertEqual(1, connection.execute(select(func.count()).select_from(delivery_read_operation)).scalar_one())


    def test_delivery_confirmation_projection_is_rebuildable_and_refresh_safe(self):
        lease = self.acquire()
        body = snapshot()
        second_guid = occurrence_guid("SECOND").upper()
        body["paradas"][0]["ocorrencias"].append({
            **body["paradas"][0]["ocorrencias"][0], "ocorrencia": 62, "guid": second_guid,
        })
        body["quantidade_ocorrencias"] = 2
        rehash(body)
        self.assertEqual(201, self.publish(body, lease).status_code)
        path = "/api/v1/motorista/viagens/MAN-A/paradas/31/pedidos/1001/leituras"
        headers = {"Authorization": "Bearer mobile-token-a"}
        first = {"operacao_guid": "11111111-1111-4111-8111-111111111111", "occurrence_guid": occurrence_guid("A").upper(), "codigo": "CONTROLADO", "data_hora_aparelho": "2026-09-07T12:00:00-03:00", "fuso_minutos": -180}
        self.assertEqual(("ACEITA", 1), tuple(self.client.post(path, json=first, headers=headers).get_json()[key] for key in ("resultado", "pendentes_pedido")))
        self.assertTrue(self.client.post(path, json=first, headers=headers).get_json()["replay"])
        duplicate = self.client.post(path, json={**first, "operacao_guid": "22222222-2222-4222-8222-222222222222"}, headers=headers)
        self.assertEqual("OCORRENCIA_JA_ENTREGUE", duplicate.get_json()["codigo"])
        second = {**first, "operacao_guid": "33333333-3333-4333-8333-333333333333", "occurrence_guid": second_guid.lower()}
        self.assertEqual(("ACEITA", 0, 0), tuple(self.client.post(path, json=second, headers=headers).get_json()[key] for key in ("resultado", "pendentes_pedido", "pendentes_parada")))
        with self.app.app_context(), get_engine().begin() as connection:
            self.assertEqual(2, connection.execute(select(func.count()).select_from(delivery_confirmation_projection)).scalar_one())
            connection.execute(delete(delivery_confirmation_projection))
            from app.service import rebuild_delivery_confirmation_projection
            rebuild_delivery_confirmation_projection(connection, self.tenant_a, "MAN-A")
            self.assertEqual(2, connection.execute(select(func.count()).select_from(delivery_confirmation_projection)).scalar_one())
        refreshed = clone(body)
        refreshed["snapshot_id"] = str(uuid.uuid4())
        refreshed["snapshot_revision"] = 2
        rehash(refreshed)
        self.assertEqual(201, self.publish(refreshed, lease).status_code)
        trip = self.client.get("/api/v1/motorista/viagens/MAN-A", headers=headers)
        self.assertEqual(200, trip.status_code, trip.get_json())
        stop = trip.get_json()["paradas"][0]
        self.assertEqual(("E", "E"), (stop["status"], stop["pedidos"][0]["status"]))
        self.assertTrue(all(item["status"] == "E" for item in stop["ocorrencias"]))

    def test_concurrent_delivery_reads_have_one_confirmation_and_safe_replay(self):
        lease = self.acquire()
        self.assertEqual(201, self.publish(snapshot(), lease).status_code)
        path = "/api/v1/motorista/viagens/MAN-A/paradas/31/pedidos/1001/leituras"
        barrier = Barrier(2)

        def submit(operation_guid, occurrence):
            with self.app.test_client() as client:
                barrier.wait(timeout=5)
                response = client.post(path, json={
                    "operacao_guid": operation_guid, "occurrence_guid": occurrence,
                    "codigo": "CONTROLADO", "data_hora_aparelho": "2026-09-07T12:00:00-03:00", "fuso_minutos": -180,
                }, headers={"Authorization": "Bearer mobile-token-a"})
                return response.status_code, response.get_json()

        with ThreadPoolExecutor(max_workers=2) as pool:
            results = list(pool.map(lambda item: submit(*item), (
                ("11111111-1111-4111-8111-111111111111", occurrence_guid("A").upper()),
                ("22222222-2222-4222-8222-222222222222", occurrence_guid("A").lower()),
            )))
        self.assertTrue(all(status == 200 for status, _ in results), results)
        self.assertEqual(1, sum(result["resultado"] == "ACEITA" for _, result in results))
        self.assertEqual(1, sum(result["codigo"] == "OCORRENCIA_JA_ENTREGUE" for _, result in results))
        accepted = next(result for _, result in results if result["resultado"] == "ACEITA")
        with self.app.app_context(), get_engine().connect() as connection:
            self.assertEqual(1, connection.execute(select(func.count()).select_from(delivery_confirmation_projection)).scalar_one())
        # Models a lost HTTP response: the original operation replays after its commit.
        replay = self.client.post(path, json={
            "operacao_guid": accepted["operacao"], "occurrence_guid": occurrence_guid("A"),
            "codigo": "CONTROLADO", "data_hora_aparelho": "2026-09-07T12:00:00-03:00", "fuso_minutos": -180,
        }, headers={"Authorization": "Bearer mobile-token-a"})
        self.assertEqual(200, replay.status_code)
        self.assertTrue(replay.get_json()["replay"])
        with self.app.app_context(), get_engine().connect() as connection:
            self.assertEqual(1, connection.execute(select(func.count()).select_from(delivery_confirmation_projection)).scalar_one())

    def test_rebuild_four_fictitious_legacy_acceptances_is_idempotent(self):
        lease = self.acquire()
        body = snapshot()
        template = body["paradas"][0]
        for stop_id, order_id, suffix in ((31, 1001, "B"), (32, 1002, "C"), (33, 1003, "D")):
            stop = clone(template)
            stop["parada"] = stop_id
            stop["pedidos"][0]["pedido"] = order_id
            stop["ocorrencias"][0].update({"ocorrencia": stop_id + 100, "guid": occurrence_guid(suffix).upper(), "pedido": order_id})
            body["paradas"].append(stop)
        body["quantidade_ocorrencias"] = 4
        rehash(body)
        self.assertEqual(201, self.publish(body, lease).status_code)
        with self.app.app_context(), get_engine().begin() as connection:
            now = connection.execute(text("SELECT CURRENT_TIMESTAMP")).scalar_one()
            for index, (stop_id, order_id, guid) in enumerate(((31, 1001, occurrence_guid("A")), (31, 1001, occurrence_guid("B")), (32, 1002, occurrence_guid("C")), (33, 1003, occurrence_guid("D"))), start=1):
                connection.execute(delivery_read_operation.insert().values(
                    tenant_id=self.tenant_a, operation_guid=str(uuid.UUID(int=index)), driver_guid="MOT-A", manifest_guid="MAN-A", stop_id=stop_id, order_id=order_id,
                    request_hash=(f"{index:064x}"), request_json={"operacao_guid": str(uuid.UUID(int=index))},
                    response_json={"resultado": "ACEITA", "ocorrencia_guid": guid}, created_at=now,
                    return_contract_version=1, return_payload_hash=(f"{index:064x}"), return_state="PENDING", return_attempt_count=0,
                ))
            from app.service import rebuild_delivery_confirmation_projection
            rebuild_delivery_confirmation_projection(connection, self.tenant_a, "MAN-A")
            self.assertEqual(4, connection.execute(select(func.count()).select_from(delivery_confirmation_projection)).scalar_one())
            rebuild_delivery_confirmation_projection(connection, self.tenant_a, "MAN-A")
            self.assertEqual(4, connection.execute(select(func.count()).select_from(delivery_confirmation_projection)).scalar_one())
        trip = self.client.get("/api/v1/motorista/viagens/MAN-A", headers={"Authorization": "Bearer mobile-token-a"})
        self.assertEqual(200, trip.status_code, trip.get_json())
        self.assertTrue(all(stop["status"] == "E" for stop in trip.get_json()["paradas"]))
        self.assertTrue(all(order["status"] == "E" for stop in trip.get_json()["paradas"] for order in stop["pedidos"]))


if __name__ == "__main__":
    unittest.main()
