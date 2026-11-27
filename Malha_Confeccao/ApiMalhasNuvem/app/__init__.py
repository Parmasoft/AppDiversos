from flask import Flask, jsonify
from .config import configure_app
from .database import init_database
from .errors import ApiError
from .routes import api

def create_app(test_config=None):
    app = Flask(__name__)
    configure_app(app, test_config)
    init_database(app)
    app.register_blueprint(api)
    @app.errorhandler(ApiError)
    def api_error(error): return jsonify({"codigo": error.code, "erro": error.message}), error.status
    @app.errorhandler(404)
    def not_found(_): return jsonify({"codigo":"NAO_ENCONTRADO","erro":"Rota nao encontrada"}), 404
    @app.errorhandler(500)
    def internal_error(_): return jsonify({"codigo":"ERRO_INTERNO","erro":"Erro interno do servico"}), 500
    return app
