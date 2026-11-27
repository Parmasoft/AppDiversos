import unittest
from contextlib import contextmanager
from datetime import datetime
from unittest.mock import patch

from app import create_app
from app.orders.service import OrderConflict, OrderValidationError, content_hash, normalize, receive_order


def official_payload():
    return {"local_id":"order-001","created_at":"2026-10-24T10:00:00+00:00","cliente":{"tipo":"oficial","id":10,"nome":"Cliente Oficial"},"forma_pagamento_id":2,"prazo_dias":15,"previsao_entrega":"2026-11-08","gerencial":False,"observacoes":"negociacao preservada","valor_total":"37.8750","itens":[{"produto_id":1,"descricao":"Malha A","unidade":"KG","quantidade":"1.250000","valor_unitario":"10.1000","subtotal":"12.6250"},{"produto_id":2,"descricao":"Malha B","unidade":"KG","quantidade":"2.500000","valor_unitario":"10.1000","subtotal":"25.2500"}]}


class OrderContractTests(unittest.TestCase):
    def test_official_and_fractional_values_are_normalized(self):
        value = normalize(official_payload())
        self.assertEqual("oficial", value["client_kind"])
        self.assertEqual("1.250000", format(value["items"][0]["quantity"], "f"))
        self.assertEqual(64, len(content_hash(value)))

    def test_provisional_client_contract(self):
        value = official_payload(); value["cliente"]={"tipo":"provisorio","nome":"Novo Cliente","provisorio":{"local_id":"client-1","tipo_pessoa":"PJ","nome":"Novo Cliente","fantasia":"Novo","cpf_cnpj":"12345678901234","telefone":"11999999999"}}
        order = normalize(value)
        self.assertEqual("client-1", order["provisional"]["local_id"])

    def test_extended_provisional_fields_are_optional_and_preserved(self):
        value = official_payload(); value["cliente"]={"tipo":"provisorio","nome":"Novo Cliente","provisorio":{"local_id":"client-1","tipo_pessoa":"PJ","nome":"Novo Cliente","fantasia":"Novo","cpf_cnpj":"12345678901234","telefone":"11999999999","inscricao_estadual":"123","email":"novo@exemplo.com","whatsapp":"11988888888","cep":"01001000","logradouro":"Rua A","numero":"10","complemento":"Sala 2","bairro":"Centro","cidade":"Sao Paulo","uf":"SP"}}
        self.assertEqual("novo@exemplo.com", normalize(value)["provisional"]["email"])

    def test_divergent_subtotal_is_rejected(self):
        value = official_payload(); value["itens"][0]["subtotal"]="12.6200"
        with self.assertRaises(OrderValidationError): normalize(value)


class OrderRouteTests(unittest.TestCase):
    def setUp(self):
        self.client = create_app({"TESTING": True}).test_client()

    def test_invalid_session_is_rejected(self):
        response = self.client.post("/api/v1/pedidos-malhas/recepcao", json=official_payload())
        self.assertEqual(401, response.status_code)

    @patch("app.orders.routes.session", return_value={"empresa":1,"vendedor":2})
    @patch("app.orders.routes.receive_order", return_value=({"pedido_recebido_id":9,"status":"RECEBIDO"}, False))
    def test_new_receipt(self, receive, _session):
        response = self.client.post("/api/v1/pedidos-malhas/recepcao", json=official_payload(), headers={"Authorization":"Bearer token"})
        self.assertEqual(201, response.status_code); self.assertFalse(response.get_json()["reenvio"])

    @patch("app.orders.routes.session", return_value={"empresa":1,"vendedor":2})
    @patch("app.orders.routes.receive_order", return_value=({"pedido_recebido_id":9,"status":"RECEBIDO"}, True))
    def test_identical_retry_returns_receipt(self, receive, _session):
        response = self.client.post("/api/v1/pedidos-malhas/recepcao", json=official_payload(), headers={"Authorization":"Bearer token"})
        self.assertEqual(200, response.status_code); self.assertTrue(response.get_json()["reenvio"])

    @patch("app.orders.routes.session", return_value={"empresa":1,"vendedor":2})
    @patch("app.orders.routes.receive_order", side_effect=OrderConflict())
    def test_divergent_retry_returns_conflict(self, receive, _session):
        response = self.client.post("/api/v1/pedidos-malhas/recepcao", json=official_payload(), headers={"Authorization":"Bearer token"})
        self.assertEqual(409, response.status_code)


class ConcurrencyFallbackTests(unittest.TestCase):
    def test_unique_race_reuses_identical_committed_receipt(self):
        payload = official_payload(); digest = content_hash(normalize(payload))
        class Cursor:
            def execute(self, *_args): pass
            def fetchone(self): return (77, digest, datetime(2026, 10, 24, 12, 0))
            def close(self): pass
        class Connection:
            def cursor(self): return Cursor()
        @contextmanager
        def readonly(): yield Connection()
        @contextmanager
        def writer(): raise RuntimeError("violation of PRIMARY or UNIQUE KEY")
        with patch("app.orders.service.write_connection", writer), patch("app.orders.service.read_connection", readonly):
            receipt, repeated = receive_order(payload, {"empresa":1,"vendedor":2})
        self.assertTrue(repeated); self.assertEqual(77, receipt["pedido_recebido_id"])
