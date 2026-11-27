import unittest
from agent.receive_orders import normalize

class ReceiveOrderTests(unittest.TestCase):
    def test_preserves_ordered_commercial_values_without_catalog_lookup(self):
        payload={"local_id":"11111111-1111-4111-8111-111111111111","created_at":"2026-10-25T12:00:00+00:00","cliente":{"tipo":"oficial","id":10,"nome":"Cliente"},"forma_pagamento_id":1,"prazo_dias":28,"previsao_entrega":"2026-11-21","gerencial":True,"observacoes":"valor fechado","valor_total":"13.9000","itens":[{"produto_id":1,"descricao":"Malha vendida","unidade":"KG","quantidade":"1.000000","valor_unitario":"13.9000","subtotal":"13.9000"}]}
        order=normalize(payload)
        self.assertEqual("13.9000",format(order["items"][0]["unit_price"],"f")); self.assertEqual("13.9000",format(order["total"],"f")); self.assertEqual(28,order["days"]); self.assertTrue(order["managerial"])

    def test_accepts_optional_extended_provisional_data(self):
        payload={"local_id":"11111111-1111-4111-8111-111111111111","created_at":"2026-10-25T12:00:00+00:00","cliente":{"tipo":"provisorio","nome":"Loja Nova","provisorio":{"local_id":"client-1","tipo_pessoa":"PJ","nome":"Loja Nova","fantasia":"Nova","cpf_cnpj":"12345678901234","telefone":"11999999999","inscricao_estadual":"123","email":"loja@exemplo.com","whatsapp":"11988888888","cep":"01001000","logradouro":"Rua A","numero":"10","complemento":"Sala 2","bairro":"Centro","cidade":"Sao Paulo","uf":"SP"}},"forma_pagamento_id":1,"prazo_dias":28,"previsao_entrega":"2026-11-21","gerencial":False,"observacoes":"","valor_total":"13.9000","itens":[{"produto_id":1,"descricao":"Malha","unidade":"KG","quantidade":"1.000000","valor_unitario":"13.9000","subtotal":"13.9000"}]}
        self.assertEqual("loja@exemplo.com", normalize(payload)["provisional"]["email"])

if __name__=="__main__": unittest.main()
