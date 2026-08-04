from __future__ import annotations

import json
import sys
from decimal import Decimal
from typing import Any

from config import carregar_configuracao
from logger import configurar_logger
from banco import BancoFirebird


SQL_PRODUTOS = """
SELECT
    P.PRD_EMPRESA AS EMPRESA,
    P.PRD_ID AS CODIGO,
    P.PRD_COD_BARRAS AS CODIGO_BARRAS,
    P.PRD_REFERENCIA AS REFERENCIA,
    P.PRD_DESCRICAO AS DESCRICAO,
    P.PRD_UN_VENDA AS UNIDADE,
    COALESCE(P.PRD_PRECO_VENDA, 0) AS PRECO,
    COALESCE(P.PRD_ESTOQUE, 0) AS ESTOQUE,
    P.PRD_STATUS AS STATUS,
    P.PRD_EXPORTAR AS EXPORTAR
FROM TB_PRODUTO P
WHERE P.PRD_EMPRESA = 1
  AND P.PRD_STATUS = 'A'
ORDER BY P.PRD_ID
"""


def normalizar(valor: Any) -> Any:
    if isinstance(valor, Decimal):
        return float(valor)

    if isinstance(valor, str):
        texto = valor.strip()
        return texto if texto else None

    return valor


def main() -> int:
    try:
        config = carregar_configuracao()
        logger = configurar_logger(config.log)
        banco = BancoFirebird(config.firebird, logger)

        logger.info("Gerando prévia local do JSON de produtos. Nenhum envio será feito.")

        with banco.conectar() as conexao:
            cursor = conexao.cursor()
            cursor.execute(SQL_PRODUTOS)

            colunas = [
                descricao[0].strip().lower()
                for descricao in cursor.description
            ]

            produtos = []

            for linha in cursor:
                registro = {
                    coluna: normalizar(valor)
                    for coluna, valor in zip(colunas, linha)
                }

                registro["ativo"] = registro.pop("status") == "A"
                produtos.append(registro)

        payload = {
            "cliente": config.aplicacao.identificador,
            "total": len(produtos),
            "produtos": produtos[:10],
        }

        print()
        print("=" * 100)
        print("PRÉVIA DO JSON — PRIMEIROS 10 PRODUTOS")
        print("=" * 100)
        print(json.dumps(payload, ensure_ascii=False, indent=2))
        print()
        print(f"Total de produtos ativos encontrados: {len(produtos)}")
        print("Nenhum dado foi enviado para a API.")

        logger.info(
            "Prévia concluída. Produtos ativos encontrados: %s.",
            len(produtos),
        )
        return 0

    except Exception as exc:
        print(f"Falha ao gerar a prévia do JSON: {exc}")
        return 1


if __name__ == "__main__":
    sys.exit(main())
