"""Teste local controlado: nao inicia HTTP e executa somente SELECT em RDB$DATABASE."""

from app import create_app
from app.database import DatabaseConfigurationError, DatabaseConnectionError, check_connectivity
from app.environment import load_local_env


def main():
    load_local_env()
    app = create_app()
    with app.app_context():
        try:
            if check_connectivity():
                print("Conexao Firebird de teste confirmada em modo somente leitura.")
                return 0
        except DatabaseConfigurationError as error:
            print(f"Configuracao incompleta: {error}")
        except DatabaseConnectionError as error:
            print(f"Falha de conectividade: {error}")
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
