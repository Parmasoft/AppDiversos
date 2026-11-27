import tempfile, unittest
from pathlib import Path
from agent.state import State
from agent.sync import run_once

class Settings:
    empresa_id=10; empresa_nome="Malhas"
def reader(_): return ([{"id":1,"nome":"V","login":"V","senha":"s","ativo":True,"empresas_permitidas":[10]}],[],[],[])
class Client:
    def __init__(self,fail=False): self.fail=fail; self.calls=[]
    def post(self,path,body):
        self.calls.append((path,body))
        if self.fail: raise RuntimeError("network")
        if path.endswith("/pedidos/claim"): return {"pedido":None}
        return {}

class SyncTests(unittest.TestCase):
    def test_keeps_same_pending_snapshot_after_failure_and_advances_after_success(self):
        with tempfile.TemporaryDirectory() as path:
            state=State(str(Path(path)/"state.db")); broken=Client(True)
            with self.assertRaises(RuntimeError): run_once(Settings(),state,reader,broken)
            revision,body=state.pending("vendedores"); self.assertEqual(1,revision)
            ok=Client(); run_once(Settings(),state,reader,ok)
            self.assertEqual(body,ok.calls[0][1]); self.assertIsNone(state.pending("vendedores"))
            run_once(Settings(),state,reader,ok); self.assertEqual(2,ok.calls[-2][1]["revision"])
            state.close()
