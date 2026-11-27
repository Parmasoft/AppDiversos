#!/usr/bin/env python3
"""Provisiona o bootstrap da empresa e digest de token do Agente; nunca imprime o token."""
import hashlib
import hmac
import os
import sys
from pathlib import Path

import psycopg

def main():
    if len(sys.argv) != 4:
        raise SystemExit("uso: provision-agent-credential.py EMPRESA_ID NOME EMPRESA_GUID")
    company_code=int(sys.argv[1]); company_name=sys.argv[2]; agent_guid=sys.argv[3]
    token_path=Path(os.environ["MALHAS_AGENT_TOKEN_FILE"])
    token=token_path.read_text(encoding="utf-8").strip()
    secret=os.environ["MALHAS_TOKEN_HASH_SECRET"]
    if len(token) < 32: raise RuntimeError("token tecnico ausente ou invalido")
    digest=hmac.new(secret.encode(),token.encode(),hashlib.sha256).hexdigest()
    database_url=os.environ["DATABASE_URL"].replace("postgresql+psycopg://","postgresql://",1)
    with psycopg.connect(database_url) as connection:
        with connection.cursor() as cursor:
            cursor.execute("SELECT id FROM malhas_empresa WHERE empresa_id=%s",(company_code,))
            row=cursor.fetchone()
            if row: company_id=row[0]
            else:
                cursor.execute("INSERT INTO malhas_empresa (empresa_id,nome,active) VALUES (%s,%s,true) RETURNING id",(company_code,company_name))
                company_id=cursor.fetchone()[0]
            cursor.execute("SELECT 1 FROM malhas_agente_credencial WHERE empresa_id=%s AND agent_guid=%s",(company_id,agent_guid))
            if cursor.fetchone(): raise RuntimeError("agent_guid ja provisionado")
            cursor.execute("INSERT INTO malhas_agente_credencial (empresa_id,agent_guid,token_digest,active) VALUES (%s,%s,%s,true)",(company_id,agent_guid,digest))
    token_path.unlink()
    print("Credencial tecnica provisionada; somente o digest foi persistido.")

if __name__ == "__main__": main()
