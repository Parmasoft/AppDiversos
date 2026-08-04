from __future__ import annotations

from datetime import date, datetime
from dataclasses import dataclass
from decimal import Decimal
from typing import Any


@dataclass(frozen=True)
class Produto:
    codigo: int
    descricao: str
    unidade: str | None = None
    codigo_barras: str | None = None
    estoque: Decimal | float | int | None = None
    custo: Decimal | float | int | None = None
    preco: Decimal | float | int | None = None
    data_ultima_compra: date | datetime | str | None = None
    nota_ultima_compra: str | None = None
    serie_ultima_compra: str | None = None
    ativo: bool = True

    def para_dict(self) -> dict[str, Any]:
        return {
            "produto": self.codigo,
            "descricao": self.descricao,
            "unidade": self.unidade,
            "codigo_barras": self.codigo_barras,
            "estoque": _numero_json(self.estoque),
            "custo": _numero_json_ou_none(self.custo),
            "preco": _numero_json(self.preco),
            "data_ultima_compra": _data_json_ou_none(self.data_ultima_compra),
            "nota_ultima_compra": self.nota_ultima_compra,
            "serie_ultima_compra": self.serie_ultima_compra,
        }

    @classmethod
    def de_registro(cls, registro: dict[str, Any]) -> "Produto":
        normalizado = {str(k).lower(): v for k, v in registro.items()}

        return cls(
            codigo=int(normalizado["codigo"]),
            descricao=str(normalizado["descricao"]).strip(),
            unidade=_texto_ou_none(normalizado.get("unidade")),
            codigo_barras=_texto_ou_none(normalizado.get("codigo_barras")),
            estoque=normalizado.get("estoque"),
            custo=normalizado.get("custo"),
            preco=normalizado.get("preco"),
            data_ultima_compra=normalizado.get("data_ultima_compra"),
            nota_ultima_compra=_texto_ou_none(normalizado.get("nota_ultima_compra")),
            serie_ultima_compra=_texto_ou_none(normalizado.get("serie_ultima_compra")),
            ativo=_para_bool(normalizado.get("ativo", True)),
        )


def _numero_json(valor: Decimal | float | int | None) -> float:
    if valor is None:
        return 0.0

    if isinstance(valor, Decimal):
        return float(valor)

    return float(valor)


def _numero_json_ou_none(valor: Decimal | float | int | None) -> float | None:
    if valor is None:
        return None

    if isinstance(valor, Decimal):
        return float(valor)

    return float(valor)


def _texto_ou_none(valor: Any) -> str | None:
    if valor is None:
        return None

    texto = str(valor).strip()
    return texto or None


def _data_json_ou_none(valor: date | datetime | str | None) -> str | None:
    if valor is None:
        return None

    if isinstance(valor, datetime):
        return valor.isoformat(timespec="seconds")

    if isinstance(valor, date):
        return valor.isoformat()

    return _texto_ou_none(valor)


def _para_bool(valor: Any) -> bool:
    if isinstance(valor, bool):
        return valor

    if valor is None:
        return True

    texto = str(valor).strip().upper()
    return texto not in {"0", "N", "NAO", "NÃO", "F", "FALSE", "INATIVO"}
