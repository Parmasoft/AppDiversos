import logging
import time
from datetime import datetime

from flask import Flask, jsonify, g, request

from .config import Config
from .health.routes import blueprint as health_blueprint
from .auth.routes import blueprint as auth_blueprint
from .catalog.routes import blueprint as catalog_blueprint
from .orders.routes import blueprint as orders_blueprint


def create_app(config_override=None):
    app = Flask(__name__)
    app.config.from_mapping(Config.from_environment())
    if config_override:
        app.config.update(config_override)

    app.register_blueprint(health_blueprint)
    app.register_blueprint(auth_blueprint)
    app.register_blueprint(catalog_blueprint)
    app.register_blueprint(orders_blueprint)

    @app.before_request
    def start_request_timer():
        g.request_started_at = time.perf_counter()

    @app.after_request
    def log_response(response):
        elapsed = (time.perf_counter() - getattr(g, "request_started_at", time.perf_counter())) * 1000
        print(
            f"[{datetime.now().strftime('%H:%M:%S')}] "
            f"{request.method} {request.path} -> HTTP {response.status_code} ({elapsed:.0f} ms)",
            flush=True,
        )
        return response

    @app.errorhandler(Exception)
    def internal_error(error):
        app.logger.exception("Erro interno não sensível em %s %s", request.method, request.path)
        return jsonify({"erro": "Erro interno da API."}), 500

    app.logger.setLevel(logging.INFO)

    @app.errorhandler(404)
    def not_found(_error):
        return jsonify({"erro": "Rota nao encontrada."}), 404

    return app
