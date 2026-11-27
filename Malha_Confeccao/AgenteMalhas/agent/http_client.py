import json
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen

class CommunicationError(RuntimeError): pass
class Client:
    def __init__(self,api_url,token): self.api_url=api_url; self.token=token
    def post(self,path,body):
        request=Request(self.api_url+path,data=json.dumps(body,separators=(",",":"),ensure_ascii=False).encode(),headers={"Authorization":"Bearer "+self.token,"Content-Type":"application/json"},method="POST")
        try:
            with urlopen(request,timeout=30) as response: return json.loads(response.read().decode())
        except HTTPError as error:
            raise CommunicationError("API recusou snapshot: HTTP %s" % error.code) from error
        except (URLError,TimeoutError) as error:
            raise CommunicationError("Falha de comunicacao com a API") from error
