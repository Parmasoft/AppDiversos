import unittest
from decimal import Decimal
from unittest.mock import MagicMock, patch

from app.catalog.service import list_touch_products_for_empresa


class TouchProductCatalogServiceTests(unittest.TestCase):
    @patch("app.catalog.service.read_connection")
    def test_serializes_database_decimal_without_float(self, read_connection):
        connection = MagicMock()
        cursor = MagicMock()
        read_connection.return_value.__enter__.return_value = connection
        connection.cursor.return_value = cursor
        cursor.fetchall.return_value = [
            (4573, "Malha branca", "UN", Decimal("319.90")),
            (4582, "Malha mescla", "UN", Decimal("349.9")),
        ]

        items = list_touch_products_for_empresa(1)

        self.assertEqual(
            [
                {
                    "id": 4573,
                    "descricao": "Malha branca",
                    "unidade": "UN",
                    "preco_unitario": "319.90",
                },
                {
                    "id": 4582,
                    "descricao": "Malha mescla",
                    "unidade": "UN",
                    "preco_unitario": "349.9",
                },
            ],
            items,
        )
        query = cursor.execute.call_args.args[0]
        self.assertIn("P.PRD_PRECO_VENDA", query)
        self.assertEqual((1,), cursor.execute.call_args.args[1])

    @patch("app.catalog.service.read_connection")
    def test_marks_null_or_invalid_price_as_unavailable(self, read_connection):
        connection = MagicMock()
        cursor = MagicMock()
        read_connection.return_value.__enter__.return_value = connection
        connection.cursor.return_value = cursor
        cursor.fetchall.return_value = [
            (1, "Sem preço", "UN", None),
            (2, "Preço inválido", "UN", Decimal("-1")),
        ]

        items = list_touch_products_for_empresa(1)

        self.assertEqual([None, None], [item["preco_unitario"] for item in items])

