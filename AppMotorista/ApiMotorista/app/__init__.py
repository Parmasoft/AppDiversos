from flask import Flask, jsonify

from .auth.routes import blueprint as auth_blueprint
from .viagens.routes import blueprint as viagens_blueprint


def create_app(config_override=None):
    app = Flask(__name__)
    app.config.from_object("app.config.Config")
    if config_override:
        app.config.update(config_override)

    app.register_blueprint(auth_blueprint)
    app.register_blueprint(viagens_blueprint)

    @app.get("/health")
    def health():
        return jsonify({"status": "ok"})

    return app

