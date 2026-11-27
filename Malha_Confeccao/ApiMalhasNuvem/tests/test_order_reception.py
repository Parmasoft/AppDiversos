import hashlib, hmac, tempfile, unittest
from datetime import timedelta
from pathlib import Path
from uuid import uuid4
from werkzeug.security import generate_password_hash
from app import create_app
from app.database import engine
from app.tables import acesso, agente, empresa, metadata, vendedor
from app.tables import pedido
from app.service import now

def digest(value): return hmac.new(b"test-secret",value.encode(),hashlib.sha256).hexdigest()
def payload(): return {"local_id":str(uuid4()),"created_at":"2026-10-25T12:00:00+00:00","cliente":{"tipo":"oficial","id":10,"nome":"Cliente"},"forma_pagamento_id":1,"prazo_dias":28,"previsao_entrega":"2026-11-21","gerencial":False,"observacoes":"preco original","valor_total":"13.9000","itens":[{"produto_id":1,"descricao":"Malha original","unidade":"KG","quantidade":"1.000000","valor_unitario":"13.9000","subtotal":"13.9000"}]}

class ReceptionTests(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory(); self.app=create_app({"TESTING":True,"DATABASE_URL":"sqlite:///"+str(Path(self.temp.name)/"test.db"),"TOKEN_HASH_SECRET":"test-secret","AGENT_CLAIM_SECONDS":120})
        with self.app.app_context():
            metadata.create_all(engine())
            with engine().begin() as c:
                c.execute(empresa.insert().values(id=1,empresa_id=10,nome="Malhas",active=True)); c.execute(empresa.insert().values(id=2,empresa_id=11,nome="Outra",active=True))
                c.execute(vendedor.insert().values(id=1,empresa_id=1,vendedor_id=7,nome="Vendedor",login="VENDEDOR",password_verifier=generate_password_hash("123"),active=True)); c.execute(acesso.insert().values(vendedor_id=1,empresa_id=1,active=True))
                c.execute(agente.insert().values(id=1,empresa_id=1,agent_guid="agent-10",token_digest=digest("agent-10"),active=True)); c.execute(agente.insert().values(id=2,empresa_id=2,agent_guid="agent-11",token_digest=digest("agent-11"),active=True))
        self.client=self.app.test_client()
    def tearDown(self):
        with self.app.app_context(): engine().dispose()
        self.temp.cleanup()
    def seller_headers(self): return {"Authorization":"Bearer "+self.client.post("/api/v1/sessoes",json={"login":"VENDEDOR","senha":"123"}).get_json()["access_token"]}
    def agent_headers(self,token="agent-10"): return {"Authorization":"Bearer "+token}
    def test_claim_ack_preserves_original_payload_and_is_idempotent(self):
        original=payload(); created=self.client.post("/api/v1/pedidos",json=original,headers=self.seller_headers()).get_json()
        claimed=self.client.post("/api/v1/agente/pedidos/claim",json={},headers=self.agent_headers()).get_json()["pedido"]
        self.assertEqual(created["id"],claimed["id"]); self.assertEqual(7,claimed["vendedor_id"]); self.assertEqual("13.9000",claimed["payload"]["itens"][0]["valor_unitario"])
        ack=self.client.post("/api/v1/agente/pedidos/"+claimed["id"]+"/ack",json={"resultado":{"pedido_recebido_id":99,"status":"RECEBIDO","repetido":False}},headers=self.agent_headers())
        self.assertEqual("RECEBIDO_PARMAGESTOR",ack.get_json()["status"])
        self.assertTrue(self.client.post("/api/v1/agente/pedidos/"+claimed["id"]+"/ack",json={"resultado":{}},headers=self.agent_headers()).get_json()["repetido"])
        self.assertIsNone(self.client.post("/api/v1/agente/pedidos/claim",json={},headers=self.agent_headers()).get_json()["pedido"])
    def test_other_company_cannot_claim_order(self):
        self.client.post("/api/v1/pedidos",json=payload(),headers=self.seller_headers())
        self.assertIsNone(self.client.post("/api/v1/agente/pedidos/claim",json={},headers=self.agent_headers("agent-11")).get_json()["pedido"])
    def test_preserves_extended_provisional_payload(self):
        body=payload(); body["cliente"]={"tipo":"provisorio","nome":"Loja Nova","provisorio":{"local_id":"client-1","tipo_pessoa":"PJ","nome":"Loja Nova","email":"loja@exemplo.com","cep":"01001000","logradouro":"Rua A","uf":"SP"}}
        self.client.post("/api/v1/pedidos",json=body,headers=self.seller_headers())
        claimed=self.client.post("/api/v1/agente/pedidos/claim",json={},headers=self.agent_headers()).get_json()["pedido"]
        self.assertEqual("loja@exemplo.com",claimed["payload"]["cliente"]["provisorio"]["email"])
    def test_expired_claim_is_recovered_without_losing_payload(self):
        self.client.post("/api/v1/pedidos",json=payload(),headers=self.seller_headers())
        first=self.client.post("/api/v1/agente/pedidos/claim",json={},headers=self.agent_headers()).get_json()["pedido"]
        with self.app.app_context(), engine().begin() as c: c.execute(pedido.update().where(pedido.c.pedido_nuvem_id==first["id"]).values(claim_expires_at=now()-timedelta(seconds=1)))
        recovered=self.client.post("/api/v1/agente/pedidos/claim",json={},headers=self.agent_headers()).get_json()["pedido"]
        self.assertEqual(first["id"],recovered["id"]); self.assertEqual(first["payload"],recovered["payload"]); self.assertEqual(2,recovered["tentativa"])

if __name__=="__main__": unittest.main()
