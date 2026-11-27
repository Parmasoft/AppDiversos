from copy import deepcopy
from uuid import NAMESPACE_URL, uuid4, uuid5

from app.canonical import semantic_hash


def snapshot(snapshot_id=None, suffix="A", revision=1):
    body = {
        "contrato_versao": 1,
        "snapshot_id": snapshot_id or str(uuid4()),
        "snapshot_revision": revision,
        "semantic_hash": "0" * 64,
        "gerado_em": "2026-09-03T15:00:00+00:00",
        "manifesto": {
            "id": 12, "guid": f"MAN-{suffix}", "versao": 1, "status": "L",
            "conferencia": "C", "gerado_em": "2026-09-03T14:00:00+00:00",
            "liberado_em": "2026-09-03T14:05:00+00:00"
        },
        "carga": {
            "id": 900, "descricao": "Carga controlada", "saida_data": "2026-09-03",
            "saida_hora": "08:00:00", "placa": "TESTE"
        },
        "motorista": {"guid": f"MOT-{suffix}", "nome": f"Motorista {suffix}"},
        "origem": {"empresa": 10, "nome_fantasia": "Empresa controlada"},
        "rota": [],
        "paradas": [
            {
                "parada": 31,
                "guid": f"PAR-{suffix}",
                "ordem": {"planejada": 1, "sugerida": 1, "realizada": None},
                "status": "P",
                "endereco": {"logradouro": "Rua teste", "cidade": "Teste", "uf": "MG"},
                "cliente": {
                    "id": 51,
                    "nome": f"Cliente {suffix}",
                    "email_notificacao": f"cliente-{suffix.lower()}@example.test",
                    "aceita_email": True,
                },
                "pedidos": [
                    {
                        "pedido": 1001, "carga_item_sequencia": 1,
                        "ordem_entrega_origem": 1, "status": "P"
                    }
                ],
                "ocorrencias": [
                    {
                        "ocorrencia": 61, "guid": occurrence_guid(suffix), "leitura_origem": 1,
                        "cliente": 51, "pedido": 1001, "item_pedido": 1, "produto": 77,
                        "tipo": "C", "codigo": "CONTROLADO", "rolo_id": None,
                        "quantidade": "1.0000", "status": "P", "versao_registro": 1
                    }
                ],
            }
        ],
        "quantidade_ocorrencias": 1,
    }
    body["semantic_hash"] = semantic_hash(body)
    return body


def rehash(body):
    body["semantic_hash"] = semantic_hash(body)
    return body


def occurrence_guid(suffix):
    return str(uuid5(NAMESPACE_URL, f"app-motorista-occurrence-{suffix}"))


def clone(value):
    return deepcopy(value)
