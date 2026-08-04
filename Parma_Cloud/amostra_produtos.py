from __future__ import annotations

import sys
from decimal import Decimal
from typing import Any

from config import carregar_configuracao
from logger import configurar_logger
from banco import BancoFirebird


SQL_EMPRESAS = """
SELECT
    PRD_EMPRESA,
    COUNT(*) AS TOTAL
FROM TB_PRODUTO
GROUP BY PRD_EMPRESA
ORDER BY PRD_EMPRESA
"""

SQL_STATUS = """
SELECT
    COALESCE(PRD_STATUS, '<NULL>') AS STATUS,
    COUNT(*) AS TOTAL
FROM TB_PRODUTO
GROUP BY PRD_STATUS
ORDER BY PRD_STATUS
"""

SQL_AMOSTRA = """
SELECT FIRST 20
    PRD_EMPRESA,
    PRD_ID,
    PRD_STATUS,
    PRD_COD_BARRAS,
    PRD_REFERENCIA,
    PRD_DESCRICAO,
    PRD_UN_VENDA,
    PRD_PRECO_VENDA,
    PRD_PRECO_TABLET,
    PRD_ESTOQUE,
    PRD_EXPORTAR,
    PRD_DT_CADASTRO
FROM TB_PRODUTO
ORDER BY PRD_EMPRESA, PRD_ID
"""


def formatar(valor: Any) -> str:
    if valor is None:
        return "<NULL>"

    if isinstance(valor, Decimal):
        return format(valor, "f")

    texto = str(valor).strip()
    return texto or "<VAZIO>"


def imprimir_tabela(titulo: str, colunas: list[str], linhas: list[tuple[Any, ...]]) -> None:
    print()
    print("=" * 150)
    print(titulo)
    print("=" * 150)

    larguras = [len(coluna) for coluna in colunas]
    valores_formatados: list[list[str]] = []

    for linha in linhas:
        valores = [formatar(valor) for valor in linha]
        valores_formatados.append(valores)

        for indice, valor in enumerate(valores):
            larguras[indice] = min(max(larguras[indice], len(valor)), 45)

    cabecalho = " | ".join(
        coluna.ljust(larguras[indice])
        for indice, coluna in enumerate(colunas)
    )
    print(cabecalho)
    print("-" * min(len(cabecalho), 150))

    for valores in valores_formatados:
        print(
            " | ".join(
                valor[:larguras[indice]].ljust(larguras[indice])
                for indice, valor in enumerate(valores)
            )
        )


def main() -> int:
    try:
        config = carregar_configuracao()
        logger = configurar_logger(config.log)
        banco = BancoFirebird(config.firebird, logger)

        logger.info("Iniciando diagnóstico de amostra dos produtos, somente leitura.")

        with banco.conectar() as conexao:
            cursor = conexao.cursor()

            cursor.execute(SQL_EMPRESAS)
            empresas = cursor.fetchall()

            cursor.execute(SQL_STATUS)
            status = cursor.fetchall()

            cursor.execute(SQL_AMOSTRA)
            amostra = cursor.fetchall()

        imprimir_tabela(
            "PRODUTOS POR EMPRESA",
            ["EMPRESA", "TOTAL"],
            empresas,
        )

        imprimir_tabela(
            "PRODUTOS POR STATUS",
            ["STATUS", "TOTAL"],
            status,
        )

        imprimir_tabela(
            "AMOSTRA DOS PRIMEIROS 20 PRODUTOS",
            [
                "EMPRESA",
                "ID",
                "STATUS",
                "COD_BARRAS",
                "REFERENCIA",
                "DESCRICAO",
                "UN_VENDA",
                "PRECO_VENDA",
                "PRECO_TABLET",
                "ESTOQUE",
                "EXPORTAR",
                "DT_CADASTRO",
            ],
            amostra,
        )

        print()
        print("Nenhum dado foi alterado e nenhuma informação foi enviada para a API.")
        logger.info("Diagnóstico de amostra concluído com sucesso.")
        return 0

    except Exception as exc:
        print(f"Falha no diagnóstico da amostra: {exc}")
        return 1


if __name__ == "__main__":
    sys.exit(main())
