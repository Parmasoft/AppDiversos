from __future__ import annotations

import argparse
import sys

from app import AplicacaoParmaCloudSync, criar_aplicacao


def criar_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="ParmaCloudSync - sincronização entre ERP Firebird e Portal ParmaSoft."
    )
    parser.add_argument(
        "--testar-conexao",
        action="store_true",
        help="Testa somente a conexão com o Firebird e encerra.",
    )
    parser.add_argument(
        "--uma-vez",
        action="store_true",
        help="Executa um único ciclo de sincronização e encerra.",
    )
    return parser


def main() -> int:    
    argumentos = criar_parser().parse_args()
    aplicacao: AplicacaoParmaCloudSync | None = None

    try:
        aplicacao = criar_aplicacao(usar_console=True)
        config = aplicacao.config
        logger = aplicacao.logger
        banco = aplicacao.banco
        runner = aplicacao.runner

        logger.info("ParmaCloudSync iniciado. Cliente: %s", config.aplicacao.cliente)

        if argumentos.testar_conexao:
            banco.testar_conexao()
            logger.info("Teste de conexão concluído com sucesso.")
            return 0

        if argumentos.uma_vez:
            runner.executar_uma_vez()
            return 0

        runner.executar_continuamente()
        return 0

    except KeyboardInterrupt:
        if aplicacao is not None:
            aplicacao.runner.solicitar_parada()
        print("\nParmaCloudSync encerrado pelo usuário.")
        return 0
    except Exception as exc:
        print(f"Falha ao iniciar o ParmaCloudSync: {exc}")
        return 1


if __name__ == "__main__":
    sys.exit(main())
