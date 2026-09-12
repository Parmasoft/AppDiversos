import inspect
import json
import os
import sqlite3
import tempfile
import unittest
from contextlib import closing
from pathlib import Path
from unittest.mock import patch

import fdb

from agent.canonical import CanonicalizationError, canonical_bytes, semantic_hash
from agent.config import Config
from agent.publisher import CloudClient, SnapshotSynchronizer, payload_from_literal
from agent.read_source import FirebirdSnapshotSource, snapshot_read_only_tpb
from agent.state import AgentState


DETAIL = {
    "manifesto": {"id": 12, "guid": "MAN-A", "versao": 1, "status": "L"},
    "carga": {"id": 900, "descricao": "Teste"},
    "motorista": {"guid": "MOT-A", "nome": "Motorista"},
    "origem": {"empresa": 10, "nome_fantasia": "Controlada"},
    "rota": [],
    "paradas": [],
    "quantidade_ocorrencias": 0,
}


class FakeSource:
    def __init__(self, details=None, events=None):
        self.details = {"MAN-A": DETAIL} if details is None else details
        self.events = events if events is not None else []
        self.received_scopes = None

    def list_released_manifest_guids(self, allowed_scopes):
        self.received_scopes = tuple(allowed_scopes)
        return list(self.details)

    def read_manifest(self, manifesto_guid):
        self.events.append(("read", manifesto_guid))
        return self.details[manifesto_guid]


class FakeClient:
    def __init__(self, events=None, fail_publish=False):
        self.events = events if events is not None else []
        self.fail_publish = fail_publish
        self.fencing = 1
        self.current_revision = 0
        self.current_hash = None
        self.current_snapshot_id = None
        self.publications = []

    def acquire_lease(self, manifesto_guid, agent_instance_guid):
        self.events.append(("acquire", manifesto_guid))
        return {
            "resultado": "LEASE_CONCEDIDO",
            "tenant_key": "GRAMDECOR",
            "manifesto_guid": manifesto_guid,
            "agent_instance_guid": agent_instance_guid,
            "fencing_token": self.fencing,
            "current_revision": self.current_revision,
            "current_semantic_hash": self.current_hash,
            "current_snapshot_id": self.current_snapshot_id,
            "expires_at": "2099-01-01T00:00:00+00:00",
        }

    def publish(self, payload_literal, agent_instance_guid, fencing_token):
        self.events.append(("publish", fencing_token))
        self.publications.append(payload_literal)
        if self.fail_publish:
            raise RuntimeError("falha de rede controlada")
        payload = payload_from_literal(payload_literal)
        self.current_revision = payload["snapshot_revision"]
        self.current_hash = payload["semantic_hash"]
        self.current_snapshot_id = payload["snapshot_id"]
        return {
            "resultado": "ACEITA",
            "replay": 0,
            "aplicado": 1,
            "motivo": None,
            "snapshot_id": payload["snapshot_id"],
            "snapshot_revision": payload["snapshot_revision"],
            "current_revision": self.current_revision,
            "current_semantic_hash": self.current_hash,
            "current_snapshot_id": self.current_snapshot_id,
        }


class EmptyCursor:
    def __init__(self):
        self.statements = []

    def execute(self, statement, params):
        self.statements.append((statement.strip(), params))

    def fetchall(self):
        return []


class FakeConnection:
    def __init__(self):
        self.tpbs = []
        self.cursor_value = EmptyCursor()
        self.rolled_back = False
        self.closed = False

    def begin(self, tpb):
        self.tpbs.append(tpb)

    def cursor(self):
        return self.cursor_value

    def rollback(self):
        self.rolled_back = True

    def close(self):
        self.closed = True


class AgentTest(unittest.TestCase):
    def setUp(self):
        self.temp_dir = tempfile.TemporaryDirectory()
        self.state_path = Path(self.temp_dir.name) / "agent_state.sqlite3"
        self.state = AgentState(self.state_path)
        self.state.initialize()

    def tearDown(self):
        self.temp_dir.cleanup()

    @patch("agent.publisher.requests.Session")
    def test_default_cloud_client_ignores_inherited_proxy_and_preserves_injection(self, session_class):
        direct_session = session_class.return_value
        client = CloudClient("https://cloud.example.test", "token")
        self.assertIs(direct_session, client.session)
        self.assertFalse(direct_session.trust_env)

        explicit_session = object()
        injected = CloudClient("https://cloud.example.test", "token", session=explicit_session)
        self.assertIs(explicit_session, injected.session)
        session_class.assert_called_once_with()

    def test_canonicalization_known_vectors_and_number_policy(self):
        vector_path = (
            Path(__file__).resolve().parent.parent
            / "contracts"
            / "v1"
            / "canonicalization-v1-vectors.json"
        )
        vectors = json.loads(vector_path.read_text(encoding="utf-8"))
        for vector in vectors:
            with self.subTest(vector=vector["name"]):
                self.assertEqual(vector["canonical_utf8"].encode(), canonical_bytes(vector["payload"]))
                self.assertEqual(vector["sha256"], semantic_hash(vector["payload"]))
        with self.assertRaises(CanonicalizationError):
            canonical_bytes({"contrato_versao": 1, "valor": 1.5})

    def test_new_publication_is_atomic_random_and_unchanged_content_does_not_publish(self):
        events = []
        source = FakeSource(events=events)
        client = FakeClient(events=events)
        synchronizer = SnapshotSynchronizer(source, client, self.state, ((10, 900),))
        first = synchronizer.run_once()
        self.assertEqual("ACEITA", first[0]["resultado"])
        payload = payload_from_literal(client.publications[0])
        self.assertEqual(4, __import__("uuid").UUID(payload["snapshot_id"]).version)
        self.assertEqual(1, payload["snapshot_revision"])
        self.assertEqual(payload["semantic_hash"], semantic_hash(payload))
        self.assertEqual([("acquire", "MAN-A"), ("read", "MAN-A"), ("publish", 1)], events)
        self.assertEqual([], self.state.list_pending())

        second = synchronizer.run_once()
        self.assertEqual("SEM_ALTERACAO", second[0]["resultado"])
        self.assertEqual(1, len(client.publications))

    def test_local_publication_creation_rolls_back_as_one_unit(self):
        installation_guid = self.state.installation_guid()
        lease_a = FakeClient().acquire_lease("MAN-A", installation_guid)
        self.state.sync_lease(lease_a)
        fixed_uuid = __import__("uuid").UUID("11111111-1111-4111-8111-111111111111")
        with patch("agent.state.uuid.uuid4", return_value=fixed_uuid):
            self.state.create_pending("GRAMDECOR", "MAN-A", DETAIL, 0, 1)

        lease_b = dict(lease_a, manifesto_guid="MAN-B")
        self.state.sync_lease(lease_b)
        detail_b = json.loads(json.dumps(DETAIL))
        detail_b["manifesto"]["guid"] = "MAN-B"
        with patch("agent.state.uuid.uuid4", return_value=fixed_uuid):
            with self.assertRaises(sqlite3.IntegrityError):
                self.state.create_pending("GRAMDECOR", "MAN-B", detail_b, 0, 1)

        with closing(sqlite3.connect(self.state_path)) as connection:
            last_known = connection.execute(
                """SELECT last_known_revision FROM manifest_sync_state
                    WHERE tenant_key = ? AND manifesto_guid = ?""",
                ("GRAMDECOR", "MAN-B"),
            ).fetchone()[0]
            pending_b = connection.execute(
                """SELECT COUNT(*) FROM pending_snapshot
                    WHERE tenant_key = ? AND manifesto_guid = ?""",
                ("GRAMDECOR", "MAN-B"),
            ).fetchone()[0]
        self.assertEqual(0, last_known)
        self.assertEqual(0, pending_b)

    def test_failed_post_survives_restart_with_literal_identity(self):
        source = FakeSource()
        failing = FakeClient(fail_publish=True)
        synchronizer = SnapshotSynchronizer(source, failing, self.state, ((10, 900),))
        with self.assertRaisesRegex(RuntimeError, "falha de rede"):
            synchronizer.run_once()
        pending_before = self.state.list_pending()[0]

        restarted_state = AgentState(self.state_path)
        restarted_state.initialize()
        succeeding = FakeClient()
        empty_source = FakeSource(details={})
        SnapshotSynchronizer(empty_source, succeeding, restarted_state, ((10, 900),)).run_once()
        self.assertEqual(pending_before["payload_json_literal"], succeeding.publications[0])
        self.assertEqual([], restarted_state.list_pending())

    def test_reacquired_fencing_changes_only_attempt_metadata(self):
        installation_guid = self.state.installation_guid()
        first_lease = FakeClient().acquire_lease("MAN-A", installation_guid)
        self.state.sync_lease(first_lease)
        pending = self.state.create_pending("GRAMDECOR", "MAN-A", DETAIL, 0, 1)

        reacquired = FakeClient()
        reacquired.fencing = 2
        SnapshotSynchronizer(
            FakeSource(details={}), reacquired, self.state, ((10, 900),)
        ).run_once()

        self.assertEqual([pending["payload_json_literal"]], reacquired.publications)
        sent = payload_from_literal(reacquired.publications[0])
        self.assertEqual(pending["snapshot_id"], sent["snapshot_id"])
        self.assertEqual(pending["snapshot_revision"], sent["snapshot_revision"])
        self.assertEqual(pending["semantic_hash"], sent["semantic_hash"])
        self.assertEqual([], self.state.list_pending())

    def test_pending_payload_is_temporary_and_database_has_only_technical_tables(self):
        lease = FakeClient().acquire_lease("MAN-A", self.state.installation_guid())
        self.state.sync_lease(lease)
        pending = self.state.create_pending("GRAMDECOR", "MAN-A", DETAIL, 0, 1)
        self.assertIn('"manifesto"', pending["payload_json_literal"])
        with closing(sqlite3.connect(self.state_path)) as connection:
            names = {
                row[0]
                for row in connection.execute(
                    "SELECT name FROM sqlite_master WHERE type = 'table' AND name NOT LIKE 'sqlite_%'"
                )
            }
        self.assertEqual(
            {"agent_installation", "manifest_sync_state", "pending_snapshot"}, names
        )
        response = {
            "current_revision": 1,
            "current_semantic_hash": pending["semantic_hash"],
            "current_snapshot_id": pending["snapshot_id"],
        }
        self.state.confirm_pending(pending, response, 1)
        self.assertEqual([], self.state.list_pending())

        detail_with_secret = json.loads(json.dumps(DETAIL))
        detail_with_secret["token"] = "nao-persistir"
        with self.assertRaisesRegex(ValueError, "segredo nao permitido"):
            self.state.create_pending("GRAMDECOR", "MAN-A", detail_with_secret, 1, 1)
        self.assertEqual([], self.state.list_pending())

    def test_firebird_snapshot_tpb_is_read_only_and_per_manifest(self):
        connection = FakeConnection()
        config = type(
            "ConfigStub",
            (),
            {
                "firebird_host": "localhost",
                "firebird_port": 3050,
                "firebird_database": "controlado.fdb",
                "firebird_user": "readonly",
                "firebird_password": "secret",
                "firebird_charset": "WIN1252",
            },
        )()
        source = FirebirdSnapshotSource(config, connect=lambda **_kwargs: connection)
        source._read_detail = lambda _cursor, _guid: DETAIL
        self.assertEqual(DETAIL, source.read_manifest("MAN-A"))
        self.assertEqual([snapshot_read_only_tpb()], connection.tpbs)
        self.assertEqual(b"\x03\x08\x02\x06", snapshot_read_only_tpb())
        self.assertTrue(connection.rolled_back)
        self.assertTrue(connection.closed)

        source_text = inspect.getsource(FirebirdSnapshotSource).upper()
        for forbidden in ("INSERT INTO", "UPDATE ", "DELETE FROM", "EXECUTE PROCEDURE"):
            self.assertNotIn(forbidden, source_text)

        failing_connection = FakeConnection()
        failing_source = FirebirdSnapshotSource(
            config, connect=lambda **_kwargs: failing_connection
        )
        failing_source._read_detail = lambda _cursor, _guid: (_ for _ in ()).throw(
            RuntimeError("falha controlada de leitura")
        )
        with self.assertRaisesRegex(RuntimeError, "falha controlada"):
            failing_source.read_manifest("MAN-A")
        self.assertTrue(failing_connection.rolled_back)
        self.assertTrue(failing_connection.closed)

    def test_configuration_guards(self):
        environment = {
            "MOTORISTA_CLOUD_URL": "https://cloud.example.test",
            "MOTORISTA_AGENT_TOKEN": "token",
            "MOTORISTA_ALLOWED_SCOPES": "",
            "FIREBIRD_DATABASE": "controlado.fdb",
            "FIREBIRD_USER": "readonly",
            "FIREBIRD_PASSWORD": "secret",
        }
        with patch.dict(os.environ, environment, clear=True):
            with self.assertRaisesRegex(RuntimeError, "publicacao bloqueada"):
                Config.from_environment()
        environment["MOTORISTA_ALLOWED_SCOPES"] = "10:900"
        environment["MOTORISTA_CLOUD_URL"] = "http://cloud.example.test"
        with patch.dict(os.environ, environment, clear=True):
            with self.assertRaisesRegex(RuntimeError, "exige HTTPS"):
                Config.from_environment()


if __name__ == "__main__":
    unittest.main()
