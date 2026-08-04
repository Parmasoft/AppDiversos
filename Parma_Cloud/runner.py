from __future__ import annotations

import logging
from datetime import datetime, timedelta
from threading import Event
from typing import Protocol


class SincronizadorCiclo(Protocol):
    def executar_ciclo(self, identificador: str | None = None) -> None:
        ...


class RunnerSincronizacao:
    def __init__(
        self,
        sincronizador: SincronizadorCiclo,
        identificador: str,
        intervalo_segundos: int,
        logger: logging.Logger,
    ) -> None:
        self._sincronizador = sincronizador
        self._identificador = identificador
        self._intervalo_segundos = intervalo_segundos
        self._logger = logger
        self._parada_solicitada = Event()

    def solicitar_parada(self) -> None:
        self._parada_solicitada.set()

    def executar_uma_vez(self) -> None:
        self._sincronizador.executar_ciclo(identificador=self._identificador)

    def executar_continuamente(self) -> None:
        if not self._intervalo_segundos:
            raise ValueError("Intervalo de sincronização não foi configurado.")

        self._logger.info(
            "Modo contínuo iniciado. Intervalo: %s segundos.",
            self._intervalo_segundos,
        )

        while not self._parada_solicitada.is_set():
            try:
                self.executar_uma_vez()
            except Exception:
                self._logger.warning(
                    "O ciclo falhou. Uma nova tentativa ocorrerá "
                    "no próximo intervalo."
                )

            if self._parada_solicitada.is_set():
                break

            proxima_execucao = datetime.now() + timedelta(
                seconds=self._intervalo_segundos
            )
            self._logger.info(
                "Aguardando próximo ciclo. Intervalo: %s segundos. "
                "Próxima execução prevista: %s.",
                self._intervalo_segundos,
                proxima_execucao.strftime("%Y-%m-%d %H:%M:%S"),
            )
            self._parada_solicitada.wait(self._intervalo_segundos)
