import tempfile
import unittest
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import patch

import main as agent_main
from agent.return_sync import DeliveryReturnSynchronizer, canonical_uuid
from agent.state import AgentState


OPERATION = "11111111-1111-4111-8111-111111111111"
OCCURRENCE = "22222222-2222-4222-8222-222222222222"


def payload(**changes):
    value = {
        "empresa": 10,
        "operation_guid": OPERATION,
        "expected_occurrence_guid": OCCURRENCE,
        "manifest_guid": "MAN-A",
        "stop_id": 31,
        "order_id": 1001,
        "contrato_versao": 1,
        "payload_hash": "a" * 64,
        "codigo": "CONTROLE",
        "data_hora_aparelho": "2026-11-25T10:00:00-03:00",
        "fuso_minutos": -180,
    }
    value.update(changes)
    return value


class FakeReturnClient:
    def __init__(self, claims=(), fail_ack_times=0):
        self.claims = list(claims)
        self.fail_ack_times = fail_ack_times
        self.claim_calls = []
        self.acks = []

    def claim_delivery_returns(self, instance_guid, operation_guid=None):
        self.claim_calls.append((instance_guid, operation_guid))
        claimed, self.claims = self.claims, []
        return {"operacoes": claimed}

    def acknowledge_delivery_return(self, acknowledgement, instance_guid):
        self.acks.append((acknowledgement, instance_guid))
        if self.fail_ack_times:
            self.fail_ack_times -= 1
            raise RuntimeError("falha controlada antes do ACK")
        return {"resultado": "APPLIED"}


class FakeFirebirdSource:
    def __init__(self, occurrence_guid=OCCURRENCE.upper(), fail_before_commit_times=0, result="ACEITA"):
        self.occurrence_guid = occurrence_guid
        self.fail_before_commit_times = fail_before_commit_times
        self.result = result
        self.apply_calls = 0
        self.committed_operations = set()

    def apply(self, item):
        self.apply_calls += 1
        if self.fail_before_commit_times:
            self.fail_before_commit_times -= 1
            raise RuntimeError("falha controlada antes do commit Firebird")
        self.committed_operations.add(item["operation_guid"])
        return {
            "resultado": self.result,
            "codigo_resposta": "ENTREGA_REGISTRADA" if self.result == "ACEITA" else "OPERACAO_GUID_CONFLITO",
            "mensagem": "resultado controlado",
            "ocorrencia_guid": self.occurrence_guid,
            "replay": self.apply_calls > 1,
        }


class ReturnSynchronizerTest(unittest.TestCase):
    def setUp(self):
        self.temp_dir = tempfile.TemporaryDirectory()
        self.state = AgentState(Path(self.temp_dir.name) / "return.sqlite3")
        self.state.initialize()

    def tearDown(self):
        self.temp_dir.cleanup()

    def sync(self, source, client):
        return DeliveryReturnSynchronizer(source, client, self.state).run_once()

    def sync_unitary(self, source, client):
        return DeliveryReturnSynchronizer(
            source, client, self.state, OPERATION, allowed_companies={10}
        ).run_once()

    def inbox(self):
        return self.state.pending_delivery_returns()

    def test_canonical_uuid_accepts_case_but_rejects_invalid(self):
        self.assertEqual(OCCURRENCE, canonical_uuid(OCCURRENCE.upper(), "occurrence"))
        with self.assertRaisesRegex(RuntimeError, "invalido"):
            canonical_uuid("nao-e-uuid", "occurrence")

    def test_uppercase_firebird_guid_is_accepted_without_mutating_payload_or_hash(self):
        item = payload(expected_occurrence_guid=OCCURRENCE.upper())
        source = FakeFirebirdSource(occurrence_guid=OCCURRENCE.lower())
        client = FakeReturnClient([item])
        self.sync(source, client)
        self.assertEqual(1, source.apply_calls)
        self.assertEqual(1, len(client.acks))
        self.assertEqual(OPERATION, client.acks[0][0]["operation_guid"])
        self.assertEqual([], self.inbox())

    def test_operation_guid_literal_is_preserved_after_validation(self):
        item = payload(operation_guid=OPERATION.upper())
        source = FakeFirebirdSource()
        client = FakeReturnClient([item])
        self.sync(source, client)
        self.assertEqual(OPERATION.upper(), client.acks[0][0]["operation_guid"])
        self.assertIn(OPERATION.upper(), source.committed_operations)
        self.assertEqual([], self.inbox())

    def test_unitary_mode_refuses_wrong_operation_company_or_multiple_claims(self):
        source = FakeFirebirdSource()
        wrong_operation = payload(operation_guid="33333333-3333-4333-8333-333333333333")
        with self.assertRaisesRegex(RuntimeError, "fora da autorizacao"):
            self.sync_unitary(source, FakeReturnClient([wrong_operation]))
        self.assertEqual(0, source.apply_calls)

        wrong_company = payload(empresa=11)
        with self.assertRaisesRegex(RuntimeError, "empresa fora"):
            self.sync_unitary(source, FakeReturnClient([wrong_company]))
        self.assertEqual(0, source.apply_calls)

        self.state = AgentState(Path(self.temp_dir.name) / "multiple.sqlite3")
        self.state.initialize()
        with self.assertRaisesRegex(RuntimeError, "mais de uma"):
            self.sync_unitary(source, FakeReturnClient([payload(), payload()]))
        self.assertEqual(0, source.apply_calls)

    def test_unitary_mode_processes_only_the_authorized_pending_operation(self):
        other = payload(operation_guid="33333333-3333-4333-8333-333333333333")
        self.state.receive_delivery_return(other)
        source = FakeFirebirdSource()
        client = FakeReturnClient([payload()])
        self.sync_unitary(source, client)
        self.assertEqual({OPERATION}, source.committed_operations)
        self.assertEqual(1, len(client.acks))
        self.assertEqual(other["operation_guid"], self.inbox()[0]["operation_guid"])

    def test_company_scoped_return_never_applies_out_of_scope_sqlite_pending(self):
        other_company = payload(empresa=11)
        self.state.receive_delivery_return(other_company)
        source = FakeFirebirdSource()
        client = FakeReturnClient()
        DeliveryReturnSynchronizer(
            source, client, self.state, allowed_companies={10}
        ).run_once()
        self.assertEqual(0, source.apply_calls)
        self.assertEqual([], client.acks)
        self.assertEqual(other_company["operation_guid"], self.inbox()[0]["operation_guid"])

    def test_return_only_runner_never_constructs_snapshot_synchronizer(self):
        config = SimpleNamespace(delivery_return_enabled=True, allowed_scopes=((10, None),))
        client, state = object(), object()
        captured = {}
        class SyncStub:
            def __init__(self, source, received_client, received_state, operation_guid, allowed_companies):
                captured.update(source=source, client=received_client, state=received_state,
                                operation_guid=operation_guid, allowed_companies=allowed_companies)
            def run_once(self):
                return [{"resultado": "CONTROLADO"}]
        with patch.object(agent_main, "FirebirdDeliveryReturnSource", return_value="return-source"), \
             patch.object(agent_main, "DeliveryReturnSynchronizer", SyncStub), \
             patch.object(agent_main, "SnapshotSynchronizer", side_effect=AssertionError("nao publicar")):
            result = agent_main.run_return_only(config, client, state, OPERATION)
        self.assertEqual([{"resultado": "CONTROLADO"}], result)
        self.assertEqual("return-source", captured["source"])
        self.assertEqual(frozenset({10}), captured["allowed_companies"])

    def test_return_only_runner_requires_explicit_enablement_and_company(self):
        with self.assertRaisesRegex(RuntimeError, "explicitamente habilitado"):
            agent_main.run_return_only(SimpleNamespace(delivery_return_enabled=False, allowed_scopes=((10, None),)), None, None, OPERATION)
        with self.assertRaisesRegex(RuntimeError, "empresa autorizada"):
            agent_main.run_return_only(SimpleNamespace(delivery_return_enabled=True, allowed_scopes=()), None, None, OPERATION)

    def test_automatic_round_runs_return_when_publication_fails(self):
        config = SimpleNamespace(
            delivery_return_enabled=True,
            delivery_return_operation_guid=None,
            allowed_scopes=((10, None),),
        )
        captured = {}

        class FailingPublication:
            def __init__(self, *_args):
                pass

            def run_once(self):
                raise RuntimeError("falha de publicacao controlada")

        class ReturnStub:
            def __init__(self, source, _client, _state, operation_guid, allowed_companies):
                captured.update(source=source, operation_guid=operation_guid,
                                allowed_companies=allowed_companies)

            def run_once(self):
                return [{"resultado": "RETORNO_PROCESSADO"}]

        with patch.object(agent_main, "FirebirdSnapshotSource", return_value="snapshot-source"), \
             patch.object(agent_main, "SnapshotSynchronizer", FailingPublication), \
             patch.object(agent_main, "FirebirdDeliveryReturnSource", return_value="return-source"), \
             patch.object(agent_main, "DeliveryReturnSynchronizer", ReturnStub):
            result = agent_main.run_automatic(config, object(), object())

        self.assertEqual([{"resultado": "RETORNO_PROCESSADO"}], result["retornos"])
        self.assertEqual([{"fluxo": "publicacao", "erro": "falha de publicacao controlada"}], result["erros"])
        self.assertEqual("return-source", captured["source"])
        self.assertIsNone(captured["operation_guid"])
        self.assertEqual({10}, captured["allowed_companies"])

    def test_automatic_round_preserves_publication_when_return_fails(self):
        config = SimpleNamespace(
            delivery_return_enabled=True,
            delivery_return_operation_guid=None,
            allowed_scopes=((10, None),),
        )

        class PublicationStub:
            def __init__(self, *_args):
                pass

            def run_once(self):
                return [{"resultado": "SNAPSHOT_ACEITO"}]

        class FailingReturn:
            def __init__(self, *_args, **_kwargs):
                pass

            def run_once(self):
                raise RuntimeError("falha de retorno controlada")

        with patch.object(agent_main, "FirebirdSnapshotSource", return_value="snapshot-source"), \
             patch.object(agent_main, "SnapshotSynchronizer", PublicationStub), \
             patch.object(agent_main, "FirebirdDeliveryReturnSource", return_value="return-source"), \
             patch.object(agent_main, "DeliveryReturnSynchronizer", FailingReturn):
            result = agent_main.run_automatic(config, object(), object())

        self.assertEqual([{"resultado": "SNAPSHOT_ACEITO"}], result["publicacoes"])
        self.assertEqual([{"fluxo": "retorno", "erro": "falha de retorno controlada"}], result["erros"])

    def test_invalid_or_divergent_occurrence_never_acknowledges(self):
        client = FakeReturnClient([payload(expected_occurrence_guid="invalido")])
        with self.assertRaisesRegex(RuntimeError, "expected_occurrence_guid invalido"):
            self.sync(FakeFirebirdSource(), client)
        self.assertEqual([], client.acks)
        self.assertEqual(0, FakeFirebirdSource().apply_calls)

        self.state = AgentState(Path(self.temp_dir.name) / "divergent.sqlite3")
        self.state.initialize()
        divergent = FakeFirebirdSource(occurrence_guid="33333333-3333-4333-8333-333333333333")
        client = FakeReturnClient([payload()])
        with self.assertRaisesRegex(RuntimeError, "diverge"):
            self.sync(divergent, client)
        self.assertEqual(1, divergent.apply_calls)
        self.assertEqual([], client.acks)
        self.assertEqual("RECEIVED", self.inbox()[0]["state"])

    def test_recovers_before_commit_without_duplicate_delivery(self):
        source = FakeFirebirdSource(fail_before_commit_times=1)
        client = FakeReturnClient([payload()])
        with self.assertRaisesRegex(RuntimeError, "antes do commit"):
            self.sync(source, client)
        self.assertEqual(set(), source.committed_operations)
        self.sync(source, client)
        self.assertEqual({OPERATION}, source.committed_operations)
        self.assertEqual(2, source.apply_calls)
        self.assertEqual([], self.inbox())

    def test_recovers_after_commit_before_local_applied_using_replay(self):
        source = FakeFirebirdSource()
        client = FakeReturnClient([payload()])
        original = self.state.mark_delivery_applied
        calls = {"count": 0}
        def fail_once(operation_guid, result):
            calls["count"] += 1
            if calls["count"] == 1:
                raise RuntimeError("falha controlada apos commit antes de APPLIED")
            return original(operation_guid, result)
        self.state.mark_delivery_applied = fail_once
        with self.assertRaisesRegex(RuntimeError, "apos commit"):
            self.sync(source, client)
        self.assertEqual({OPERATION}, source.committed_operations)
        self.assertEqual("RECEIVED", self.inbox()[0]["state"])
        self.sync(source, client)
        self.assertEqual(2, source.apply_calls)
        self.assertEqual([], self.inbox())

    def test_recovers_after_local_applied_before_ack_without_reapplying_firebird(self):
        source = FakeFirebirdSource()
        client = FakeReturnClient([payload()], fail_ack_times=1)
        with self.assertRaisesRegex(RuntimeError, "antes do ACK"):
            self.sync(source, client)
        self.assertEqual("APPLIED", self.inbox()[0]["state"])
        self.assertEqual(1, source.apply_calls)
        self.sync(source, client)
        self.assertEqual(1, source.apply_calls)
        self.assertEqual(2, len(client.acks))
        self.assertEqual([], self.inbox())

    def test_conflict_is_terminal_and_acked_operation_is_not_acked_twice(self):
        source = FakeFirebirdSource(result="CONFLITO")
        client = FakeReturnClient([payload()])
        self.sync(source, client)
        self.assertEqual("CONFLITO", client.acks[0][0]["resultado"])
        self.sync(source, client)
        self.assertEqual(1, len(client.acks))
        self.assertEqual([], self.inbox())

    def test_return_path_does_not_issue_direct_carga_status_update(self):
        source_text = Path(__file__).resolve().parent.parent.joinpath("agent", "return_source.py").read_text(encoding="utf-8").upper()
        self.assertNotIn("UPDATE TB_CARGA", source_text)
        self.assertNotIn("CARG_STATUS", source_text)


if __name__ == "__main__":
    unittest.main()
