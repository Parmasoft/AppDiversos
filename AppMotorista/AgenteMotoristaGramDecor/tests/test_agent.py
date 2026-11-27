import inspect
import json
import os
import sqlite3
import tempfile
import unittest
from contextlib import closing
from datetime import datetime
from pathlib import Path
from unittest.mock import patch

import fdb

from agent.canonical import CanonicalizationError, canonical_bytes, semantic_hash
from agent.config import Config, _scopes
from agent.publisher import CloudClient, SnapshotSynchronizer, payload_from_literal
from agent.read_source import FirebirdSnapshotSource, snapshot_read_only_tpb
from agent.return_source import FirebirdDeliveryReturnSource
from agent.return_sync import DeliveryReturnSynchronizer
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

    def test_company_scope_discovers_existing_and_new_released_manifests(self):
        details = {"MAN-A": DETAIL}
        source = FakeSource(details=details)
        client = FakeClient()
        synchronizer = SnapshotSynchronizer(source, client, self.state, ((10, None),))

        first = synchronizer.run_once()
        self.assertEqual("ACEITA", first[0]["resultado"])
        self.assertEqual(1, len(client.publications))

        second = synchronizer.run_once()
        self.assertEqual("SEM_ALTERACAO", second[0]["resultado"])
        self.assertEqual(1, len(client.publications))

        detail_b = json.loads(json.dumps(DETAIL))
        detail_b["manifesto"]["guid"] = "MAN-B"
        detail_b["manifesto"]["id"] = 13
        detail_b["carga"]["id"] = 901
        details["MAN-B"] = detail_b
        third = synchronizer.run_once()
        self.assertEqual("SEM_ALTERACAO", third[0]["resultado"])
        self.assertEqual("ACEITA", third[1]["resultado"])
        self.assertEqual(2, len(client.publications))
        self.assertEqual("MAN-B", payload_from_literal(client.publications[1])["manifesto"]["guid"])

    def test_pending_snapshot_is_discarded_when_manifest_is_no_longer_eligible(self):
        lease = FakeClient().acquire_lease("MAN-A", self.state.installation_guid())
        self.state.sync_lease(lease)
        self.state.create_pending("GRAMDECOR", "MAN-A", DETAIL, 0, 1)
        client = FakeClient()
        result = SnapshotSynchronizer(
            FakeSource(details={}), client, self.state, ((10, 900),)
        ).run_once()
        self.assertEqual("PENDENTE_DESCARTADO_INELEGIVEL", result[0]["resultado"])
        self.assertEqual([], client.publications)
        self.assertEqual([], self.state.list_pending())

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
        still_eligible_source = FakeSource()
        SnapshotSynchronizer(still_eligible_source, succeeding, restarted_state, ((10, 900),)).run_once()
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
            FakeSource(), reacquired, self.state, ((10, 900),)
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
            {
                "agent_installation", "manifest_sync_state", "pending_snapshot",
                "delivery_return_inbox", "company_scope_activation",
                "company_scope_baseline_manifest",
            }, names
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

    def test_allowed_scopes_support_company_and_company_load(self):
        self.assertEqual(((10, 652),), _scopes("10:652"))
        self.assertEqual(((10, None),), _scopes("10"))
        with self.assertRaises(ValueError):
            _scopes("10:")
        with self.assertRaises(ValueError):
            _scopes("10:652:73")

    def test_company_scope_query_omits_load_predicate(self):
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
        self.assertEqual([], source.list_released_manifest_guids(((10, None),)))
        statement, parameters = connection.cursor_value.statements[0]
        self.assertIn("M.CARGM_EMPRESA = ?", statement)
        self.assertNotIn("M.CARGM_CARGA = ?", statement)
        self.assertIn("M.CARGM_DH_LIBERACAO IS NOT NULL", statement)
        self.assertIn("D.MOTAPP_ATIVO = 'S'", statement)
        self.assertEqual((10,), parameters)

        load_connection = FakeConnection()
        load_source = FirebirdSnapshotSource(config, connect=lambda **_kwargs: load_connection)
        self.assertEqual([], load_source.list_released_manifest_guids(((10, 652),)))
        statement, parameters = load_connection.cursor_value.statements[0]
        self.assertIn("M.CARGM_CARGA = ?", statement)
        self.assertEqual((10, 652), parameters)

    def test_snapshot_client_name_uses_reason_social_for_null_empty_or_blank_alias(self):
        source_text = Path(__file__).resolve().parent.parent.joinpath(
            "agent", "read_source.py"
        ).read_text(encoding="utf-8")
        expression = "COALESCE(NULLIF(TRIM(CL.CLI_FANTASIA_APELIDO), ''), CL.CLI_RSOCIAL_NOME)"
        self.assertIn(expression, source_text)
        connection = sqlite3.connect(":memory:")
        for alias, expected in (
            ("Loja Exemplo", "Loja Exemplo"),
            (None, "Razao Social"),
            ("", "Razao Social"),
            ("   ", "Razao Social"),
        ):
            with self.subTest(alias=alias):
                actual = connection.execute(
                    "SELECT COALESCE(NULLIF(TRIM(?), ''), ?)",
                    (alias, "Razao Social"),
                ).fetchone()[0]
                self.assertEqual(expected, actual)
        connection.close()

    def test_delivery_return_source_uses_the_fifteen_parameter_contract(self):
        class ReturnCursor:
            def __init__(self):
                self.statement = None
                self.parameters = None

            def execute(self, statement, parameters):
                self.statement = statement
                self.parameters = parameters

            def fetchone(self):
                return ("ACEITA", "ENTREGA_REGISTRADA", "ok", "OP", "OCC", "C", 1001, 0, 0, 0)

        class ReturnConnection:
            def __init__(self):
                self.cursor_value = ReturnCursor()
                self.committed = False
                self.closed = False

            def cursor(self):
                return self.cursor_value

            def commit(self):
                self.committed = True

            def rollback(self):
                pass

            def close(self):
                self.closed = True

        connection = ReturnConnection()
        config = type("ConfigStub", (), {
            "firebird_host": "localhost", "firebird_port": 3050,
            "firebird_database": "controlado.fdb", "firebird_user": "user",
            "firebird_password": "secret", "firebird_charset": "WIN1252",
        })()
        payload = {
            "empresa": 10, "manifest_guid": "MAN-A", "stop_id": 31, "order_id": 1001,
            "expected_occurrence_guid": "OCC", "operation_guid": "OP",
            "contrato_versao": 1, "payload_hash": "a" * 64, "codigo": "CONTROLADO",
            "data_hora_aparelho": "2026-09-07T12:00:00-03:00", "fuso_minutos": -180,
            "latitude": None, "longitude": None, "precisao": None, "dispositivo": None,
        }
        result = FirebirdDeliveryReturnSource(config, connect=lambda **_kwargs: connection).apply(payload)
        self.assertEqual(15, connection.cursor_value.statement.count("?"))
        self.assertEqual(
            (10, "MAN-A", 31, 1001, "OCC", "OP", 1, "a" * 64, "CONTROLADO",
             datetime.fromisoformat("2026-09-07T12:00:00-03:00"), -180, None, None, None, None),
            connection.cursor_value.parameters,
        )
        self.assertEqual("ACEITA", result["resultado"])
        self.assertTrue(connection.committed)
        self.assertTrue(connection.closed)

    def test_delivery_return_synchronizer_forwards_optional_operation_guid(self):
        class ClaimOnlyClient:
            def __init__(self):
                self.arguments = None

            def claim_delivery_returns(self, instance_guid, operation_guid=None):
                self.arguments = (instance_guid, operation_guid)
                return {"operacoes": []}

        client = ClaimOnlyClient()
        operation_guid = "e5c2b0b3-7ae4-4eb4-99e2-eeac5e7bf544"
        DeliveryReturnSynchronizer(None, client, self.state, operation_guid).run_once()
        self.assertEqual((self.state.installation_guid(), operation_guid), client.arguments)


if __name__ == "__main__":
    unittest.main()
