import unittest
from unittest.mock import MagicMock, patch

from app import create_app
from app.database import DatabaseConnectionError, check_connectivity, write_connection


class DatabaseTests(unittest.TestCase):
    def setUp(self):
        self.app = create_app({
            "TESTING": True,
            "FB_DATABASE": "E:/teste/DADOS.FDB",
            "FB_USER": "leitura",
            "FB_PASSWORD": "valor-de-teste-nao-real",
        })

    @patch("app.database._driver")
    def test_connectivity_uses_readonly_transaction_and_closes_resources(self, driver):
        driver.return_value = MagicMock(
            isc_tpb_version3=3,
            isc_tpb_read=8,
            isc_tpb_read_committed=15,
            isc_tpb_rec_version=17,
            isc_tpb_wait=6,
        )
        connection = MagicMock()
        cursor = connection.cursor.return_value
        cursor.fetchone.return_value = (1,)
        driver.return_value.connect.return_value = connection

        with self.app.app_context():
            self.assertTrue(check_connectivity())

        cursor.execute.assert_called_once_with("SELECT 1 FROM RDB$DATABASE")
        connection.begin.assert_called_once()
        connection.commit.assert_called_once()
        cursor.close.assert_called_once()
        connection.close.assert_called_once()

    @patch("app.database._driver")
    def test_connection_failure_is_sanitized(self, driver):
        driver.return_value.connect.side_effect = RuntimeError("senha confidencial")
        with self.app.app_context():
            with self.assertRaises(DatabaseConnectionError) as raised:
                check_connectivity()
        self.assertNotIn("confidencial", str(raised.exception))

    @patch("app.database._driver")
    def test_write_transaction_rolls_back_on_failure(self, driver):
        driver.return_value = MagicMock(
            isc_tpb_version3=3,
            isc_tpb_write=9,
            isc_tpb_read_committed=15,
            isc_tpb_rec_version=17,
            isc_tpb_wait=6,
        )
        connection = MagicMock()
        driver.return_value.connect.return_value = connection
        with self.app.app_context():
            with self.assertRaises(RuntimeError):
                with write_connection():
                    raise RuntimeError("falha simulada")
        connection.rollback.assert_called_once()
        connection.commit.assert_not_called()
        connection.close.assert_called_once()
