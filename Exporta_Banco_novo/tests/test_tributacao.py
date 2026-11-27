import unittest
from decimal import Decimal

from ui.main_window import MainWindow


class Valor:
    def __init__(self, valor):
        self.valor = valor

    def get(self):
        return self.valor


class FirebirdFalso:
    @staticmethod
    def normalizar_nome_tabela(nome):
        return nome.strip().upper()


class ServicoCamposFalso(FirebirdFalso):
    def __init__(self, campos):
        self.campos = campos

    def obter_campos_tabela(self, con, tabela):
        return self.campos[getattr(con, "nome", con)][tabela]


class CursorFalso:
    def __init__(self, respostas):
        self.respostas = iter(respostas)
        self.resposta = None
        self.executados = []

    def execute(self, sql, parametros=None):
        self.executados.append((sql, parametros))
        self.resposta = next(self.respostas)

    def fetchall(self):
        return self.resposta

    def fetchone(self):
        return self.resposta


class ConexaoFalsa:
    def __init__(self, nome, respostas):
        self.nome = nome
        self.cursor_falso = CursorFalso(respostas)

    def cursor(self):
        return self.cursor_falso


class ConexaoConsultaFalsa:
    def __init__(self, retorno):
        self.retorno = retorno
        self.sql = None
        self.parametros = None

    def cursor(self):
        return self

    def execute(self, sql, parametros):
        self.sql = sql
        self.parametros = parametros

    def fetchone(self):
        return self.retorno


def janela(filtro="Todos", somente_10=False):
    instancia = object.__new__(MainWindow)
    instancia.var_filtro_produtos = Valor(filtro)
    instancia.var_somente_10 = Valor(somente_10)
    instancia._filtro_produtos_em_execucao = filtro != "Todos"
    instancia.firebird_service = FirebirdFalso()
    instancia._escrever_log = lambda texto: None
    return instancia


class TributacaoProdutosTest(unittest.TestCase):
    def test_pacote_posiciona_tributacao_apos_produto(self):
        tabelas = janela()._criar_pacotes_migracao()[3]["tabelas"]
        self.assertLess(tabelas.index("TB_PRODUTO"), tabelas.index("TB_PRODUTO_TRIBUTO"))

    def test_chave_upsert_composta_confirmada(self):
        self.assertEqual(
            janela()._obter_chave_upsert_tabela("TB_PRODUTO_TRIBUTO"),
            ["PRDT_EMPRESA", "PRDT_PRODUTO"],
        )

    def test_todos_restringe_tributacao_a_produto_da_mesma_empresa(self):
        sql = janela("Todos")._montar_sql_origem_produtos("TB_PRODUTO_TRIBUTO")
        self.assertIn("p.PRD_EMPRESA = t.PRDT_EMPRESA", sql)
        self.assertIn("p.PRD_ID = t.PRDT_PRODUTO", sql)
        self.assertIn("1 = 1", sql)

    def test_filtro_de_doze_meses_reutiliza_predicado_existente(self):
        sql = janela("12 meses")._montar_sql_origem_produtos("TB_PRODUTO_TRIBUTO")
        self.assertIn("DATEADD(-12 MONTH TO CURRENT_DATE)", sql)
        self.assertIn("TB_PRODUTO_MOVIMENTO", sql)
        self.assertIn("TB_NOTA_FISCAL_ITEM", sql)

    def test_count_tributario_usa_mesmo_vinculo_empresa_produto(self):
        sql = janela("24 meses")._montar_sql_origem_produtos(
            "TB_PRODUTO_TRIBUTO", contar=True
        )
        self.assertTrue(sql.startswith("SELECT COUNT(*)"))
        self.assertIn("p.PRD_EMPRESA = t.PRDT_EMPRESA", sql)
        self.assertIn("p.PRD_ID = t.PRDT_PRODUTO", sql)

    def test_bloqueia_campo_fiscal_perdido_no_destino(self):
        campos = {
            "origem": {"TB_PRODUTO_TRIBUTO": [
                {"nome": "PRDT_EMPRESA", "tipo": "INTEGER", "obrigatorio": True},
                {"nome": "PRDT_PRODUTO", "tipo": "INTEGER", "obrigatorio": True},
                {"nome": "PRDT_ICMS_CST", "tipo": "VARCHAR(3)", "obrigatorio": False},
            ]},
            "destino": {"TB_PRODUTO_TRIBUTO": [
                {"nome": "PRDT_EMPRESA", "tipo": "INTEGER", "obrigatorio": True},
                {"nome": "PRDT_PRODUTO", "tipo": "INTEGER", "obrigatorio": True},
            ]},
        }
        app = janela()
        app.firebird_service = ServicoCamposFalso(campos)
        with self.assertRaisesRegex(RuntimeError, "PRDT_ICMS_CST"):
            app._validar_compatibilidade_tributaria("origem", "destino")

    def test_blob_amparo_compativel_e_preservado_sem_transformacao(self):
        campos_tabela = [
            {"nome": "PRDT_EMPRESA", "tipo": "INTEGER", "obrigatorio": True},
            {"nome": "PRDT_PRODUTO", "tipo": "INTEGER", "obrigatorio": True},
            {"nome": "PRDT_AMPARO_LEGAL_IMENDES", "tipo": "BLOB", "obrigatorio": False},
        ]
        app = janela()
        app.firebird_service = ServicoCamposFalso({
            "origem": {"TB_PRODUTO_TRIBUTO": campos_tabela},
            "destino": {"TB_PRODUTO_TRIBUTO": campos_tabela},
        })
        app._validar_compatibilidade_tributaria("origem", "destino")
        blob = b"conteudo fiscal original"
        self.assertIs(app._limpar_valor_para_firebird(blob), blob)

    def test_grupo_tributario_nulo_nao_exige_cadastro_adicional(self):
        app = janela()
        app.firebird_service = ServicoCamposFalso({
            "origem": {"TB_PRODUTO_TRIBUTO": [
                {"nome": "PRDT_GRUPO_TRIB", "tipo": "INTEGER", "obrigatorio": False},
            ]},
        })
        origem = ConexaoFalsa("origem", [[], (0,)])
        app._validar_dependencias_tributarias(origem, "destino")

    def test_grupo_tributario_ausente_no_destino_bloqueia_copia(self):
        app = janela()
        campo = {"nome": "PRDT_GRUPO_TRIB", "tipo": "INTEGER", "obrigatorio": False}
        grupo = {"nome": "NCMG_ID", "tipo": "INTEGER", "obrigatorio": True}
        app.firebird_service = ServicoCamposFalso({
            "origem": {
                "TB_PRODUTO_TRIBUTO": [campo],
                "TB_NCM_GRUPO_TRIB": [grupo],
            },
            "destino": {"TB_NCM_GRUPO_TRIB": [grupo]},
        })
        origem = ConexaoFalsa("origem", [[(9,)], (0,)])
        destino = ConexaoFalsa("destino", [None])
        with self.assertRaisesRegex(RuntimeError, "Dependencia tributaria nao resolvida"):
            app._validar_dependencias_tributarias(origem, destino)

    def test_consulta_de_upsert_usa_empresa_e_produto(self):
        destino = ConexaoConsultaFalsa((1,))
        existe = janela()._registro_existe_destino(
            destino,
            "TB_PRODUTO_TRIBUTO",
            ["PRDT_EMPRESA", "PRDT_PRODUTO"],
            {"PRDT_EMPRESA": 3, "PRDT_PRODUTO": 81},
        )
        self.assertTrue(existe)
        self.assertIn("PRDT_EMPRESA = ? AND PRDT_PRODUTO = ?", destino.sql)
        self.assertEqual(destino.parametros, [3, 81])

    def test_bloqueia_tipo_fiscal_divergente(self):
        campos_origem = [
            {"nome": "PRDT_EMPRESA", "tipo": "INTEGER", "obrigatorio": True},
            {"nome": "PRDT_PRODUTO", "tipo": "INTEGER", "obrigatorio": True},
            {"nome": "PRDT_ICMS_ALIQ", "tipo": "NUMERIC(10,2)", "obrigatorio": False},
        ]
        campos_destino = campos_origem[:-1] + [
            {"nome": "PRDT_ICMS_ALIQ", "tipo": "NUMERIC(12,4)", "obrigatorio": False},
        ]
        app = janela()
        app.firebird_service = ServicoCamposFalso({
            "origem": {"TB_PRODUTO_TRIBUTO": campos_origem},
            "destino": {"TB_PRODUTO_TRIBUTO": campos_destino},
        })
        with self.assertRaisesRegex(RuntimeError, "PRDT_ICMS_ALIQ"):
            app._validar_compatibilidade_tributaria("origem", "destino")

    def test_bloqueia_campo_obrigatorio_exclusivo_do_destino(self):
        origem = [
            {"nome": "PRDT_EMPRESA", "tipo": "INTEGER", "obrigatorio": True},
            {"nome": "PRDT_PRODUTO", "tipo": "INTEGER", "obrigatorio": True},
        ]
        destino = origem + [
            {"nome": "PRDT_NOVO_OBRIGATORIO", "tipo": "VARCHAR(10)", "obrigatorio": True},
        ]
        app = janela()
        app.firebird_service = ServicoCamposFalso({
            "origem": {"TB_PRODUTO_TRIBUTO": origem},
            "destino": {"TB_PRODUTO_TRIBUTO": destino},
        })
        with self.assertRaisesRegex(RuntimeError, "PRDT_NOVO_OBRIGATORIO"):
            app._validar_compatibilidade_tributaria("origem", "destino")

    def test_aceita_ampliacao_numerica_segura_das_quatro_aliquotas(self):
        campos_origem = [
            {"nome": "PRDT_EMPRESA", "tipo": "INTEGER", "obrigatorio": True},
            {"nome": "PRDT_PRODUTO", "tipo": "INTEGER", "obrigatorio": True},
        ] + [
            {"nome": nome, "tipo": "NUMERIC(10,4)", "obrigatorio": False}
            for nome in (
                "PRDT_CONFINS_ALIQ_ENT",
                "PRDT_CONFINS_ALIQ_SAI",
                "PRDT_PIS_ALIQ_ENT",
                "PRDT_PIS_ALIQ_SAI",
            )
        ]
        campos_destino = [
            {**campo, "tipo": "NUMERIC(12,4)"}
            if campo["nome"].startswith("PRDT_") and "ALIQ" in campo["nome"]
            else campo
            for campo in campos_origem
        ]
        app = janela()
        app.firebird_service = ServicoCamposFalso({
            "origem": {"TB_PRODUTO_TRIBUTO": campos_origem},
            "destino": {"TB_PRODUTO_TRIBUTO": campos_destino},
        })
        app._validar_compatibilidade_tributaria("origem", "destino")

    def test_bloqueia_reducao_de_escala_de_aliquota(self):
        origem = [
            {"nome": "PRDT_EMPRESA", "tipo": "INTEGER", "obrigatorio": True},
            {"nome": "PRDT_PRODUTO", "tipo": "INTEGER", "obrigatorio": True},
            {"nome": "PRDT_PIS_ALIQ_SAI", "tipo": "NUMERIC(10,4)", "obrigatorio": False},
        ]
        destino = origem[:-1] + [
            {"nome": "PRDT_PIS_ALIQ_SAI", "tipo": "NUMERIC(10,2)", "obrigatorio": False},
        ]
        app = janela()
        app.firebird_service = ServicoCamposFalso({
            "origem": {"TB_PRODUTO_TRIBUTO": origem},
            "destino": {"TB_PRODUTO_TRIBUTO": destino},
        })
        with self.assertRaisesRegex(RuntimeError, "PRDT_PIS_ALIQ_SAI"):
            app._validar_compatibilidade_tributaria("origem", "destino")

    def test_financeiro_nao_referencia_estado_de_falha_tributaria(self):
        self.assertNotIn(
            "falhas_tributarias",
            MainWindow._migrar_financeiro_em_aberto.__code__.co_names,
        )

    def test_numeric_15_2_para_15_4_exige_validacao_por_valor(self):
        app = janela("36 meses")
        limite = app._tipos_numericos_tributarios_validaveis_por_valor(
            "NUMERIC(15,2)", "NUMERIC(15,4)"
        )
        self.assertEqual(limite, Decimal("99999999999.9999"))

    def test_valor_tributario_representavel_e_permitido(self):
        app = janela("36 meses")
        origem = ConexaoFalsa("origem", [None])
        app._validar_valores_numericos_tributarios(
            origem,
            [("PRDT_PIS_ALIQ_SAI", Decimal("99999999999.9999"))],
        )
        sql, parametros = origem.cursor_falso.executados[0]
        self.assertIn("PRDT_PIS_ALIQ_SAI", sql)
        self.assertIn("DATEADD(-36 MONTH TO CURRENT_DATE)", sql)
        self.assertEqual(parametros, [Decimal("99999999999.9999"), Decimal("-99999999999.9999")])

    def test_valor_tributario_fora_do_destino_bloqueia_com_chave(self):
        app = janela("Todos")
        origem = ConexaoFalsa("origem", [(2, 81, Decimal("100000000000.0000"))])
        with self.assertRaisesRegex(RuntimeError, "empresa=2; produto=81; campo=PRDT_CONFINS_ALIQ_ENT"):
            app._validar_valores_numericos_tributarios(
                origem,
                [("PRDT_CONFINS_ALIQ_ENT", Decimal("99999999999.9999"))],
            )

    def test_nutricional_reutiliza_filtro_e_vinculo_empresa_produto(self):
        sql = janela("12 meses")._montar_sql_origem_produtos("TB_PRODUTO_NUTRICIONAL")
        self.assertIn("p.PRD_EMPRESA = n.PRDN_EMPRESA", sql)
        self.assertIn("p.PRD_ID = n.PRDN_PRODUTO", sql)
        self.assertIn("DATEADD(-12 MONTH TO CURRENT_DATE)", sql)

    def test_nutricional_tem_chave_composta_de_upsert(self):
        self.assertEqual(
            janela()._obter_chave_upsert_tabela("TB_PRODUTO_NUTRICIONAL"),
            ["PRDN_EMPRESA", "PRDN_PRODUTO"],
        )

    def test_xml_importado_e_oitava_tabela_do_pacote_produtos(self):
        tabelas = janela()._criar_pacotes_migracao()[3]["tabelas"]
        self.assertEqual(len(tabelas), 8)
        self.assertEqual(tabelas[-1], "TB_PROD_XML_IMPORTADO")

    def test_xml_importado_tem_chave_primaria_composta_real(self):
        self.assertEqual(
            janela()._obter_chave_upsert_tabela("TB_PROD_XML_IMPORTADO"),
            ["PXI_EMPRESA", "PXI_EMITENTE", "PXI_COD_PROD_EMIT"],
        )

    def test_xml_importado_filtra_produto_por_empresa_e_preserva_nulos(self):
        sql = janela("36 meses")._montar_sql_origem_produtos("TB_PROD_XML_IMPORTADO")
        self.assertIn("x.PXI_PRODUTO IS NULL", sql)
        self.assertIn("p.PRD_EMPRESA = x.PXI_EMPRESA", sql)
        self.assertIn("p.PRD_ID = x.PXI_PRODUTO", sql)
        self.assertIn("DATEADD(-36 MONTH TO CURRENT_DATE)", sql)

    def test_xml_importado_valida_empresa_para_registro_sem_produto(self):
        app = janela("Todos")
        origem = ConexaoFalsa("origem", [[(4, None)]])
        destino = ConexaoFalsa("destino", [(1,)])
        app._validar_vinculos_xml_importado(origem, destino)
        sql, parametros = destino.cursor_falso.executados[0]
        self.assertIn("TB_EMPRESA", sql)
        self.assertEqual(parametros, [4])

    def test_xml_importado_bloqueia_produto_ausente_no_destino(self):
        app = janela("Todos")
        origem = ConexaoFalsa("origem", [[(4, 19)]])
        destino = ConexaoFalsa("destino", [None])
        with self.assertRaisesRegex(RuntimeError, "empresa=4; produto=19"):
            app._validar_vinculos_xml_importado(origem, destino)


if __name__ == "__main__":
    unittest.main()
