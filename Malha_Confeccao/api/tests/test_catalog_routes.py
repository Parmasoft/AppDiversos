import unittest
from unittest.mock import patch

from app import create_app


class CatalogRouteTests(unittest.TestCase):
    def setUp(self):
        self.app = create_app({"TESTING": True})
        self.client = self.app.test_client()

    def test_catalog_rejects_missing_bearer_token(self):
        self.assertEqual(401, self.client.get("/api/v1/catalogo/produtos-touch").status_code)

    @patch("app.catalog.routes.list_touch_products_for_empresa")
    @patch("app.catalog.routes.session", return_value={"empresa": 10, "vendedor": 7})
    def test_touch_products_derive_company_from_session(self, session, list_products):
        list_products.return_value = [{"id": 3, "descricao": "Malha", "unidade": "MT", "preco_unitario": "12.3456"}]
        response = self.client.get(
            "/api/v1/catalogo/produtos-touch",
            headers={"Authorization": "Bearer token"},
        )
        self.assertEqual(200, response.status_code)
        self.assertEqual({"itens": list_products.return_value}, response.get_json())
        list_products.assert_called_once_with(10)

    @patch("app.catalog.routes.search_clients_for_vendedor")
    @patch("app.catalog.routes.session", return_value={"empresa": 10, "vendedor": 7})
    def test_clients_derive_company_and_seller_from_session(self, session, search):
        search.return_value = []
        response = self.client.get(
            "/api/v1/catalogo/clientes?termo=abc",
            headers={"Authorization": "Bearer token"},
        )
        self.assertEqual(200, response.status_code)
        search.assert_called_once_with(10, 7, "abc")
