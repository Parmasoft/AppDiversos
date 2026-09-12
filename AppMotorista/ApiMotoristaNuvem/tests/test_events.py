import tempfile
import unittest
from pathlib import Path

from app import create_app
from sqlalchemy import func, select

from app.database import dispose_database, get_engine, initialize_database
from app.errors import ApiError
from app.events import record_authoritative_event
from app.provisioning import provision_tenant
from app.tables import notification_outbox, tracking_event


def delivered_event(occurred_at="2026-09-03T15:00:00+00:00"):
    return {
        "contrato_versao": 1,
        "tipo": "PEDIDO_ENTREGUE",
        "versao_evento": 1,
        "ocorrido_em": occurred_at,
        "fonte_autoritativa": "FIREBIRD",
        "operacao_guid": "OP-001",
        "carga_guid": "CAR-A",
        "manifesto_guid": "MAN-A",
        "parada_guid": "PAR-A",
        "pedido_guid": "PED-A",
        "cliente": {
            "id": 51,
            "nome": "Cliente A",
            "email_notificacao": "cliente@example.test",
            "aceita_email": True,
        },
    }


class TrackingEventTest(unittest.TestCase):
    def setUp(self):
        self.temp_dir = tempfile.TemporaryDirectory()
        self.app = create_app(
            {
                "TESTING": True,
                "DATABASE_URL": f"sqlite+pysqlite:///{(Path(self.temp_dir.name) / 'test.sqlite3').as_posix()}",
                "TOKEN_HASH_SECRET": "test-secret-with-enough-entropy",
            }
        )
        with self.app.app_context():
            initialize_database()
            self.tenant_id = provision_tenant(
                "GRAMDECOR", "GramDecor", "2026-09-03T12:00:00+00:00"
            )
            self.old_tenant_id = provision_tenant(
                "ANTIGO", "Tenant historico", "2026-09-04T00:00:00+00:00"
            )

    def tearDown(self):
        with self.app.app_context():
            dispose_database()
        self.temp_dir.cleanup()

    def test_event_replay_creates_one_event_and_one_outbox_item(self):
        with self.app.app_context():
            first = record_authoritative_event(self.tenant_id, delivered_event())
            replay = record_authoritative_event(self.tenant_id, delivered_event())
            self.assertEqual(0, first["replay"])
            self.assertEqual(1, replay["replay"])
            with get_engine().connect() as connection:
                self.assertEqual(1, connection.execute(select(func.count()).select_from(tracking_event)).scalar_one())
                self.assertEqual(1, connection.execute(select(func.count()).select_from(notification_outbox)).scalar_one())

    def test_same_logical_event_with_changed_content_conflicts(self):
        with self.app.app_context():
            record_authoritative_event(self.tenant_id, delivered_event())
            changed = delivered_event()
            changed["operacao_guid"] = "OP-OUTRA"
            with self.assertRaises(ApiError) as error:
                record_authoritative_event(self.tenant_id, changed)
            self.assertEqual("EVENTO_LOGICO_CONFLITO", error.exception.code)

    def test_historical_event_before_activation_does_not_enqueue(self):
        with self.app.app_context():
            result = record_authoritative_event(self.old_tenant_id, delivered_event())
            self.assertEqual(0, result["replay"])
            with get_engine().connect() as connection:
                self.assertEqual(
                    1,
                    connection.execute(
                        select(func.count()).select_from(tracking_event).where(
                            tracking_event.c.tenant_id == self.old_tenant_id
                        )
                    ).scalar_one(),
                )
                self.assertEqual(
                    0,
                    connection.execute(
                        select(func.count()).select_from(notification_outbox).where(
                            notification_outbox.c.tenant_id == self.old_tenant_id
                        )
                    ).scalar_one(),
                )

    def test_event_requires_firebird_and_delivery_operation_guid(self):
        with self.app.app_context():
            invalid_source = delivered_event()
            invalid_source["fonte_autoritativa"] = "NUVEM"
            with self.assertRaises(ApiError):
                record_authoritative_event(self.tenant_id, invalid_source)
            no_operation = delivered_event()
            no_operation["operacao_guid"] = None
            with self.assertRaises(ApiError):
                record_authoritative_event(self.tenant_id, no_operation)

    def test_saiu_para_entrega_contract_is_prepared_without_emitter(self):
        with self.app.app_context():
            with get_engine().connect() as connection:
                self.assertEqual(0, connection.execute(select(func.count()).select_from(tracking_event)).scalar_one())
                self.assertEqual(0, connection.execute(select(func.count()).select_from(notification_outbox)).scalar_one())


if __name__ == "__main__":
    unittest.main()
