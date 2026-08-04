from __future__ import annotations

import logging
import traceback
from threading import Event

import servicemanager
import win32service
import win32serviceutil

from app import AplicacaoParmaCloudSync, criar_aplicacao


class ParmaCloudSyncService(win32serviceutil.ServiceFramework):
    _svc_name_ = "ParmaCloudSync"
    _svc_display_name_ = "ParmaCloudSync - ParmaSoft"
    _svc_description_ = "Sincronizador de dados do ERP ParmaSoft com a nuvem."

    def __init__(self, args: list[str]) -> None:
        super().__init__(args)
        self._aplicacao: AplicacaoParmaCloudSync | None = None
        self._parada_pendente = Event()

    def SvcDoRun(self) -> None:
        try:
            self.ReportServiceStatus(win32service.SERVICE_START_PENDING)

            self._aplicacao = criar_aplicacao(usar_console=False)
            logger = self._aplicacao.logger

            logger.info("Serviço ParmaCloudSync iniciado.")

            if self._parada_pendente.is_set():
                logger.info("Serviço ParmaCloudSync parando.")
                self._aplicacao.runner.solicitar_parada()
                logger.info("Serviço ParmaCloudSync encerrado.")
                return

            logger.info("Serviço ParmaCloudSync em execução.")

            self.ReportServiceStatus(win32service.SERVICE_RUNNING)
            self._aplicacao.runner.executar_continuamente()

            logger.info("Serviço ParmaCloudSync encerrado.")

        except Exception:
            self._registrar_erro_fatal()
        finally:
            self.ReportServiceStatus(win32service.SERVICE_STOPPED)

    def SvcStop(self) -> None:
        self.ReportServiceStatus(win32service.SERVICE_STOP_PENDING)
        self._parada_pendente.set()

        if self._aplicacao is None:
            servicemanager.LogInfoMsg("Serviço ParmaCloudSync parando.")
            return

        self._aplicacao.logger.info("Serviço ParmaCloudSync parando.")
        self._aplicacao.runner.solicitar_parada()

    def _registrar_erro_fatal(self) -> None:
        mensagem = "Erro fatal no Serviço ParmaCloudSync."

        logger = self._obter_logger()
        if logger is not None:
            logger.exception(mensagem)
            return

        servicemanager.LogErrorMsg(f"{mensagem}\n{traceback.format_exc()}")

    def _obter_logger(self) -> logging.Logger | None:
        if self._aplicacao is None:
            return None

        return self._aplicacao.logger


if __name__ == "__main__":
    win32serviceutil.HandleCommandLine(ParmaCloudSyncService)
