import hashlib
import hmac
import os
import unittest
from uuid import uuid4

from sqlalchemy import select
from werkzeug.security import generate_password_hash

from app import create_app
from app.database import engine
from app.tables import acesso, agente, empresa, item, pedido, produto, vendedor


def payload():
    return {"local_id":str(uuid4()),"created_at":"2026-10-24T18:30:00+00:00","cliente":{"tipo":"oficial","id":10,"nome":"Cliente"},"forma_pagamento_id":1,"prazo_dias":28,"previsao_entrega":"2026-11-21","gerencial":False,"observacoes":"preco original","valor_total":"13.9000","itens":[{"produto_id":1,"descricao":"Malha","unidade":"KG","quantidade":"1.000000","valor_unitario":"13.9000","subtotal":"13.9000"}]}

def agent_digest(value): return hmac.new(b"postgres-test-secret",value.encode(),hashlib.sha256).hexdigest()


@unittest.skipUnless(os.getenv("MALHAS_POSTGRES_TEST_URL"), "MALHAS_POSTGRES_TEST_URL nao configurada")
class PostgreSqlIntegrationTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.app=create_app({"TESTING":True,"DATABASE_URL":os.environ["MALHAS_POSTGRES_TEST_URL"],"TOKEN_HASH_SECRET":"postgres-test-secret"})
        code=int(uuid4().int % 100000000) + 1000000000
        with cls.app.app_context(), engine().begin() as c:
            company_id=c.execute(empresa.insert().values(empresa_id=code,nome="Empresa Teste",active=True)).inserted_primary_key[0]
            seller_id=c.execute(vendedor.insert().values(empresa_id=company_id,vendedor_id=12,nome="Vendedor Teste",login="TESTE"+str(code),password_verifier=generate_password_hash("123"),active=True)).inserted_primary_key[0]
            c.execute(acesso.insert().values(vendedor_id=seller_id,empresa_id=company_id,active=True))
            c.execute(produto.insert().values(empresa_id=company_id,produto_id=1,descricao="Preco atualizado",unidade="KG",preco_unitario="14.5000",active=True))
        cls.login_name="TESTE"+str(code)
        cls.client=cls.app.test_client()

    def token(self): return self.client.post("/api/v1/sessoes",json={"login":self.login_name,"senha":"123"}).get_json()["access_token"]

    def test_postgresql_receipt_replay_conflict_status_and_original_values(self):
        headers={"Authorization":"Bearer "+self.token()}; original=payload()
        first=self.client.post("/api/v1/pedidos",json=original,headers=headers)
        self.assertEqual(201,first.status_code); cloud_id=first.get_json()["id"]
        self.assertEqual("RECEBIDO_NUVEM",first.get_json()["status"])
        self.assertEqual(200,self.client.post("/api/v1/pedidos",json=original,headers=headers).status_code)
        changed={**original,"valor_total":"14.5000","itens":[{**original["itens"][0],"valor_unitario":"14.5000","subtotal":"14.5000"}]}
        self.assertEqual(409,self.client.post("/api/v1/pedidos",json=changed,headers=headers).status_code)
        self.assertEqual("RECEBIDO_NUVEM",self.client.get("/api/v1/pedidos/"+cloud_id,headers=headers).get_json()["status"])
        with self.app.app_context(), engine().connect() as c:
            saved=c.execute(select(pedido.c.payload_json).where(pedido.c.pedido_nuvem_id==cloud_id)).scalar_one()
        self.assertEqual("13.9000",saved["itens"][0]["valor_unitario"])
        self.assertEqual("13.9000",saved["valor_total"])

if __name__=="__main__": unittest.main()

@unittest.skipUnless(os.getenv("MALHAS_POSTGRES_TEST_URL"), "MALHAS_POSTGRES_TEST_URL nao configurada")
class PostgreSqlAgentSnapshotIntegrationTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.app=create_app({"TESTING":True,"DATABASE_URL":os.environ["MALHAS_POSTGRES_TEST_URL"],"TOKEN_HASH_SECRET":"postgres-test-secret"})
        code=int(uuid4().int % 1000000000) + 1000000000
        with cls.app.app_context(), engine().begin() as c:
            company_id=c.execute(empresa.insert().values(empresa_id=code,nome="Empresa Agente Teste",active=True)).inserted_primary_key[0]
            c.execute(agente.insert().values(empresa_id=company_id,agent_guid="agent-test-"+str(code),token_digest=agent_digest("agent-test-token-"+str(code)),active=True))
        cls.company_code=code; cls.agent_token="agent-test-token-"+str(code); cls.client=cls.app.test_client()
    def headers(self): return {"Authorization":"Bearer "+self.agent_token}
    def sellers(self,revision=1): return {"empresa":{"id":self.company_code,"nome":"Empresa Agente Teste"},"revision":revision,"vendedores":[{"id":41,"nome":"Vendedor Agente","login":"AG"+str(self.company_code),"senha":"senha-ficticia","ativo":True,"empresas_permitidas":[self.company_code]}]}
    def catalog(self,revision=1,price="14.5000"): return {"empresa":{"id":self.company_code,"nome":"Empresa Agente Teste"},"revision":revision,"clientes":[{"id":51,"vendedor_id":41,"nome":"Cliente Agente","fantasia":"Cliente","ativo":True}],"produtos":[{"id":61,"descricao":"Malha Agente","unidade":"KG","preco_unitario":price,"ativo":True}],"formas_pagamento":[{"id":71,"descricao":"Boleto","ativo":True}]}
    def test_agent_snapshots_on_postgresql_preserve_orders(self):
        self.assertEqual(401,self.client.post("/api/v1/agente/catalogo/snapshots",json=self.catalog()).status_code)
        self.assertEqual(200,self.client.post("/api/v1/agente/vendedores/snapshot",json=self.sellers(),headers=self.headers()).status_code)
        self.assertEqual(200,self.client.post("/api/v1/agente/catalogo/snapshots",json=self.catalog(),headers=self.headers()).status_code)
        self.assertTrue(self.client.post("/api/v1/agente/catalogo/snapshots",json=self.catalog(),headers=self.headers()).get_json()["repetido"])
        invalid={"Authorization":"Bearer token-invalido"}; self.assertEqual(401,self.client.post("/api/v1/agente/catalogo/snapshots",json=self.catalog(),headers=invalid).status_code)
        other=self.catalog(); other["empresa"]["id"]=self.company_code+1
        self.assertEqual(403,self.client.post("/api/v1/agente/catalogo/snapshots",json=other,headers=self.headers()).status_code)
        session=self.client.post("/api/v1/sessoes",json={"login":"AG"+str(self.company_code),"senha":"senha-ficticia"}).get_json()["access_token"]
        original=payload(); original["itens"][0]["produto_id"]=61; original["forma_pagamento_id"]=71
        self.assertEqual(201,self.client.post("/api/v1/pedidos",json=original,headers={"Authorization":"Bearer "+session}).status_code)
        self.assertEqual(200,self.client.post("/api/v1/agente/catalogo/snapshots",json=self.catalog(2,"15.0000"),headers=self.headers()).status_code)
        with self.app.app_context(), engine().connect() as c:
            saved=c.execute(item.select().where(item.c.produto_id==61)).mappings().first()
        self.assertEqual("13.9000",str(saved["preco_unitario"]))
