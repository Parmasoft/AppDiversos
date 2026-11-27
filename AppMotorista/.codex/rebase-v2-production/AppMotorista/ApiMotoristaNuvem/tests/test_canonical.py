import json
import unittest
from pathlib import Path

from app.canonical import CanonicalizationError, canonical_bytes, semantic_hash


class CanonicalizationTest(unittest.TestCase):
    def test_known_vectors(self):
        vector_path = (
            Path(__file__).resolve().parent.parent
            / "contracts"
            / "v1"
            / "canonicalization-v1-vectors.json"
        )
        vectors = json.loads(vector_path.read_text(encoding="utf-8"))
        for vector in vectors:
            with self.subTest(vector=vector["name"]):
                self.assertEqual(
                    vector["canonical_utf8"].encode("utf-8"),
                    canonical_bytes(vector["payload"]),
                )
                self.assertEqual(vector["sha256"], semantic_hash(vector["payload"]))

    def test_publication_metadata_is_excluded(self):
        first = {"contrato_versao": 1, "valor": 7, "snapshot_revision": 1}
        second = {
            "contrato_versao": 1,
            "valor": 7,
            "snapshot_revision": 99,
            "snapshot_id": "outro",
            "semantic_hash": "f" * 64,
            "gerado_em": "outro",
        }
        self.assertEqual(semantic_hash(first), semantic_hash(second))

    def test_non_integer_json_number_is_rejected(self):
        with self.assertRaises(CanonicalizationError):
            canonical_bytes({"contrato_versao": 1, "valor": 1.5})


if __name__ == "__main__":
    unittest.main()
