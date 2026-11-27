import queue
import threading
import unittest

from ui.main_window import MainWindow


class InterfaceThreadingTest(unittest.TestCase):
    def _janela_worker(self):
        app = object.__new__(MainWindow)
        app._em_thread_trabalho = True
        app._thread_trabalho = threading.current_thread()
        app._fila_interface = queue.Queue()
        app._dados_execucao = {
            "somente_10": True,
            "limpar_destino": False,
            "continuar_erro": True,
            "filtro_produtos": "36 meses",
            "conexoes": {"origem": {"banco": "origem"}},
        }
        return app

    def test_worker_publica_log_na_fila_sem_tocar_no_tk(self):
        app = self._janela_worker()
        self.assertTrue(app._publicar_interface("log", texto="processando"))
        self.assertEqual(app._fila_interface.get_nowait(), ("log", {"texto": "processando"}))

    def test_worker_usa_snapshot_dos_parametros(self):
        app = self._janela_worker()
        self.assertFalse(app._somente_10_ativo())
        self.assertFalse(app._limpar_destino_ativo())
        self.assertTrue(app._continuar_erro_ativo())
        self.assertEqual(app._obter_meses_filtro_produtos(), 36)
        self.assertEqual(app._obter_dados_conexao("origem"), {"banco": "origem"})

    def test_thread_principal_nao_e_tratada_como_worker(self):
        app = self._janela_worker()
        app._thread_trabalho = object()
        self.assertFalse(app._na_thread_trabalho())

    def test_opcoes_de_teste_ficam_permanentemente_desativadas(self):
        app = object.__new__(MainWindow)
        self.assertFalse(app._somente_10_ativo())
        self.assertFalse(app._limpar_destino_ativo())

    def test_preparo_de_nova_execucao_limpa_somente_antes_do_inicio(self):
        app = object.__new__(MainWindow)
        eventos = []
        app._limpar_log = lambda: eventos.append("limpar")
        app._atualizar_resumo_execucao = lambda texto: eventos.append(("resumo", texto))
        app._atualizar_status_execucao = lambda texto: eventos.append(("status", texto))
        app._atualizar_progresso = lambda **dados: eventos.append(("progresso", dados))
        app._preparar_nova_execucao()
        self.assertEqual(eventos[0], "limpar")
        self.assertEqual(eventos[-1], ("progresso", {"maximum": 100, "value": 0}))


if __name__ == "__main__":
    unittest.main()
