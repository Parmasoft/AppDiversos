import unittest
from unittest.mock import patch
from urllib.error import HTTPError

from agent.diagnostics import _api_auth_probe


class Settings:
    api_url = "https://api.example"
    token = "segredo-nao-exibir"
    empresa_id = 1
    empresa_nome = "TEKNO PRIME"


class DiagnosticsTests(unittest.TestCase):
    def test_auth_probe_treats_contract_400_as_authenticated_without_publish(self):
        error = HTTPError("https://api.example", 400, "Bad Request", {}, None)
        with patch("agent.diagnostics.urlopen", side_effect=error) as opened:
            _api_auth_probe(Settings())
        request = opened.call_args.args[0]
        self.assertEqual("POST", request.method)
        self.assertEqual(b'{"empresa":{"id":1,"nome":"TEKNO PRIME"},"revision":0}', request.data)
        self.assertNotIn(b"vendedores", request.data)

    def test_auth_probe_distinguishes_unauthorized(self):
        error = HTTPError("https://api.example", 401, "Unauthorized", {}, None)
        with patch("agent.diagnostics.urlopen", side_effect=error):
            with self.assertRaisesRegex(RuntimeError, "HTTP 401"):
                _api_auth_probe(Settings())
