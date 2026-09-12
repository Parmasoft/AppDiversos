import os
from dataclasses import dataclass
from pathlib import Path


def _scopes(value):
    result = []
    for item in value.split(","):
        if not item.strip():
            continue
        company, load = item.split(":", 1)
        result.append((int(company.strip()), int(load.strip())))
    return tuple(result)


@dataclass(frozen=True)
class Config:
    cloud_url: str
    agent_token: str
    allowed_scopes: tuple
    allow_http: bool
    firebird_host: str
    firebird_port: int
    firebird_database: str
    firebird_user: str
    firebird_password: str
    firebird_charset: str
    state_database: str

    @classmethod
    def from_environment(cls):
        config = cls(
            cloud_url=os.getenv("MOTORISTA_CLOUD_URL", "").rstrip("/"),
            agent_token=os.getenv("MOTORISTA_AGENT_TOKEN", ""),
            allowed_scopes=_scopes(os.getenv("MOTORISTA_ALLOWED_SCOPES", "")),
            allow_http=os.getenv("MOTORISTA_ALLOW_HTTP", "false").lower() == "true",
            firebird_host=os.getenv("FIREBIRD_HOST", "127.0.0.1"),
            firebird_port=int(os.getenv("FIREBIRD_PORT", "3050")),
            firebird_database=os.getenv("FIREBIRD_DATABASE", ""),
            firebird_user=os.getenv("FIREBIRD_USER", ""),
            firebird_password=os.getenv("FIREBIRD_PASSWORD", ""),
            firebird_charset=os.getenv("FIREBIRD_CHARSET", "WIN1252"),
            state_database=os.getenv(
                "MOTORISTA_AGENT_STATE_DATABASE",
                str(Path(__file__).resolve().parent.parent / "instance" / "agent_state.sqlite3"),
            ),
        )
        if not config.cloud_url or not config.agent_token:
            raise RuntimeError("URL e token do agente sao obrigatorios")
        if not config.cloud_url.startswith("https://") and not config.allow_http:
            raise RuntimeError("O agente exige HTTPS; HTTP so e permitido em laboratorio")
        if not config.allowed_scopes:
            raise RuntimeError("MOTORISTA_ALLOWED_SCOPES vazio: publicacao bloqueada por seguranca")
        if not config.firebird_database or not config.firebird_user or not config.firebird_password:
            raise RuntimeError("Conexao Firebird incompleta")
        return config
