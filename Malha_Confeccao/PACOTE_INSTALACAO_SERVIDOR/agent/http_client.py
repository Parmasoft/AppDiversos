import json
import socket
import ssl
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen

class CommunicationError(RuntimeError):
    """Erro seguro para log: nunca inclui token, cabecalhos ou corpo HTTP."""


def _transport_message(error, path):
    reason = getattr(error, "reason", error)
    if isinstance(reason, socket.gaierror):
        return "Falha DNS ao acessar a API em POST %s" % path
    if isinstance(reason, ssl.SSLError):
        return "Falha TLS ao acessar a API em POST %s" % path
    if isinstance(reason, (socket.timeout, TimeoutError)):
        return "Timeout ao acessar a API em POST %s" % path
    return "Falha de transporte ao acessar a API em POST %s" % path


class Client:
    def __init__(self,api_url,token): self.api_url=api_url; self.token=token
    def post(self,path,body):
        request=Request(self.api_url+path,data=json.dumps(body,separators=(",",":"),ensure_ascii=False).encode(),headers={"Authorization":"Bearer "+self.token,"Content-Type":"application/json"},method="POST")
        try:
            with urlopen(request,timeout=30) as response: return json.loads(response.read().decode())
        except HTTPError as error:
            raise CommunicationError("API respondeu HTTP %s em POST %s" % (error.code,path)) from error
        except (URLError,TimeoutError,socket.timeout) as error:
            raise CommunicationError(_transport_message(error,path)) from error
