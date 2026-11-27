import os
from pathlib import Path


def load_local_env(path=None):
    """Carrega um .env local simples sem substituir variaveis já definidas.

    O arquivo fica fora do versionamento e e opcional; em produção as variáveis
    devem ser fornecidas pelo ambiente do processo.
    """
    env_path = Path(path) if path else Path(__file__).resolve().parents[1] / ".env"
    if not env_path.is_file():
        return False

    for raw_line in env_path.read_text(encoding="utf-8-sig").splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        key = key.strip()
        if key and key not in os.environ:
            os.environ[key] = value.strip().strip('"').strip("'")
    return True
