import sqlite3
import unittest
from pathlib import Path


class TripClientNameProjectionTests(unittest.TestCase):
    def test_local_trip_reader_uses_same_safe_client_name_expression(self):
        source = Path(__file__).resolve().parent.parent / "app" / "viagens" / "service.py"
        expression = "COALESCE(NULLIF(TRIM(CL.CLI_FANTASIA_APELIDO), ''), CL.CLI_RSOCIAL_NOME)"
        self.assertIn(expression, source.read_text(encoding="utf-8"))

    def test_client_name_projection_cases(self):
        connection = sqlite3.connect(":memory:")
        cases = (
            ("Fantasia", "Razao Social", "Fantasia"),
            (None, "Razao Social", "Razao Social"),
            ("", "Razao Social", "Razao Social"),
            ("   ", "Razao Social", "Razao Social"),
        )
        for alias, legal_name, expected in cases:
            with self.subTest(alias=alias):
                actual = connection.execute(
                    "SELECT COALESCE(NULLIF(TRIM(?), ''), ?)", (alias, legal_name)
                ).fetchone()[0]
                self.assertEqual(expected, actual)
        connection.close()


if __name__ == "__main__":
    unittest.main()
