from __future__ import annotations

import logging
from dataclasses import dataclass

from api import ClienteApi
from banco import BancoFirebird
from config import Configuracao, carregar_configuracao
from logger import configurar_logger
from runner import RunnerSincronizacao
from sincronizador import SincronizadorProdutos


@dataclass(frozen=True)
class AplicacaoParmaCloudSync:
    config: Configuracao
    logger: logging.Logger
    banco: BancoFirebird
    runner: RunnerSincronizacao


def criar_aplicacao(usar_console: bool = True) -> AplicacaoParmaCloudSync:
    config = carregar_configuracao()
    logger = configurar_logger(config.log, usar_console=usar_console)

    banco = BancoFirebird(config.firebird, logger)
    api = ClienteApi(config.api, logger)
    sincronizador = SincronizadorProdutos(
        banco=banco,
        api=api,
        config=config.sincronizacao_produtos,
        logger=logger,
        mostrar_progresso=usar_console,
    )
    runner = RunnerSincronizacao(
        sincronizador=sincronizador,
        identificador=config.aplicacao.identificador,
        intervalo_segundos=config.aplicacao.intervalo_segundos,
        logger=logger,
    )

    return AplicacaoParmaCloudSync(
        config=config,
        logger=logger,
        banco=banco,
        runner=runner,
    )
