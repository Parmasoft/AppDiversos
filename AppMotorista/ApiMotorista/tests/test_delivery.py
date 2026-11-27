import copy
import unittest
from unittest.mock import MagicMock, call, patch

from app.api_errors import ApiError
from app.viagens.delivery import register_delivery
from app.viagens.repository import (
    _MANIFEST_COMPANY_SQL,
    _REGISTER_DELIVERY_SQL,
    register_delivery_operation,
)


MANIFEST = "4ABC6281-BF30-4910-A3AA-507C48B53DC7"
OTHER_MANIFEST = "AAAAAAAA-BBBB-4CCC-8DDD-EEEEEEEEEEEE"
OPERATION = "11111111-2222-3333-4444-555555555555"
OCCURRENCE = "22222222-3333-4444-8555-666666666666"


def payload(**changes):
    result = {
        "operacao_guid": OPERATION,
        "occurrence_guid": OCCURRENCE,
        "codigo": "c00264310003850010000",
        "data_hora_aparelho": "2026-08-25T12:30:45-03:00",
        "fuso_minutos": -180,
    }
    result.update(changes)
    return result


class DeliveryTests(unittest.TestCase):
    @patch("app.viagens.delivery.register_delivery_operation")
    def test_canonicalizes_and_calls_the_official_procedure_repository(self, operation):
        operation.return_value = {"resultado": "ACEITA"}
        result = register_delivery(1, 4, "telefone", MANIFEST, 61, 2643, payload())

        self.assertEqual(result, {"resultado": "ACEITA"})
        arguments = operation.call_args.kwargs
        self.assertEqual(arguments["codigo"], "C00264310003850010000")
        self.assertEqual(arguments["payload_versao"], 2)
        self.assertEqual(arguments["occurrence_guid"], OCCURRENCE)
        self.assertEqual(len(arguments["payload_hash"]), 64)
        self.assertEqual(arguments["fuso_minutos"], -180)
        self.assertIsNone(arguments["data_hora_aparelho"].tzinfo)

    @patch("app.viagens.delivery.register_delivery_operation")
    def test_equivalent_timestamps_produce_the_same_hash(self, operation):
        operation.return_value = {"resultado": "ACEITA"}
        register_delivery(1, 4, "telefone", MANIFEST, 61, 2643, payload())
        first_hash = operation.call_args.kwargs["payload_hash"]

        register_delivery(
            1,
            4,
            "telefone",
            MANIFEST.lower(),
            61,
            2643,
            payload(data_hora_aparelho="2026-08-25T12:30:45.000000-03:00"),
        )
        second_hash = operation.call_args.kwargs["payload_hash"]
        self.assertEqual(first_hash, second_hash)

    def test_rejects_server_owned_fields(self):
        with self.assertRaises(ApiError) as raised:
            register_delivery(
                1,
                4,
                "telefone",
                MANIFEST,
                61,
                2643,
                payload(empresa=10),
            )
        self.assertEqual(raised.exception.status_code, 400)

    def test_rejects_mismatched_timezone(self):
        with self.assertRaises(ApiError) as raised:
            register_delivery(
                1,
                4,
                "telefone",
                MANIFEST,
                61,
                2643,
                payload(fuso_minutos=-120),
            )
        self.assertEqual(raised.exception.status_code, 400)

    def test_v2_payload_does_not_reject_occurrence_guid_as_an_unexpected_field(self):
        with patch("app.viagens.delivery.register_delivery_operation") as operation:
            operation.return_value = {"resultado": "ACEITA"}

            result = register_delivery(1, 4, "telefone", MANIFEST, 61, 2643, payload())

        self.assertEqual("ACEITA", result["resultado"])
        self.assertEqual(OCCURRENCE, operation.call_args.kwargs["occurrence_guid"])

    def test_v2_requires_a_valid_occurrence_guid(self):
        for occurrence_guid in (None, "nao-e-uuid"):
            with self.subTest(occurrence_guid=occurrence_guid):
                with self.assertRaises(ApiError) as raised:
                    register_delivery(
                        1, 4, "telefone", MANIFEST, 61, 2643,
                        payload(occurrence_guid=occurrence_guid),
                    )
                self.assertEqual(400, raised.exception.status_code)

    def test_v2_requires_every_contract_field(self):
        for field in ("data_hora_aparelho", "fuso_minutos"):
            with self.subTest(field=field):
                body = payload()
                del body[field]
                with self.assertRaises(ApiError) as raised:
                    register_delivery(1, 4, "telefone", MANIFEST, 61, 2643, body)
                self.assertEqual(400, raised.exception.status_code)

    def test_repository_uses_the_firebird_v2_procedure_with_occurrence_guid(self):
        self.assertIn("SP_APL_ENTREGA_NUVEM", _REGISTER_DELIVERY_SQL)
        self.assertEqual(15, _REGISTER_DELIVERY_SQL.count("?"))

    @patch("app.viagens.repository.transaction")
    def test_repository_derives_company_from_authenticated_manifest_and_uses_15_parameters(self, transaction):
        connection = MagicMock()
        cursor = connection.cursor.return_value
        cursor.fetchone.side_effect = [
            (10,),
            ("ACEITA", "ENTREGA_REGISTRADA", "ok", OPERATION, OCCURRENCE, "C", 2643, 0, 0, 0),
        ]
        transaction.return_value.__enter__.return_value = connection

        result = register_delivery_operation(
            manifesto_guid=MANIFEST, motorista_id=1, sessao_id=4,
            parada=61, pedido=2643, operacao_guid=OPERATION,
            occurrence_guid=OCCURRENCE, payload_versao=2,
            payload_hash="A" * 64, codigo="C00264310003850010000",
            data_hora_aparelho=None, fuso_minutos=-180, latitude=None,
            longitude=None, precisao=None, dispositivo="telefone",
        )

        self.assertEqual("ACEITA", result["resultado"])
        self.assertEqual(OPERATION, result["operacao_guid"])
        self.assertIsNone(result["operacao"])
        cursor.execute.assert_has_calls([
            call(_MANIFEST_COMPANY_SQL, (MANIFEST, 1)),
            call(
                _REGISTER_DELIVERY_SQL,
                (10, MANIFEST, 61, 2643, OCCURRENCE, OPERATION, 2,
                 "A" * 64, "C00264310003850010000", None, -180, None,
                 None, None, "telefone"),
            ),
        ])

    @patch("app.viagens.repository.transaction")
    def test_repository_does_not_call_procedure_without_authenticated_manifest_scope(self, transaction):
        connection = MagicMock()
        cursor = connection.cursor.return_value
        cursor.fetchone.return_value = None
        transaction.return_value.__enter__.return_value = connection

        result = register_delivery_operation(
            manifesto_guid=MANIFEST, motorista_id=99, sessao_id=4,
            parada=61, pedido=2643, operacao_guid=OPERATION,
            occurrence_guid=OCCURRENCE, payload_versao=2,
            payload_hash="A" * 64, codigo="C00264310003850010000",
            data_hora_aparelho=None, fuso_minutos=-180, latitude=None,
            longitude=None, precisao=None, dispositivo="telefone",
        )

        self.assertEqual("RECUSADA", result["resultado"])
        self.assertEqual("MANIFESTO_NAO_AUTORIZADO", result["codigo_resposta"])
        cursor.execute.assert_called_once_with(_MANIFEST_COMPANY_SQL, (MANIFEST, 99))


class IdempotencySessionContractTests(unittest.TestCase):
    def setUp(self):
        self.contract = _CorrectedProcedureContract()
        self.patch = patch(
            "app.viagens.delivery.register_delivery_operation",
            side_effect=self.contract,
        )
        self.patch.start()

    def tearDown(self):
        self.patch.stop()

    def register(
        self,
        *,
        motorista=1,
        sessao=4,
        dispositivo="App Motorista Flutter",
        manifesto=MANIFEST,
        parada=61,
        pedido=2643,
        payload_changes=None,
    ):
        body = payload(**(payload_changes or {}))
        return register_delivery(
            motorista,
            sessao,
            dispositivo,
            manifesto,
            parada,
            pedido,
            body,
        )

    def test_a_same_uuid_payload_and_session_is_accepted_replay(self):
        first = self.register()
        replay = self.register()

        self.assertEqual(first["resultado"], "ACEITA")
        self.assertFalse(first["replay"])
        self.assertEqual(replay["resultado"], "ACEITA")
        self.assertTrue(replay["replay"])

    def test_b_renewed_token_with_same_session_is_accepted_replay(self):
        self.register(sessao=4)

        replay_after_token_renewal = self.register(sessao=4)

        self.assertEqual(replay_after_token_renewal["resultado"], "ACEITA")
        self.assertTrue(replay_after_token_renewal["replay"])

    def test_c_new_legitimate_session_same_driver_device_is_accepted_replay(self):
        self.register(motorista=1, sessao=4, dispositivo="App Motorista Flutter")

        replay_after_new_login = self.register(
            motorista=1,
            sessao=99,
            dispositivo="App Motorista Flutter",
        )

        self.assertEqual(replay_after_new_login["resultado"], "ACEITA")
        self.assertTrue(replay_after_new_login["replay"])
        self.assertEqual(self.contract.movement_count, 1)

    def test_expired_original_session_rejects_old_session_but_new_session_replays(self):
        self.register(sessao=4)
        del self.contract.valid_sessions[4]

        expired_session = self.register(sessao=4)
        new_valid_session = self.register(sessao=99)

        self.assertEqual(expired_session["resultado"], "RECUSADA")
        self.assertEqual(expired_session["codigo_resposta"], "SESSAO_INVALIDA")
        self.assertEqual(new_valid_session["resultado"], "ACEITA")
        self.assertTrue(new_valid_session["replay"])

    def test_d_same_uuid_with_changed_code_or_delivery_context_conflicts(self):
        self.register()

        attempts = (
            {"payload_changes": {"codigo": "OUTRO-CODIGO"}},
            {"payload_changes": {"occurrence_guid": "33333333-3333-4333-8333-333333333333"}},
            {"parada": 62},
            {"pedido": 2644},
            {
                "payload_changes": {
                    "data_hora_aparelho": "2026-08-25T12:31:45-03:00"
                }
            },
        )

        for changes in attempts:
            with self.subTest(changes=changes):
                changed = self.register(sessao=99, **changes)
                self.assertEqual(changed["resultado"], "CONFLITO")
                self.assertEqual(
                    changed["codigo_resposta"],
                    "OPERACAO_GUID_CONFLITO",
                )
        self.assertEqual(self.contract.movement_count, 1)

    def test_e_other_driver_is_rejected_before_fallback(self):
        self.register(motorista=1, sessao=4)

        other_driver = self.register(
            motorista=2,
            sessao=5,
        )

        self.assertEqual(other_driver["resultado"], "RECUSADA")
        self.assertEqual(
            other_driver["codigo_resposta"],
            "MANIFESTO_NAO_AUTORIZADO",
        )
        self.assertEqual(self.contract.movement_count, 1)

    def test_manifest_not_authorized_is_rejected_before_fallback(self):
        self.register()

        unauthorized = self.register(sessao=99, manifesto=OTHER_MANIFEST)

        self.assertEqual(unauthorized["resultado"], "RECUSADA")
        self.assertEqual(
            unauthorized["codigo_resposta"],
            "MANIFESTO_NAO_AUTORIZADO",
        )
        self.assertEqual(self.contract.movement_count, 1)

    def test_f_lost_response_then_new_login_replays_without_new_movement(self):
        self.contract.lose_next_response = True
        with self.assertRaises(ConnectionError):
            self.register(sessao=4)

        new_session = self.register(sessao=99)

        self.assertEqual(new_session["resultado"], "ACEITA")
        self.assertTrue(new_session["replay"])
        self.assertEqual(self.contract.movement_count, 1)

    def test_original_operation_remains_immutable_after_new_session_replay(self):
        self.register(sessao=4)
        original = copy.deepcopy(self.contract.operations[OPERATION])

        replay = self.register(sessao=99)

        self.assertTrue(replay["replay"])
        self.assertEqual(self.contract.operations[OPERATION], original)
        self.assertEqual(self.contract.operations[OPERATION]["sessao_id"], 4)
        self.assertEqual(
            self.contract.operations[OPERATION]["payload_hash"],
            original["payload_hash"],
        )
        self.assertEqual(self.contract.movement_count, 1)

    def test_new_session_is_recorded_only_in_replay_attempt_audit(self):
        self.register(sessao=4)

        self.register(sessao=99)

        self.assertEqual(self.contract.operations[OPERATION]["sessao_id"], 4)
        self.assertEqual(self.contract.attempts[-1]["sessao_id"], 99)
        self.assertEqual(
            self.contract.attempts[-1]["payload_hash"],
            self.contract.operations[OPERATION]["payload_hash"],
        )
        self.assertTrue(self.contract.attempts[-1]["replay"])

    def test_old_operation_is_replayed_by_fallback_without_data_migration(self):
        self.register(sessao=4)
        legacy_record = copy.deepcopy(self.contract.operations[OPERATION])
        legacy_record["created_by_contract"] = "1.1.0.71"
        self.contract.operations[OPERATION] = legacy_record

        replay = self.register(
            sessao=99,
            payload_changes={},
        )

        self.assertEqual(replay["resultado"], "ACEITA")
        self.assertTrue(replay["replay"])
        self.assertEqual(
            self.contract.operations[OPERATION]["created_by_contract"],
            "1.1.0.71",
        )
        self.assertEqual(self.contract.movement_count, 1)

    def test_operation_guid_is_part_of_canonical_payload_hash(self):
        self.register()
        first_hash = self.contract.calls[-1]["payload_hash"]

        self.register(payload_changes={"operacao_guid": "AAAAAAAA-BBBB-4CCC-8DDD-EEEEEEEEEEEE"})
        second_hash = self.contract.calls[-1]["payload_hash"]

        self.assertNotEqual(first_hash, second_hash)

    def test_v2_rejects_unknown_or_out_of_scope_occurrence_before_movement(self):
        cases = (
            ("33333333-3333-4333-8333-333333333333", 61, 2643, "OCORRENCIA_NAO_ENCONTRADA"),
            (OCCURRENCE, 62, 2643, "OCORRENCIA_FORA_DO_ESCOPO"),
            (OCCURRENCE, 61, 2644, "OCORRENCIA_FORA_DO_ESCOPO"),
        )
        for occurrence_guid, parada, pedido, expected_code in cases:
            with self.subTest(occurrence_guid=occurrence_guid, parada=parada, pedido=pedido):
                result = self.register(
                    parada=parada,
                    pedido=pedido,
                    payload_changes={
                        "operacao_guid": f"00000000-0000-4000-8000-{parada:04d}{pedido:08d}",
                        "occurrence_guid": occurrence_guid,
                    },
                )
                self.assertEqual("RECUSADA", result["resultado"])
                self.assertEqual(expected_code, result["codigo_resposta"])
        self.assertEqual(0, self.contract.movement_count)


class _CorrectedProcedureContract:
    """Modelo controlado dos ramos de idempotencia do actScript176."""

    def __init__(self):
        self.operations = {}
        self.calls = []
        self.attempts = []
        self.movement_count = 0
        self.lose_next_response = False
        self.valid_sessions = {4: 1, 5: 2, 6: 1, 99: 1}
        self.manifest_owners = {MANIFEST: 1, OTHER_MANIFEST: 2}
        self.occurrences = {
            OCCURRENCE: (MANIFEST, 61, 2643, "C00264310003850010000"),
        }

    @staticmethod
    def _semantic_content(arguments):
        return (
            arguments["payload_versao"],
            arguments["manifesto_guid"],
            arguments["parada"],
            arguments["pedido"],
            "E",
            arguments["occurrence_guid"],
            arguments["codigo"],
            arguments["motorista_id"],
            arguments["dispositivo"],
            arguments["data_hora_aparelho"],
            arguments["fuso_minutos"],
            arguments["latitude"],
            arguments["longitude"],
            arguments["precisao"],
        )

    def _audit(self, arguments, result):
        self.attempts.append(
            {
                "operacao_guid": arguments["operacao_guid"],
                "sessao_id": arguments["sessao_id"],
                "payload_hash": arguments["payload_hash"],
                "resultado": result["resultado"],
                "replay": result["replay"],
            }
        )

    def __call__(self, **arguments):
        self.calls.append(arguments)
        if self.valid_sessions.get(arguments["sessao_id"]) != arguments["motorista_id"]:
            return {
                "resultado": "RECUSADA",
                "codigo_resposta": "SESSAO_INVALIDA",
                "replay": False,
            }
        owner = self.manifest_owners.get(arguments["manifesto_guid"])
        if owner is None:
            return {
                "resultado": "RECUSADA",
                "codigo_resposta": "MANIFESTO_NAO_ENCONTRADO",
                "replay": False,
            }
        if owner != arguments["motorista_id"]:
            return {
                "resultado": "RECUSADA",
                "codigo_resposta": "MANIFESTO_NAO_AUTORIZADO",
                "replay": False,
            }
        guid = arguments["operacao_guid"]
        existing = self.operations.get(guid)
        if existing is not None:
            same_version_and_hash = (
                existing["payload_versao"] == arguments["payload_versao"]
                and existing["payload_hash"] == arguments["payload_hash"]
            )
            semantically_equal_without_session = existing[
                "semantic_content"
            ] == self._semantic_content(arguments)
            if same_version_and_hash or semantically_equal_without_session:
                result = {
                    "resultado": "ACEITA",
                    "codigo_resposta": "ENTREGA_REGISTRADA",
                    "replay": True,
                }
                self._audit(arguments, result)
                return result
            result = {
                "resultado": "CONFLITO",
                "codigo_resposta": "OPERACAO_GUID_CONFLITO",
                "replay": False,
            }
            self._audit(arguments, result)
            return result
        occurrence = self.occurrences.get(arguments["occurrence_guid"])
        if occurrence is None:
            return {
                "resultado": "RECUSADA",
                "codigo_resposta": "OCORRENCIA_NAO_ENCONTRADA",
                "replay": False,
            }
        if occurrence[:3] != (
            arguments["manifesto_guid"], arguments["parada"], arguments["pedido"],
        ):
            return {
                "resultado": "RECUSADA",
                "codigo_resposta": "OCORRENCIA_FORA_DO_ESCOPO",
                "replay": False,
            }
        if occurrence[3] != arguments["codigo"]:
            return {
                "resultado": "RECUSADA",
                "codigo_resposta": "CODIGO_DIVERGENTE",
                "replay": False,
            }
        self.operations[guid] = copy.deepcopy(arguments)
        self.operations[guid]["semantic_content"] = self._semantic_content(arguments)
        self.movement_count += 1
        result = {
            "resultado": "ACEITA",
            "codigo_resposta": "ENTREGA_REGISTRADA",
            "replay": False,
        }
        self._audit(arguments, result)
        if self.lose_next_response:
            self.lose_next_response = False
            raise ConnectionError("Resposta perdida depois do processamento.")
        return result


if __name__ == "__main__":
    unittest.main()
