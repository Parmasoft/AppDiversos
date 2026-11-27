import json
import argparse

from agent.config import Config
from agent.publisher import CloudClient, SnapshotSynchronizer
from agent.read_source import FirebirdSnapshotSource
from agent.return_source import FirebirdDeliveryReturnSource
from agent.return_sync import DeliveryReturnSynchronizer, canonical_uuid
from agent.state import AgentState


def parse_arguments():
    parser = argparse.ArgumentParser()
    parser.add_argument("--return-only", action="store_true")
    parser.add_argument("--operation-guid")
    args = parser.parse_args()
    if args.return_only != bool(args.operation_guid):
        parser.error("--return-only exige --operation-guid, e vice-versa")
    if args.operation_guid:
        try:
            canonical_uuid(args.operation_guid, "operation_guid")
        except RuntimeError as error:
            parser.error(str(error))
    return args


def run_return_only(config, client, state, operation_guid):
    if not config.delivery_return_enabled:
        raise RuntimeError("Modo return-only exige retorno explicitamente habilitado")
    companies = {company for company, _load in config.allowed_scopes}
    if not companies:
        raise RuntimeError("Modo return-only exige empresa autorizada")
    return DeliveryReturnSynchronizer(
        FirebirdDeliveryReturnSource(config), client, state, operation_guid,
        allowed_companies=companies,
    ).run_once()


def run_automatic(config, client, state):
    """Runs the independent publication and return flows for one agent round.

    Both outcomes are deliberately captured.  The launcher retries the next
    round, but a transient failure on one direction must not suppress safe work
    on the other direction.
    """
    result = {"publicacoes": [], "retornos": [], "erros": []}
    try:
        source = FirebirdSnapshotSource(config)
        result["publicacoes"] = SnapshotSynchronizer(
            source, client, state, config.allowed_scopes
        ).run_once()
    except Exception as error:
        result["erros"].append({"fluxo": "publicacao", "erro": str(error)})

    if config.delivery_return_enabled:
        try:
            companies = {company for company, _load in config.allowed_scopes}
            if not companies:
                raise RuntimeError("Retorno automatico exige empresa autorizada")
            result["retornos"] = DeliveryReturnSynchronizer(
                FirebirdDeliveryReturnSource(config),
                client,
                state,
                config.delivery_return_operation_guid,
                allowed_companies=companies,
            ).run_once()
        except Exception as error:
            result["erros"].append({"fluxo": "retorno", "erro": str(error)})
    return result


def main():
    args = parse_arguments()
    config = Config.from_environment()
    client = CloudClient(config.cloud_url, config.agent_token)
    state = AgentState(config.state_database)
    state.initialize()
    if args.return_only:
        print(json.dumps({"publicacoes": [], "retornos": run_return_only(
            config, client, state, args.operation_guid,
        )}, ensure_ascii=False))
        return

    result = run_automatic(config, client, state)
    print(json.dumps(result, ensure_ascii=False))
    return 1 if result["erros"] else 0


if __name__ == "__main__":
    raise SystemExit(main())
