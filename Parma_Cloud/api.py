from __future__ import annotations

import logging
from typing import Any

import requests

from config import ConfigApi


class ClienteApi:
    def __init__(self, config: ConfigApi, logger: logging.Logger) -> None:
        self._config = config
        self._logger = logger
        self._session = requests.Session()

        self._session.headers.update(
            {
                "Accept": "application/json",
                "Content-Type": "application/json",
                "User-Agent": "ParmaCloudSync/1.0",
            }
        )

        if self._config.token:
            self._session.headers.update(
                {"X-Portal-Token": self._config.token}
            )

    def enviar_produtos(
        self,
        identificador: str,
        produtos: list[dict[str, Any]],
    ) -> dict[str, Any]:
        url = (
            f"{self._config.url_base}/portal/"
            f"{identificador}/sincronizar-produtos"
        )

        payload = {"produtos": produtos}

        self._logger.info(
            "Enviando lote para a API. URL: %s | Produtos: %s",
            url,
            len(produtos),
            extra={"somente_arquivo": True},
        )

        try:
            resposta = self._session.post(
                url,
                json=payload,
                timeout=self._config.timeout_segundos,
                verify=self._config.verificar_ssl,
            )
        except requests.RequestException as erro:
            raise RuntimeError(
                f"Falha de comunicação com a API: {erro}"
            ) from erro

        try:
            conteudo = resposta.json()
        except ValueError:
            conteudo = {"texto": resposta.text}

        if not resposta.ok:
            raise RuntimeError(
                f"API retornou HTTP {resposta.status_code}: {conteudo}"
            )

        if not isinstance(conteudo, dict) or conteudo.get("ok") is not True:
            raise RuntimeError(
                f"Resposta inesperada da API: {conteudo}"
            )

        self._logger.info(
            "Lote enviado com sucesso. HTTP %s | Processados: %s.",
            resposta.status_code,
            conteudo.get("produtos_processados", len(produtos)),
            extra={"somente_arquivo": True},
        )

        return conteudo
