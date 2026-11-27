import os
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from agent.config import Settings
from agent.http_client import CommunicationError
from agent.instance_lock import AgentAlreadyRunningError, InstanceLock
from agent.sync import run_forever

class OperationTests(unittest.TestCase):
    def env(self,url,extra=None):
        values={"MALHAS_AGENT_API_URL":url,"MALHAS_AGENT_TOKEN":"token-de-teste","MALHAS_AGENT_EMPRESA_ID":"1","MALHAS_AGENT_EMPRESA_NOME":"Empresa","FB_DATABASE":"C:/teste.fdb","FB_USER":"usuario","FB_PASSWORD":"senha"}
        if extra: values.update(extra)
        return values

    def test_rejects_external_http_and_allows_explicit_loopback_test(self):
        with patch.dict(os.environ,self.env("http://malhas.parmatech.com.br"),clear=True):
            with self.assertRaisesRegex(RuntimeError,"exige HTTPS"): Settings.from_env()
        with patch.dict(os.environ,self.env("http://127.0.0.1:5057",{"MALHAS_AGENT_ALLOW_INSECURE_LOCAL_TESTS":"1"}),clear=True):
            self.assertEqual("http://127.0.0.1:5057",Settings.from_env().api_url)

    def test_prevents_two_instances_for_same_state(self):
        with tempfile.TemporaryDirectory() as folder:
            path=str(Path(folder)/"state.db.lock")
            first=InstanceLock(path).acquire()
            try:
                with self.assertRaises(AgentAlreadyRunningError): InstanceLock(path).acquire()
            finally: first.release()

    def test_retries_after_communication_failure_then_stops_cleanly(self):
        attempts=[]; stop=[False,False,False,True]
        def reader(*_): return ([],[],[],[])
        class Client: pass
        class SettingsForLoop: retry_seconds=0
        def sleep(_): pass
        def should_stop(): return stop.pop(0)
        with patch("agent.sync.run_once",side_effect=[CommunicationError("fora"),None]) as run:
            run_forever(SettingsForLoop(),object(),reader,Client(),sleep,should_stop)
        self.assertEqual(2,run.call_count)
