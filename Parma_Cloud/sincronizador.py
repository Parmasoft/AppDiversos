from __future__ import annotations

import logging
import math
import shutil
import sys
import time

from api import ClienteApi
from banco import BancoFirebird
from config import ConfigSincronizacaoProdutos


class SincronizadorProdutos:
    def __init__(
        self,
        banco: BancoFirebird,
        api: ClienteApi,
        config: ConfigSincronizacaoProdutos,
        logger: logging.Logger,
        mostrar_progresso: bool = True,
    ) -> None:
        self._banco = banco
        self._api = api
        self._config = config
        self._logger = logger
        self._exibir_progresso = mostrar_progresso

    @staticmethod
    def _mostrar_progresso(texto: str) -> None:
        largura = max(shutil.get_terminal_size((120, 20)).columns - 1, 40)
        texto_visivel = texto[:largura]
        sys.stdout.write("\r" + texto_visivel.ljust(largura))
        sys.stdout.flush()

    @staticmethod
    def _limpar_progresso() -> None:
        largura = max(shutil.get_terminal_size((120, 20)).columns - 1, 40)
        sys.stdout.write("\r" + (" " * largura) + "\r")
        sys.stdout.flush()

    def executar_ciclo(
        self,
        identificador: str | None = None,
    ) -> None:
        if not self._config.ativo:
            self._logger.info("Sincronização de produtos está desativada.")
            return

        if not identificador:
            raise ValueError("Identificador do cliente não foi informado.")

        inicio = time.monotonic()
        progresso_ativo = False

        try:
            produtos = self._banco.consultar_produtos(self._config.sql)

            total = len(produtos)
            tamanho_lote = self._config.tamanho_lote

            if total == 0:
                self._logger.warning(
                    "Nenhum produto encontrado. Nada será enviado neste ciclo."
                )
                return

            if tamanho_lote <= 0:
                raise ValueError(
                    "O tamanho do lote deve ser maior que zero."
                )

            total_lotes = math.ceil(total / tamanho_lote)
            total_enviado = 0

            self._logger.info(
                "Iniciando envio. Total: %s produtos | "
                "Lotes: %s | Tamanho do lote: %s.",
                total,
                total_lotes,
                tamanho_lote,
            )

            for inicio_lote in range(0, total, tamanho_lote):
                lote = produtos[inicio_lote : inicio_lote + tamanho_lote]
                numero_lote = (inicio_lote // tamanho_lote) + 1

                self._logger.info(
                    "Lote %s de %s iniciado. Registros: %s.",
                    numero_lote,
                    total_lotes,
                    len(lote),
                    extra={"somente_arquivo": True},
                )

                percentual_antes = (total_enviado / total) * 100
                if self._exibir_progresso:
                    self._mostrar_progresso(
                        "Sincronizando | "
                        f"Lote {numero_lote} de {total_lotes} | "
                        f"{total_enviado} de {total} enviados | "
                        f"{percentual_antes:.2f}%"
                    )
                    progresso_ativo = True

                self._api.enviar_produtos(
                    identificador=identificador,
                    produtos=[produto.para_dict() for produto in lote],
                )

                total_enviado += len(lote)
                percentual = (total_enviado / total) * 100

                self._logger.info(
                    "Lote %s de %s concluído. "
                    "Enviados: %s de %s. Progresso: %.2f%%.",
                    numero_lote,
                    total_lotes,
                    total_enviado,
                    total,
                    percentual,
                    extra={"somente_arquivo": True},
                )

                if self._exibir_progresso:
                    self._mostrar_progresso(
                        "Sincronizando | "
                        f"Lote {numero_lote} de {total_lotes} | "
                        f"{total_enviado} de {total} enviados | "
                        f"{percentual:.2f}%"
                    )

            duracao = time.monotonic() - inicio
            if progresso_ativo:
                self._limpar_progresso()
                progresso_ativo = False

            self._logger.info(
                "Sincronização concluída com sucesso. "
                "Total enviado: %s produtos | "
                "Lotes concluídos: %s | "
                "Duração: %.2f segundos.",
                total_enviado,
                total_lotes,
                duracao,
            )

        except Exception:
            if progresso_ativo:
                self._limpar_progresso()

            self._logger.exception("Falha durante o ciclo de sincronização.")
            raise
