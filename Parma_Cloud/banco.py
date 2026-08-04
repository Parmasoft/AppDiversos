from __future__ import annotations

import logging
from contextlib import contextmanager
from typing import Any, Iterator

import fdb

from config import ConfigFirebird
from modelos import Produto


class BancoFirebird:
    def __init__(self, config: ConfigFirebird, logger: logging.Logger) -> None:
        self._config = config
        self._logger = logger

    @contextmanager
    def conectar(self) -> Iterator[fdb.Connection]:
        conexao = None

        try:
            conexao = fdb.connect(
                dsn=self._config.dsn,
                user=self._config.usuario,
                password=self._config.senha,
                charset=self._config.charset,
            )
            yield conexao
        finally:
            if conexao is not None:
                conexao.close()

    def testar_conexao(self) -> None:
        self._logger.info("Testando conexão com o Firebird: %s", self._config.dsn)

        with self.conectar() as conexao:
            cursor = conexao.cursor()
            cursor.execute("SELECT 1 FROM RDB$DATABASE")
            resultado = cursor.fetchone()

        if not resultado or resultado[0] != 1:
            raise RuntimeError("O Firebird respondeu, mas o teste retornou resultado inválido.")

        self._logger.info("Conexão com o Firebird validada.")

    def consultar_produtos(self, sql: str) -> list[Produto]:
        self._logger.info("Iniciando consulta de produtos no Firebird.")

        with self.conectar() as conexao:
            cursor = conexao.cursor()
            cursor.execute(sql)

            nomes_colunas = [
                descricao[0].strip().lower() for descricao in cursor.description
            ]

            produtos: list[Produto] = []

            for linha in cursor:
                registro: dict[str, Any] = dict(zip(nomes_colunas, linha))
                produtos.append(Produto.de_registro(registro))

        self._logger.info("Consulta concluída. Produtos encontrados: %s", len(produtos))
        return produtos
