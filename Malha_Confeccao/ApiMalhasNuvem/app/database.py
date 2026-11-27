from flask import current_app
from sqlalchemy import create_engine
def init_database(app): app.extensions["malhas_engine"] = create_engine(app.config["DATABASE_URL"], future=True)
def engine(): return current_app.extensions["malhas_engine"]
