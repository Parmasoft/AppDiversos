import os
import unittest
from unittest.mock import patch

from app import create_app
from app.database import missing_database_settings


class ConfigTests(unittest.TestCase):
    def test_reports_only_missing_setting_names(self):
        missing = missing_database_settings({
            "FB_DATABASE": "E:/teste/DADOS.FDB",
            "FB_USER": "",
            "FB_PASSWORD": "",
        })
        self.assertEqual(["FB_USER", "FB_PASSWORD"], missing)

    def test_reads_environment_when_application_is_created(self):
        with patch.dict(os.environ, {
            "FB_DATABASE": "E:/teste/DADOS.FDB",
            "FB_USER": "leitura",
            "FB_PASSWORD": "segredo-de-teste",
            "MALHA_API_PORT": "5056",
        }, clear=False):
            app = create_app()
        self.assertEqual("E:/teste/DADOS.FDB", app.config["FB_DATABASE"])
        self.assertEqual("leitura", app.config["FB_USER"])
        self.assertEqual(5056, app.config["API_PORT"])
