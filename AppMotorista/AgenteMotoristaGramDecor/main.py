import json

from agent.config import Config
from agent.publisher import CloudClient, SnapshotSynchronizer
from agent.read_source import FirebirdSnapshotSource
from agent.state import AgentState


def main():
    config = Config.from_environment()
    source = FirebirdSnapshotSource(config)
    client = CloudClient(config.cloud_url, config.agent_token)
    state = AgentState(config.state_database)
    state.initialize()
    synchronizer = SnapshotSynchronizer(source, client, state, config.allowed_scopes)
    print(json.dumps(synchronizer.run_once(), ensure_ascii=False))


if __name__ == "__main__":
    main()
