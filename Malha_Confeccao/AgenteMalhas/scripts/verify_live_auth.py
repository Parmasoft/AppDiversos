"""Valida login HTTPS usando um vendedor projetado pelo Agente, sem exibir segredos."""
import json
import sys
from pathlib import Path
from urllib.request import Request, urlopen

sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
from agent.config import Settings
from agent.read_source import snapshot

settings=Settings.from_env()
sellers,_,_,_=snapshot(settings)
seller=next((value for value in sellers if value["ativo"]),None)
if not seller: raise RuntimeError("Nenhum vendedor ativo elegivel para validar autenticacao")
request=Request(settings.api_url+"/api/v1/sessoes",data=json.dumps({"usuario":seller["login"],"senha":seller["senha"]}).encode(),headers={"Content-Type":"application/json"},method="POST")
with urlopen(request,timeout=30) as response:
    body=json.loads(response.read().decode())
    if response.status != 201 or not body.get("access_token") or not body.get("refresh_token"):
        raise RuntimeError("Resposta de autenticacao invalida")
print("Autenticacao HTTPS validada para vendedor projetado; credenciais e tokens nao exibidos.")
