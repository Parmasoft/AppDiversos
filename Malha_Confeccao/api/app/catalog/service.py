"""Consultas internas preparadas para futura rota autenticada.

Não há Blueprint neste módulo: nenhuma consulta comercial está exposta por HTTP.
"""

from app.database import read_connection
from decimal import Decimal, InvalidOperation

MIN_SEARCH_LENGTH = 3
MAX_RESULTS = 30


def _term(value):
    normalized = (value or "").strip()
    if len(normalized) < MIN_SEARCH_LENGTH:
        raise ValueError("Informe pelo menos 3 caracteres.")
    return normalized.upper()


def search_clients_for_vendedor(empresa, vendedor_id, value):
    """Busca somente clientes ativos da carteira recebida do contexto servidor."""
    term = _term(value)
    pattern = f"%{term}%"
    with read_connection() as connection:
        cursor = connection.cursor()
        try:
            cursor.execute(
                """
                SELECT FIRST 30
                    C.CLI_ID,
                    C.CLI_RSOCIAL_NOME,
                    C.CLI_FANTASIA_APELIDO
                FROM TB_CLIENTE C
                WHERE C.CLI_EMPRESA = ?
                  AND C.CLI_VENDEDOR = ?
                  AND C.CLI_STATUS = 'A'
                  AND (
                    UPPER(C.CLI_RSOCIAL_NOME) LIKE ?
                    OR UPPER(C.CLI_FANTASIA_APELIDO) LIKE ?
                    OR CAST(C.CLI_ID AS VARCHAR(20)) LIKE ?
                  )
                ORDER BY C.CLI_RSOCIAL_NOME
                """,
                (empresa, vendedor_id, pattern, pattern, pattern),
            )
            return [
                {"id": row[0], "nome": row[1] or "", "fantasia": row[2] or ""}
                for row in cursor.fetchall()
            ]
        finally:
            cursor.close()


def search_products_for_authorized_client(empresa, vendedor_id, cliente_id, value):
    """Pesquisa produto somente se o cliente pertencer à carteira informada.

    Preço permanece `None`: a fórmula comercial completa ainda não foi
    homologada, portanto não será apresentado como valor real.
    """
    term = _term(value)
    pattern = f"%{term}%"
    with read_connection() as connection:
        cursor = connection.cursor()
        try:
            cursor.execute(
                """
                SELECT FIRST 30
                    P.PRD_ID,
                    P.PRD_DESCRICAO,
                    P.PRD_UN_VENDA,
                    P.PRD_COD_BARRAS
                FROM TB_PRODUTO P
                WHERE P.PRD_EMPRESA = ?
                  AND P.PRD_STATUS <> 'I'
                  AND EXISTS (
                    SELECT 1
                    FROM TB_CLIENTE C
                    WHERE C.CLI_EMPRESA = ?
                      AND C.CLI_ID = ?
                      AND C.CLI_VENDEDOR = ?
                      AND C.CLI_STATUS = 'A'
                  )
                  AND (
                    UPPER(P.PRD_DESCRICAO) LIKE ?
                    OR CAST(P.PRD_ID AS VARCHAR(20)) LIKE ?
                    OR UPPER(COALESCE(P.PRD_COD_BARRAS, '')) LIKE ?
                  )
                ORDER BY P.PRD_DESCRICAO
                """,
                (empresa, empresa, cliente_id, vendedor_id, pattern, pattern, pattern),
            )
            return [
                {
                    "id": row[0],
                    "descricao": row[1] or "",
                    "unidade": row[2] or "",
                    "codigo": row[3] or "",
                    "preco": None,
                }
                for row in cursor.fetchall()
            ]
        finally:
            cursor.close()


def list_touch_products_for_empresa(empresa):
    """Lista o catálogo habilitado para touch da empresa autenticada."""
    with read_connection() as connection:
        cursor = connection.cursor()
        try:
            cursor.execute(
                """
                SELECT P.PRD_ID, P.PRD_DESCRICAO, P.PRD_UN_VENDA,
                       P.PRD_PRECO_VENDA
                FROM TB_PRODUTO P
                JOIN TB_PROD_GRUPO G
                  ON G.PGRU_EMPRESA = P.PRD_EMPRESA
                 AND G.PGRU_ID = P.PRD_GRUPO
                WHERE P.PRD_EMPRESA = ?
                  AND COALESCE(P.PRD_STATUS, 'A') <> 'I'
                  AND G.PGRU_MOSTRAR = 'S'
                ORDER BY G.PGRU_ORDEM, P.PRD_DESCRICAO
                """,
                (empresa,),
            )
            def price(value):
                if value is None:
                    return None
                try:
                    decimal = Decimal(value)
                except (InvalidOperation, ValueError):
                    return None
                return format(decimal, "f") if decimal >= 0 else None

            return [
                {
                    "id": row[0],
                    "descricao": row[1] or "",
                    "unidade": row[2] or "",
                    # String decimal: evita arredondamento binário na API e no cliente.
                    "preco_unitario": price(row[3]),
                }
                for row in cursor.fetchall()
            ]
        finally:
            cursor.close()


def list_payment_methods_for_empresa(empresa):
    """Lista formas de pagamento ativas, sem confundi-las com prazo/condição."""
    with read_connection() as connection:
        cursor = connection.cursor()
        try:
            cursor.execute(
                """
                SELECT F.FPG_ID, F.FPG_DESCRICAO, F.FPG_DESCRICAO_RESUMIDA,
                       F.FPG_NR_PARCELAS, F.FPG_ENTRADA
                FROM TB_FORMA_PAGTO F
                WHERE F.FPG_EMPRESA = ?
                  AND F.FPG_STATUS = 'A'
                ORDER BY F.FPG_DESCRICAO
                """,
                (empresa,),
            )
            return [
                {
                    "id": row[0],
                    "descricao": row[1] or "",
                    "descricao_resumida": row[2] or "",
                    "parcelas": row[3] or 0,
                    "entrada": row[4] or "N",
                }
                for row in cursor.fetchall()
            ]
        finally:
            cursor.close()
