import os


def _integer_set(value):
    try:
        return frozenset(int(item.strip()) for item in value.split(",") if item.strip())
    except ValueError as error:
        raise RuntimeError("MOTORISTA_DELIVERY_DENIED_LOAD_IDS invalida") from error


def configure_app(app, test_config=None):
    app.config.from_mapping(
        DATABASE_URL=os.getenv("DATABASE_URL", ""),
        TOKEN_HASH_SECRET=os.getenv("MOTORISTA_TOKEN_HASH_SECRET", ""),
        BIND_HOST=os.getenv("MOTORISTA_BIND_HOST", "127.0.0.1"),
        BIND_PORT=int(os.getenv("MOTORISTA_BIND_PORT", "8091")),
        SNAPSHOT_LEASE_SECONDS=int(os.getenv("MOTORISTA_SNAPSHOT_LEASE_SECONDS", "60")),
        MOBILE_ACCESS_TOKEN_SECONDS=int(os.getenv("MOTORISTA_MOBILE_ACCESS_TOKEN_SECONDS", "900")),
        MOBILE_SESSION_SECONDS=int(os.getenv("MOTORISTA_MOBILE_SESSION_SECONDS", "2592000")),
        DELIVERY_RETURN_CLAIM_SECONDS=int(os.getenv("MOTORISTA_DELIVERY_RETURN_CLAIM_SECONDS", "120")),
        DELIVERY_DENIED_LOAD_IDS=_integer_set(os.getenv("MOTORISTA_DELIVERY_DENIED_LOAD_IDS", "530")),
    )
    if test_config:
        app.config.update(test_config)
    if not app.config["TOKEN_HASH_SECRET"]:
        raise RuntimeError("MOTORISTA_TOKEN_HASH_SECRET nao configurado")
    if not app.config["DATABASE_URL"]:
        raise RuntimeError("DATABASE_URL nao configurada")
    if not app.config.get("TESTING") and not app.config["DATABASE_URL"].startswith(
        "postgresql+psycopg://"
    ):
        raise RuntimeError("Producao exige DATABASE_URL postgresql+psycopg")
    if app.config["SNAPSHOT_LEASE_SECONDS"] < 10:
        raise RuntimeError("MOTORISTA_SNAPSHOT_LEASE_SECONDS deve ser no minimo 10")
    if app.config["MOBILE_ACCESS_TOKEN_SECONDS"] < 60:
        raise RuntimeError("MOTORISTA_MOBILE_ACCESS_TOKEN_SECONDS deve ser no minimo 60")
    if app.config["MOBILE_SESSION_SECONDS"] < app.config["MOBILE_ACCESS_TOKEN_SECONDS"]:
        raise RuntimeError("MOTORISTA_MOBILE_SESSION_SECONDS deve cobrir o access token")
