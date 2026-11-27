import unittest

from app import create_app


class AppTests(unittest.TestCase):
    def setUp(self):
        self.app = create_app({"TESTING": True})
        self.client = self.app.test_client()

    def test_health_does_not_expose_database_details(self):
        response = self.client.get("/health")
        self.assertEqual(200, response.status_code)
        self.assertEqual({"status": "ok"}, response.get_json())

    def test_unknown_route_returns_generic_json_error(self):
        response = self.client.get("/inexistente")
        self.assertEqual(404, response.status_code)
        self.assertEqual({"erro": "Rota nao encontrada."}, response.get_json())

    def test_logout_requires_bearer_token(self):
        response = self.client.delete("/api/v1/sessoes/atual")
        self.assertEqual(401, response.status_code)
