import hashlib, hmac, tempfile, unittest
from pathlib import Path
from uuid import uuid4
from werkzeug.security import generate_password_hash

from app import create_app
from app.database import engine
from app.tables import acesso, agente, cliente, empresa, item, metadata, pagamento, pedido, produto, vendedor

def digest(value): return hmac.new(b"test-secret",value.encode(),hashlib.sha256).hexdigest()
def order_payload(): return {"local_id":str(uuid4()),"created_at":"2026-10-24T18:30:00+00:00","cliente":{"tipo":"oficial","id":10},"forma_pagamento_id":1,"prazo_dias":28,"previsao_entrega":"2026-11-21","gerencial":False,"observacoes":"original","valor_total":"13.9000","itens":[{"produto_id":1,"descricao":"Malha antiga","unidade":"KG","quantidade":"1.000000","valor_unitario":"13.9000","subtotal":"13.9000"}]}

class AgentSnapshotTests(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory(); self.app=create_app({"TESTING":True,"DATABASE_URL":"sqlite:///"+str(Path(self.temp.name)/"test.db"),"TOKEN_HASH_SECRET":"test-secret"})
        with self.app.app_context():
            metadata.create_all(engine())
            with engine().begin() as c:
                c.execute(empresa.insert().values(id=1,empresa_id=10,nome="Malhas",active=True))
                c.execute(agente.insert().values(id=1,empresa_id=1,agent_guid="agent-local",token_digest=digest("agent-token"),active=True))
        self.client=self.app.test_client(); self.headers={"Authorization":"Bearer agent-token"}
    def tearDown(self):
        with self.app.app_context(): engine().dispose()
        self.temp.cleanup()
    def sellers(self,revision=1): return {"empresa":{"id":10,"nome":"Malhas Atualizada"},"revision":revision,"vendedores":[{"id":7,"nome":"Vendedor","login":"VENDEDOR","senha":"123","ativo":True,"empresas_permitidas":[10]}]}
    def catalog(self,revision=1,price="14.5000"): return {"empresa":{"id":10,"nome":"Malhas Atualizada"},"revision":revision,"clientes":[{"id":9,"vendedor_id":7,"nome":"Cliente","fantasia":"Loja","ativo":True}],"produtos":[{"id":1,"descricao":"Malha","unidade":"KG","preco_unitario":price,"ativo":True}],"formas_pagamento":[{"id":1,"descricao":"Boleto","ativo":True}]}
    def test_agent_requires_technical_bearer(self):
        self.assertEqual(401,self.client.post("/api/v1/agente/catalogo/snapshots",json=self.catalog()).status_code)
    def test_sellers_permissions_catalog_replay_and_order_price_are_independent(self):
        self.assertEqual(200,self.client.post("/api/v1/agente/vendedores/snapshot",json=self.sellers(),headers=self.headers).status_code)
        first=self.client.post("/api/v1/agente/catalogo/snapshots",json=self.catalog(),headers=self.headers)
        self.assertEqual(200,first.status_code); self.assertFalse(first.get_json()["repetido"])
        replay=self.client.post("/api/v1/agente/catalogo/snapshots",json=self.catalog(),headers=self.headers)
        self.assertEqual(200,replay.status_code); self.assertTrue(replay.get_json()["repetido"])
        login=self.client.post("/api/v1/sessoes",json={"login":"VENDEDOR","senha":"123"}).get_json()["access_token"]
        created=self.client.post("/api/v1/pedidos",json=order_payload(),headers={"Authorization":"Bearer "+login})
        self.assertEqual(201,created.status_code)
        self.assertEqual(200,self.client.post("/api/v1/agente/catalogo/snapshots",json=self.catalog(2,"15.0000"),headers=self.headers).status_code)
        with self.app.app_context(), engine().connect() as c:
            self.assertEqual("13.9000",str(c.execute(item.select()).mappings().first()["preco_unitario"]))
            self.assertEqual("15.0000",str(c.execute(produto.select()).mappings().first()["preco_unitario"]))
            self.assertEqual(1,len(c.execute(cliente.select()).all())); self.assertEqual(1,len(c.execute(pagamento.select()).all()))
    def test_agent_cannot_publish_for_another_company(self):
        data=self.catalog(); data["empresa"]["id"]=11
        self.assertEqual(403,self.client.post("/api/v1/agente/catalogo/snapshots",json=data,headers=self.headers).status_code)
