import os
from pathlib import Path
from urllib.parse import urlparse
from dataclasses import dataclass

@dataclass(frozen=True)
class Settings:
    api_url: str; token: str; empresa_id: int; empresa_nome: str
    fb_host: str; fb_port: int; fb_database: str; fb_user: str; fb_password: str; fb_charset: str
    state_path: str; retry_seconds: int; log_path: str; log_max_bytes: int; log_backup_count: int; stop_file: str

    @classmethod
    def from_env(cls):
        values={"api_url":os.getenv("MALHAS_AGENT_API_URL","").rstrip("/"),"token":os.getenv("MALHAS_AGENT_TOKEN","").strip(),"empresa_nome":os.getenv("MALHAS_AGENT_EMPRESA_NOME","").strip(),"fb_database":os.getenv("FB_DATABASE","").strip(),"fb_user":os.getenv("FB_USER","").strip(),"fb_password":os.getenv("FB_PASSWORD","")}
        if not all(values.values()): raise RuntimeError("Variaveis obrigatorias do Agente Malhas nao configuradas")
        parsed=urlparse(values["api_url"])
        insecure_local=os.getenv("MALHAS_AGENT_ALLOW_INSECURE_LOCAL_TESTS","") == "1"
        if parsed.scheme == "https" and parsed.hostname: pass
        elif parsed.scheme == "http" and parsed.hostname in {"localhost","127.0.0.1","::1"} and insecure_local: pass
        else: raise RuntimeError("MALHAS_AGENT_API_URL exige HTTPS; HTTP so e permitido para teste local explicito")
        try: empresa_id=int(os.environ["MALHAS_AGENT_EMPRESA_ID"])
        except (KeyError,ValueError): raise RuntimeError("MALHAS_AGENT_EMPRESA_ID invalido")
        state_path=os.getenv("MALHAS_AGENT_STATE_PATH","state.db")
        return cls(values["api_url"],values["token"],empresa_id,values["empresa_nome"],os.getenv("FB_HOST","localhost"),int(os.getenv("FB_PORT","3050")),values["fb_database"],values["fb_user"],values["fb_password"],os.getenv("FB_CHARSET","WIN1252"),state_path,int(os.getenv("MALHAS_AGENT_RETRY_SECONDS","10")),os.getenv("MALHAS_AGENT_LOG_PATH",str(Path(state_path).with_name("agente-malhas.log"))),int(os.getenv("MALHAS_AGENT_LOG_MAX_BYTES",str(5*1024*1024))),int(os.getenv("MALHAS_AGENT_LOG_BACKUP_COUNT","5")),os.getenv("MALHAS_AGENT_STOP_FILE",str(Path(state_path).with_name("stop.request"))))
