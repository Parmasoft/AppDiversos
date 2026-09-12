from flask import Flask

from .config import configure_app
from .database import init_database
from .errors import register_error_handlers
from .routes import api


def create_app(test_config=None):
    app = Flask(__name__)
    configure_app(app, test_config)
    init_database(app)
    app.register_blueprint(api)
    register_error_handlers(app)
    return app
