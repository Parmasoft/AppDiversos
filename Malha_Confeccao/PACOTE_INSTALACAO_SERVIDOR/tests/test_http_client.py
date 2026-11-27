import socket
import unittest
from unittest.mock import patch
from urllib.error import HTTPError, URLError

from agent.http_client import Client, CommunicationError


class HttpClientTests(unittest.TestCase):
    def test_reports_http_status_without_request_secrets(self):
        client = Client("https://api.example", "segredo-nao-exibir")
        with patch("agent.http_client.urlopen", side_effect=HTTPError("https://api.example", 401, "Unauthorized", {}, None)):
            with self.assertRaisesRegex(CommunicationError, r"HTTP 401.*vendedores/snapshot") as caught:
                client.post("/api/v1/agente/vendedores/snapshot", {})
        self.assertNotIn("segredo-nao-exibir", str(caught.exception))

    def test_classifies_dns_without_request_secrets(self):
        client = Client("https://api.example", "segredo-nao-exibir")
        with patch("agent.http_client.urlopen", side_effect=URLError(socket.gaierror())):
            with self.assertRaisesRegex(CommunicationError, "DNS") as caught:
                client.post("/api/v1/agente/vendedores/snapshot", {})
        self.assertNotIn("segredo-nao-exibir", str(caught.exception))
