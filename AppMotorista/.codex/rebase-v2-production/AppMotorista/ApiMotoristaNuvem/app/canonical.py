import hashlib
import json
import math


CANONICALIZATION_VERSION = 1
PUBLICATION_FIELDS = frozenset(
    {"snapshot_id", "snapshot_revision", "semantic_hash", "gerado_em"}
)


class CanonicalizationError(ValueError):
    pass


def _validate_numbers(value, path="$"):
    if value is None or isinstance(value, (str, bool, int)):
        return
    if isinstance(value, float):
        if not math.isfinite(value):
            raise CanonicalizationError(f"{path}: numero nao finito")
        raise CanonicalizationError(
            f"{path}: numeros nao inteiros devem ser representados como strings"
        )
    if isinstance(value, list):
        for index, item in enumerate(value):
            _validate_numbers(item, f"{path}[{index}]")
        return
    if isinstance(value, dict):
        for key, item in value.items():
            if not isinstance(key, str):
                raise CanonicalizationError(f"{path}: chave JSON deve ser string")
            _validate_numbers(item, f"{path}.{key}")
        return
    raise CanonicalizationError(f"{path}: tipo JSON nao suportado")


def semantic_document(payload):
    if not isinstance(payload, dict):
        raise CanonicalizationError("payload deve ser objeto JSON")
    semantic = {key: value for key, value in payload.items() if key not in PUBLICATION_FIELDS}
    _validate_numbers(semantic)
    return semantic


def canonical_bytes(payload):
    return json.dumps(
        semantic_document(payload),
        ensure_ascii=False,
        sort_keys=True,
        separators=(",", ":"),
        allow_nan=False,
    ).encode("utf-8")


def semantic_hash(payload):
    return hashlib.sha256(canonical_bytes(payload)).hexdigest()
