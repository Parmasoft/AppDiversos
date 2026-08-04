from __future__ import annotations

import sys

from config import carregar_configuracao
from logger import configurar_logger
from banco import BancoFirebird


SQL_CAMPOS = """
SELECT
    TRIM(RF.RDB$FIELD_NAME) AS CAMPO,
    F.RDB$FIELD_TYPE AS TIPO_INTERNO,
    F.RDB$FIELD_SUB_TYPE AS SUBTIPO,
    F.RDB$FIELD_LENGTH AS TAMANHO,
    F.RDB$FIELD_PRECISION AS PRECISAO,
    F.RDB$FIELD_SCALE AS ESCALA,
    RF.RDB$NULL_FLAG AS OBRIGATORIO
FROM RDB$RELATION_FIELDS RF
JOIN RDB$FIELDS F
  ON F.RDB$FIELD_NAME = RF.RDB$FIELD_SOURCE
WHERE RF.RDB$RELATION_NAME = 'TB_PRODUTO'
ORDER BY RF.RDB$FIELD_POSITION
"""

SQL_EXISTE_TABELA = """
SELECT COUNT(*)
FROM RDB$RELATIONS
WHERE RDB$RELATION_NAME = 'TB_PRODUTO'
  AND COALESCE(RDB$SYSTEM_FLAG, 0) = 0
"""

TIPOS_FIREBIRD = {
    7: "SMALLINT",
    8: "INTEGER",
    10: "FLOAT",
    12: "DATE",
    13: "TIME",
    14: "CHAR",
    16: "BIGINT/NUMERIC",
    27: "DOUBLE",
    35: "TIMESTAMP",
    37: "VARCHAR",
    261: "BLOB",
}


def descrever_tipo(
    tipo_interno: int,
    subtipo: int | None,
    precisao: int | None,
    escala: int | None,
) -> str:
    tipo = TIPOS_FIREBIRD.get(tipo_interno, f"TIPO_{tipo_interno}")

    if tipo_interno in {7, 8, 16} and subtipo in {1, 2}:
        nome = "NUMERIC" if subtipo == 1 else "DECIMAL"
        casas = abs(escala or 0)
        return f"{nome}({precisao or '?'},{casas})"

    return tipo


def main() -> int:
    try:
        config = carregar_configuracao()
        logger = configurar_logger(config.log)
        banco = BancoFirebird(config.firebird, logger)

        logger.info("Iniciando diagnóstico somente leitura da TB_PRODUTO.")

        with banco.conectar() as conexao:
            cursor = conexao.cursor()

            cursor.execute(SQL_EXISTE_TABELA)
            existe = cursor.fetchone()[0]

            if not existe:
                logger.error("A tabela TB_PRODUTO não foi encontrada no banco.")
                return 2

            cursor.execute(SQL_CAMPOS)
            campos = cursor.fetchall()

        print()
        print("=" * 110)
        print("ESTRUTURA DA TB_PRODUTO")
        print("=" * 110)
        print(f"{'CAMPO':38} {'TIPO':24} {'TAM':6} {'NULL?':8}")
        print("-" * 110)

        for (
            campo,
            tipo_interno,
            subtipo,
            tamanho,
            precisao,
            escala,
            obrigatorio,
        ) in campos:
            tipo = descrever_tipo(
                tipo_interno=tipo_interno,
                subtipo=subtipo,
                precisao=precisao,
                escala=escala,
            )
            permite_nulo = "NÃO" if obrigatorio == 1 else "SIM"

            print(
                f"{str(campo):38} "
                f"{tipo:24} "
                f"{str(tamanho or ''):6} "
                f"{permite_nulo:8}"
            )

        print("-" * 110)
        print(f"Total de campos: {len(campos)}")
        print()
        logger.info(
            "Diagnóstico concluído com sucesso. Campos encontrados: %s",
            len(campos),
        )
        return 0

    except Exception as exc:
        print(f"Falha no diagnóstico da TB_PRODUTO: {exc}")
        return 1


if __name__ == "__main__":
    sys.exit(main())
