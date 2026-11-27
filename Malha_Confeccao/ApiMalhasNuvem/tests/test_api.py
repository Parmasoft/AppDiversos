import tempfile, unittest
from pathlib import Path
from uuid import uuid4
from werkzeug.security import generate_password_hash
from app import create_app
from app.database import engine
from app.tables import acesso, cliente, empresa, metadata, pagamento, produto, vendedor

def payload(value="13.9000"):
    return {"local_id":str(uuid4()),"created_at":"2026-10-24T18:30:00+00:00","cliente":{"tipo":"oficial","id":10,"nome":"Cliente"},"forma_pagamento_id":1,"prazo_dias":28,"previsao_entrega":"2026-11-21","gerencial":False,"observacoes":"preco original","valor_total":value,"itens":[{"produto_id":1,"descricao":"Malha","unidade":"KG","quantidade":"1.000000","valor_unitario":value,"subtotal":value}]}
class ApiTests(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory(); self.app=create_app({"TESTING":True,"DATABASE_URL":"sqlite:///"+str(Path(self.temp.name)/"test.db"),"TOKEN_HASH_SECRET":"test-secret"})
        with self.app.app_context():
            metadata.create_all(engine())
            with engine().begin() as c:
                c.execute(empresa.insert().values(id=1,empresa_id=1,nome="Empresa",active=True)); c.execute(vendedor.insert().values(id=1,empresa_id=1,vendedor_id=12,nome="EU",login="EU",password_verifier=generate_password_hash("123"),active=True)); c.execute(acesso.insert().values(vendedor_id=1,empresa_id=1,active=True)); c.execute(produto.insert().values(empresa_id=1,produto_id=1,descricao="Preco novo",unidade="KG",preco_unitario="14.5000",active=True)); c.execute(cliente.insert().values(empresa_id=1,cliente_id=10,vendedor_id=12,nome="Cliente",fantasia="Loja",active=True)); c.execute(pagamento.insert().values(empresa_id=1,forma_pagamento_id=1,descricao="Boleto",active=True))
        self.client=self.app.test_client()
    def tearDown(self):
        with self.app.app_context(): engine().dispose()
        self.temp.cleanup()
    def token(self): return self.client.post("/api/v1/sessoes",json={"login":"EU","senha":"123"}).get_json()["access_token"]
    def test_health(self): self.assertEqual(200,self.client.get("/api/v1/health").status_code)
    def test_login_and_companies(self): self.assertEqual(200,self.client.get("/api/v1/empresas",headers={"Authorization":"Bearer "+self.token()}).status_code)
    def test_catalog_is_authenticated_and_scoped(self):
        headers={"Authorization":"Bearer "+self.token()}; self.assertEqual(401,self.client.get("/api/v1/catalogo/clientes").status_code); self.assertEqual(10,self.client.get("/api/v1/catalogo/clientes?termo=cli",headers=headers).get_json()["itens"][0]["id"]); self.assertEqual("14.5000",self.client.get("/api/v1/catalogo/produtos",headers=headers).get_json()["itens"][0]["preco_unitario"]); self.assertEqual(1,self.client.get("/api/v1/catalogo/formas-pagamento",headers=headers).get_json()["itens"][0]["id"])
    def test_order_replay_conflict_and_original_price(self):
        token=self.token(); headers={"Authorization":"Bearer "+token}; value=payload(); first=self.client.post("/api/v1/pedidos",json=value,headers=headers); self.assertEqual(201,first.status_code); self.assertEqual("RECEBIDO_NUVEM",first.get_json()["status"]); self.assertEqual(200,self.client.post("/api/v1/pedidos",json=value,headers=headers).status_code); changed={**value,"valor_total":"14.5000","itens":[{**value["itens"][0],"valor_unitario":"14.5000","subtotal":"14.5000"}]}; self.assertEqual(409,self.client.post("/api/v1/pedidos",json=changed,headers=headers).status_code); self.assertEqual(1,len(self.client.get("/api/v1/pedidos",headers=headers).get_json()["pedidos"]))
    def test_order_accepts_bounded_legacy_local_id(self):
        value=payload(); value["local_id"]="1793018051045823-4294967295"
        response=self.client.post("/api/v1/pedidos",json=value,headers={"Authorization":"Bearer "+self.token()})
        self.assertEqual(201,response.status_code)
    def test_order_status_is_scoped(self):
        headers={"Authorization":"Bearer "+self.token()}; created=self.client.post("/api/v1/pedidos",json=payload(),headers=headers).get_json(); self.assertEqual(200,self.client.get("/api/v1/pedidos/"+created["id"],headers=headers).status_code)
if __name__=="__main__": unittest.main()
