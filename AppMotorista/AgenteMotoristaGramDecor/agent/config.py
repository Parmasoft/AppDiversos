import os
from dataclasses import dataclass
from pathlib import Path
from uuid import UUID


def _scopes(value):
    result = []
    for item in value.split(","):
        item = item.strip()
        if not item:
            continue
        parts = [part.strip() for part in item.split(":")]
        if len(parts) == 1:
            result.append((int(parts[0]), None))
        elif len(parts) == 2 and all(parts):
            result.append((int(parts[0]), int(parts[1])))
        else:
            raise ValueError(
                "MOTORISTA_ALLOWED_SCOPES deve usar empresa ou empresa:carga"
            )
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
    delivery_return_enabled: bool
    delivery_return_operation_guid: str

    @classmethod
    def from_environment(cls):
        operation_guid = os.getenv("MOTORISTA_DELIVERY_RETURN_OPERATION_GUID", "").strip() or None
        if operation_guid is not None:
            try:
                operation_guid = str(UUID(operation_guid))
            except ValueError:
                raise RuntimeError("MOTORISTA_DELIVERY_RETURN_OPERATION_GUID invalida")
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
            delivery_return_enabled=os.getenv("MOTORISTA_DELIVERY_RETURN_ENABLED", "false").lower() == "true",
            delivery_return_operation_guid=operation_guid,
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
