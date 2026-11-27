"""Diagnostico somente-leitura do Agente Malhas.

Executado como ``python -m agent.diagnostics`` a partir da raiz do pacote.
Nao publica snapshot, nao faz claim e nao envia ACK.
"""
import argparse
import json
import platform
import socket
import ssl
import sys
from urllib.error import HTTPError, URLError
from urllib.request import Request
from urllib.request import urlopen

from .config import Settings


def _api_auth_probe(settings):
    """Valida token/agente com payload que falha antes de qualquer transacao.

    A rota autentica primeiro e depois rejeita a ausencia de ``vendedores``
    com HTTP 400; o codigo da API atual nao abre transacao nesse caminho.
    """
    body = {"empresa": {"id": settings.empresa_id, "nome": settings.empresa_nome}, "revision": 0}
    request = Request(settings.api_url + "/api/v1/agente/vendedores/snapshot", data=json.dumps(body,separators=(",",":"),ensure_ascii=False).encode(), headers={"Authorization":"Bearer " + settings.token,"Content-Type":"application/json"}, method="POST")
    try:
        with urlopen(request, timeout=30, context=ssl.create_default_context()) as response:
            raise RuntimeError("Sonda de autenticacao recebeu HTTP %s inesperado" % response.status)
    except HTTPError as error:
        if error.code == 400:
            print("API tecnica: token e empresa validados (HTTP 400 esperado; nenhuma gravacao executada)")
            return
        if error.code == 401:
            raise RuntimeError("API tecnica recusou o token: HTTP 401") from error
        if error.code == 403:
            raise RuntimeError("API tecnica recusou a empresa configurada: HTTP 403") from error
        raise RuntimeError("API tecnica respondeu HTTP %s na sonda sem efeito colateral" % error.code) from error
    except URLError as error:
        reason = error.reason
        if isinstance(reason, socket.gaierror): raise RuntimeError("Sonda API tecnica: falha DNS") from error
        if isinstance(reason, ssl.SSLError): raise RuntimeError("Sonda API tecnica: falha TLS") from error
        if isinstance(reason, (socket.timeout, TimeoutError)): raise RuntimeError("Sonda API tecnica: timeout") from error
        raise RuntimeError("Sonda API tecnica: falha de transporte") from error
    except (socket.timeout, TimeoutError) as error:
        raise RuntimeError("Sonda API tecnica: timeout") from error


def main(argv=None):
    parser = argparse.ArgumentParser()
    parser.add_argument("--api-auth-probe", action="store_true", help="valida o token sem publicar snapshots")
    args = parser.parse_args(argv)
    print("Python:", sys.version.split()[0], "|", platform.architecture()[0])
    if sys.version_info[:2] != (3, 11) or sys.maxsize >= 2**32:
        raise RuntimeError("Requer Python 3.11 de 32 bits")
    import fdb

    print("Dependencia fdb:", getattr(fdb, "__version__", "instalada"))
    settings = Settings.from_env()
    if settings.api_url != "https://malhas.parmatech.com.br":
        print("AVISO: URL de API diferente da prevista:", settings.api_url)
    with urlopen(settings.api_url + "/api/v1/health", timeout=30, context=ssl.create_default_context()) as response:
        if response.status != 200:
            raise RuntimeError("Health HTTP %s" % response.status)
    print("API HTTPS /api/v1/health: OK (sem autenticacao e sem alterar pedidos)")
    if args.api_auth_probe:
        _api_auth_probe(settings)
    db = fdb.connect(host=settings.fb_host, port=settings.fb_port, database=settings.fb_database, user=settings.fb_user, password=settings.fb_password, charset=settings.fb_charset)
    try:
        db.begin(tpb=bytes((fdb.isc_tpb_version3, fdb.isc_tpb_read, fdb.isc_tpb_read_committed, fdb.isc_tpb_rec_version, fdb.isc_tpb_wait)))
        cursor = db.cursor()
        cursor.execute("SELECT 1 FROM RDB$DATABASE")
        cursor.fetchone()
        cursor.close()
        db.commit()
    except Exception:
        db.rollback()
        raise
    finally:
        db.close()
    print("Firebird: conexao e consulta somente-leitura OK")
    print("Diagnostico concluido. Nenhum snapshot, claim, ACK, pedido ou escrita comercial foi executado.")


if __name__ == "__main__":
    main()
