import os
def configure_app(app, test_config=None):
    app.config.from_mapping(DATABASE_URL=os.getenv("DATABASE_URL", ""), TOKEN_HASH_SECRET=os.getenv("MALHAS_TOKEN_HASH_SECRET", ""), ACCESS_TOKEN_SECONDS=900, SESSION_SECONDS=2592000, AGENT_CLAIM_SECONDS=120)
    if test_config: app.config.update(test_config)
    if not app.config["DATABASE_URL"]: raise RuntimeError("DATABASE_URL nao configurada")
    if not app.config["TOKEN_HASH_SECRET"]: raise RuntimeError("MALHAS_TOKEN_HASH_SECRET nao configurado")
    if not app.config.get("TESTING") and not app.config["DATABASE_URL"].startswith("postgresql+psycopg://"): raise RuntimeError("Producao exige DATABASE_URL postgresql+psycopg")
