from app import create_app
from app.environment import load_local_env


load_local_env()
app = create_app()


if __name__ == "__main__":
    app.run(
        host=app.config["API_HOST"],
        port=app.config["API_PORT"],
        debug=app.config["API_DEBUG"],
    )
