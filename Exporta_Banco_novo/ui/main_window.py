import tkinter as tk
from tkinter import ttk, messagebox, filedialog

from services.firebird_service import FirebirdService


class MainWindow(tk.Tk):
    def __init__(self):
        super().__init__()

        self.title("ImportaDados - Migração Assistida entre Bases")
        self.geometry("1480x900")
        self.minsize(1280, 780)
        self.configure(bg="#f5f6f8")

        self.firebird_service = FirebirdService()
        self.ambiente_firebird = self.firebird_service.detectar_ambiente_firebird()

        self.edt_origem_servidor = None
        self.edt_origem_porta = None
        self.edt_origem_banco = None
        self.edt_origem_usuario = None
        self.edt_origem_senha = None
        self.edt_origem_charset = None

        self.edt_destino_servidor = None
        self.edt_destino_porta = None
        self.edt_destino_banco = None
        self.edt_destino_usuario = None
        self.edt_destino_senha = None
        self.edt_destino_charset = None

        self.lbl_status_conexao = None

        self.lst_pacotes = None
        self.lst_tabelas = None
        self.txt_log = None
        self.lbl_resumo_execucao = None
        self.lbl_progresso_execucao = None
        self.pb_execucao = None

        self.base_inicial_processada = False

        self.var_somente_10 = tk.BooleanVar(value=False)


        self.var_limpar_destino = tk.BooleanVar(value=False)
        self.var_continuar_erro = tk.BooleanVar(value=True)

        self.pacotes_migracao = self._criar_pacotes_migracao()

        self._configurar_estilos()
        self._criar_layout()

    def _configurar_estilos(self):
        style = ttk.Style()

        try:
            style.theme_use("clam")
        except Exception:
            pass

        style.configure(
            "Card.TLabelframe",
            background="#ffffff",
            borderwidth=1,
            relief="solid",
        )

        style.configure(
            "Card.TLabelframe.Label",
            font=("Segoe UI", 10, "bold"),
            foreground="#222222",
            background="#ffffff",
        )

        style.configure(
            "Campo.TLabel",
            font=("Segoe UI", 9, "bold"),
            foreground="#333333",
            background="#ffffff",
        )

        style.configure(
            "Texto.TLabel",
            font=("Segoe UI", 10),
            foreground="#444444",
            background="#ffffff",
        )

        style.configure(
            "Info.TLabel",
            font=("Segoe UI", 9),
            foreground="#355c7d",
            background="#f5f6f8",
        )

        style.configure(
            "Secao.TButton",
            font=("Segoe UI", 9, "bold"),
            padding=(8, 4),
        )

        style.configure(
            "Arquivo.TButton",
            font=("Segoe UI", 9, "bold"),
            padding=(6, 2),
        )

    def _criar_layout(self):
        container = tk.Frame(self, bg="#f5f6f8")
        container.pack(fill="both", expand=True, padx=12, pady=12)

        self.lbl_status_conexao = ttk.Label(
            container,
            text=self._montar_texto_ambiente(),
            style="Info.TLabel",
            justify="left",
        )
        self.lbl_status_conexao.pack(anchor="w", pady=(0, 8))

        notebook = ttk.Notebook(container)
        notebook.pack(fill="both", expand=True)

        aba_conexoes = tk.Frame(notebook, bg="#f5f6f8")
        aba_execucao = tk.Frame(notebook, bg="#f5f6f8")

        notebook.add(aba_conexoes, text="Conexões")
        notebook.add(aba_execucao, text="Execução da Migração")

        self._criar_aba_conexoes(aba_conexoes)
        self._criar_aba_execucao(aba_execucao)

    def _criar_aba_conexoes(self, parent):
        parent.grid_columnconfigure(0, weight=1)
        parent.grid_columnconfigure(1, weight=1)
        parent.grid_rowconfigure(0, weight=0)
        parent.grid_rowconfigure(1, weight=0)

        bloco_origem = self._criar_bloco_conexao(parent, "Conexão Origem", "origem")
        bloco_origem.grid(row=0, column=0, sticky="nsew", padx=(0, 6), pady=(0, 8))

        bloco_destino = self._criar_bloco_conexao(parent, "Conexão Destino", "destino")
        bloco_destino.grid(row=0, column=1, sticky="nsew", padx=(6, 0), pady=(0, 8))

        barra = ttk.LabelFrame(parent, text="Ações iniciais", style="Card.TLabelframe")
        barra.grid(row=1, column=0, columnspan=2, sticky="ew")

        interno = tk.Frame(barra, bg="#ffffff")
        interno.pack(fill="x", expand=True, padx=10, pady=10)

        ttk.Button(
            interno,
            text="Validar conexões",
            style="Secao.TButton",
            command=self._validar_conexoes,
        ).pack(side="left", padx=(0, 8))

        ttk.Button(
            interno,
            text="Analisar pacote selecionado",
            style="Secao.TButton",
            command=self._analisar_destino_pacote,
        ).pack(side="left", padx=(0, 8))

        ttk.Label(
            interno,
            text="Depois das conexões válidas, a execução deve ser feita pela aba 'Execução da Migração'.",
            style="Texto.TLabel",
        ).pack(side="left")

    def _criar_aba_execucao(self, parent):
        parent.grid_rowconfigure(0, weight=1)
        parent.grid_rowconfigure(1, weight=0)
        parent.grid_rowconfigure(2, weight=2)
        parent.grid_columnconfigure(0, weight=1)

        topo = tk.Frame(parent, bg="#f5f6f8")
        topo.grid(row=0, column=0, sticky="nsew", pady=(0, 8))
        topo.grid_columnconfigure(0, weight=1)
        topo.grid_columnconfigure(1, weight=1)
        topo.grid_columnconfigure(2, weight=1)

        bloco_pacotes = ttk.LabelFrame(topo, text="Pacotes de migração", style="Card.TLabelframe")
        bloco_pacotes.grid(row=0, column=0, sticky="nsew", padx=(0, 6))

        interno_pacotes = tk.Frame(bloco_pacotes, bg="#ffffff")
        interno_pacotes.pack(fill="both", expand=True, padx=8, pady=8)

        ttk.Label(
            interno_pacotes,
            text="Selecione um pacote para carregar a lista de tabelas.",
            style="Texto.TLabel",
        ).pack(anchor="w", pady=(0, 6))

        self.lst_pacotes = tk.Listbox(interno_pacotes, exportselection=False, height=12)
        self.lst_pacotes.pack(fill="both", expand=True)
        self.lst_pacotes.bind("<<ListboxSelect>>", self._ao_selecionar_pacote)

        for pacote in self.pacotes_migracao:
            self.lst_pacotes.insert(tk.END, pacote["nome"])

        self._atualizar_pacotes_liberados()

        bloco_tabelas = ttk.LabelFrame(topo, text="Tabelas do pacote", style="Card.TLabelframe")
        bloco_tabelas.grid(row=0, column=1, sticky="nsew", padx=6)

        interno_tabelas = tk.Frame(bloco_tabelas, bg="#ffffff")
        interno_tabelas.pack(fill="both", expand=True, padx=8, pady=8)

        ttk.Label(
            interno_tabelas,
            text="Use esta lista para migrar uma tabela isolada, se necessário.",
            style="Texto.TLabel",
        ).pack(anchor="w", pady=(0, 6))

        self.lst_tabelas = tk.Listbox(interno_tabelas, exportselection=False, height=12)
        self.lst_tabelas.pack(fill="both", expand=True)

        bloco_opcoes = ttk.LabelFrame(topo, text="Opções e ações", style="Card.TLabelframe")
        bloco_opcoes.grid(row=0, column=2, sticky="nsew", padx=(6, 0))

        interno_opcoes = tk.Frame(bloco_opcoes, bg="#ffffff")
        interno_opcoes.pack(fill="both", expand=True, padx=8, pady=8)

        ttk.Checkbutton(
            interno_opcoes,
            text="Migrar somente 10 registros por tabela",
            variable=self.var_somente_10,
        ).pack(anchor="w", pady=(0, 6))

        ttk.Checkbutton(
            interno_opcoes,
            text="Limpar tabela destino antes de inserir",
            variable=self.var_limpar_destino,
        ).pack(anchor="w", pady=(0, 6))

        ttk.Checkbutton(
            interno_opcoes,
            text="Continuar mesmo se uma tabela falhar",
            variable=self.var_continuar_erro,
        ).pack(anchor="w", pady=(0, 12))

        ttk.Button(
            interno_opcoes,
            text="Analisar pacote selecionado",
            style="Secao.TButton",
            command=self._analisar_destino_pacote,
        ).pack(fill="x", pady=(0, 8))

        ttk.Button(
            interno_opcoes,
            text="Migrar pacote selecionado",
            style="Secao.TButton",
            command=self._migrar_pacote_selecionado,
        ).pack(fill="x", pady=(0, 8))

        ttk.Button(
            interno_opcoes,
            text="Migrar tabela selecionada",
            style="Secao.TButton",
            command=self._migrar_tabela_selecionada,
        ).pack(fill="x", pady=(0, 8))

        ttk.Button(
            interno_opcoes,
            text="Limpar log",
            style="Secao.TButton",
            command=self._limpar_log,
        ).pack(fill="x")

        faixa_progresso = tk.Frame(parent, bg="#f5f6f8")
        faixa_progresso.grid(row=1, column=0, sticky="ew", pady=(0, 8))
        faixa_progresso.grid_columnconfigure(0, weight=1)

        self.lbl_progresso_execucao = ttk.Label(
            faixa_progresso,
            text="Aguardando execução.",
            style="Texto.TLabel",
        )
        self.lbl_progresso_execucao.grid(row=0, column=0, sticky="w", pady=(0, 4))

        self.pb_execucao = ttk.Progressbar(
            faixa_progresso,
            orient="horizontal",
            mode="determinate",
            maximum=100,
            value=0,
        )
        self.pb_execucao.grid(row=1, column=0, sticky="ew")

        bloco_log = ttk.LabelFrame(parent, text="Log da execução", style="Card.TLabelframe")
        bloco_log.grid(row=2, column=0, sticky="nsew")

        interno_log = tk.Frame(bloco_log, bg="#ffffff")
        interno_log.pack(fill="both", expand=True, padx=8, pady=8)

        self.lbl_resumo_execucao = ttk.Label(
            interno_log,
            text="Pronto para iniciar a migração.",
            style="Texto.TLabel",
        )
        self.lbl_resumo_execucao.pack(anchor="w", pady=(0, 6))

        area_log = tk.Frame(interno_log, bg="#ffffff")
        area_log.pack(fill="both", expand=True)

        self.txt_log = tk.Text(area_log, wrap="word", height=18)
        self.txt_log.grid(row=0, column=0, sticky="nsew")

        scroll_y = ttk.Scrollbar(area_log, orient="vertical", command=self.txt_log.yview)
        scroll_y.grid(row=0, column=1, sticky="ns")

        self.txt_log.configure(yscrollcommand=scroll_y.set)

        area_log.grid_rowconfigure(0, weight=1)
        area_log.grid_columnconfigure(0, weight=1)

        if self.pacotes_migracao:
            self.lst_pacotes.selection_set(0)
            self._ao_selecionar_pacote()

    def _criar_bloco_conexao(self, parent, titulo, lado):
        frame = ttk.LabelFrame(parent, text=titulo, style="Card.TLabelframe")

        interno = tk.Frame(frame, bg="#ffffff")
        interno.pack(fill="both", expand=True, padx=8, pady=8)

        for i in range(10):
            interno.grid_columnconfigure(i, weight=0)

        edt_servidor = self._adicionar_campo_inline(
            interno, "Servidor / IP", 0, "127.0.0.1", largura=12
        )
        edt_porta = self._adicionar_campo_inline(
            interno, "Porta", 2, "3050", largura=7
        )
        edt_usuario = self._adicionar_campo_inline(
            interno, "Usuário", 4, "SYSDBA", largura=10
        )
        edt_senha = self._adicionar_campo_inline(
            interno, "Senha", 6, "masterkey", largura=10, show="*"
        )
        edt_charset = self._adicionar_campo_inline(
            interno, "Charset", 8, "WIN1252", largura=8
        )

        linha_banco = tk.Frame(interno, bg="#ffffff")
        linha_banco.grid(row=1, column=0, columnspan=10, sticky="ew", pady=(8, 6))
        linha_banco.grid_columnconfigure(1, weight=1)

        ttk.Label(linha_banco, text="Caminho do banco", style="Campo.TLabel").grid(
            row=0, column=0, sticky="w", padx=(0, 8)
        )

        edt_banco = ttk.Entry(linha_banco)
        edt_banco.grid(row=0, column=1, sticky="ew", padx=(0, 8), ipady=2)

        if lado == "origem":
            edt_banco.insert(0, r"E:/Dados Clientes/Fabri Tecidos/DADOS.FDB")
        else:
            edt_banco.insert(0, r"E:/Dados Clientes/Banco Vazio/DADOS.FDB")

        ttk.Button(
            linha_banco,
            text="...",
            width=4,
            style="Arquivo.TButton",
            command=lambda l=lado: self._selecionar_arquivo_banco(l),
        ).grid(row=0, column=2, sticky="w")

        linha_acao = tk.Frame(interno, bg="#ffffff")
        linha_acao.grid(row=2, column=0, columnspan=10, sticky="ew", pady=(0, 2))

        ttk.Button(
            linha_acao,
            text="Testar conexão",
            style="Secao.TButton",
            command=lambda l=lado: self._testar_conexao(l),
        ).pack(side="left", padx=(0, 8))

        if lado == "origem":
            self.edt_origem_servidor = edt_servidor
            self.edt_origem_porta = edt_porta
            self.edt_origem_banco = edt_banco
            self.edt_origem_usuario = edt_usuario
            self.edt_origem_senha = edt_senha
            self.edt_origem_charset = edt_charset
        else:
            self.edt_destino_servidor = edt_servidor
            self.edt_destino_porta = edt_porta
            self.edt_destino_banco = edt_banco
            self.edt_destino_usuario = edt_usuario
            self.edt_destino_senha = edt_senha
            self.edt_destino_charset = edt_charset

        return frame

    def _adicionar_campo_inline(self, parent, titulo, column_start, valor="", largura=12, show=None):
        ttk.Label(parent, text=titulo, style="Campo.TLabel").grid(
            row=0, column=column_start, sticky="w", padx=(0, 6)
        )

        widget = ttk.Entry(parent, width=largura)
        if show:
            widget.configure(show=show)

        if valor:
            widget.insert(0, valor)

        widget.grid(row=0, column=column_start + 1, sticky="w", padx=(0, 14), ipady=2)
        return widget

    def _selecionar_arquivo_banco(self, lado):
        caminho = filedialog.askopenfilename(
            title="Selecionar banco Firebird",
            filetypes=[
                ("Banco Firebird", "*.fdb *.gdb"),
                ("Banco Firebird", "*.FDB *.GDB"),
                ("Todos os arquivos", "*.*"),
            ],
        )

        if not caminho:
            return

        if lado == "origem":
            self.edt_origem_banco.delete(0, tk.END)
            self.edt_origem_banco.insert(0, caminho)
        else:
            self.edt_destino_banco.delete(0, tk.END)
            self.edt_destino_banco.insert(0, caminho)

    def _obter_widgets_lado(self, lado):
        if lado == "origem":
            return {
                "servidor": self.edt_origem_servidor,
                "porta": self.edt_origem_porta,
                "banco": self.edt_origem_banco,
                "usuario": self.edt_origem_usuario,
                "senha": self.edt_origem_senha,
                "charset": self.edt_origem_charset,
            }

        return {
            "servidor": self.edt_destino_servidor,
            "porta": self.edt_destino_porta,
            "banco": self.edt_destino_banco,
            "usuario": self.edt_destino_usuario,
            "senha": self.edt_destino_senha,
            "charset": self.edt_destino_charset,
        }

    def _obter_dados_conexao(self, lado):
        widgets = self._obter_widgets_lado(lado)

        porta_txt = (widgets["porta"].get() or "").strip()
        porta = 3050
        if porta_txt:
            try:
                porta = int(porta_txt)
            except ValueError:
                raise ValueError(f"A porta da conexão {lado} está inválida.")

        return {
            "servidor": (widgets["servidor"].get() or "").strip() or "127.0.0.1",
            "porta": porta,
            "banco": (widgets["banco"].get() or "").strip(),
            "usuario": (widgets["usuario"].get() or "").strip() or "SYSDBA",
            "senha": widgets["senha"].get() or "",
            "charset": (widgets["charset"].get() or "").strip() or "WIN1252",
        }

    def _montar_texto_ambiente(self):
        return self.firebird_service.montar_texto_ambiente(self.ambiente_firebird)

    def _conectar_automatico(self, dados):
        return self.firebird_service.conectar_automatico(dados, self.ambiente_firebird)

    def _fechar_conexao(self, con):
        self.firebird_service.fechar_conexao(con)

    def _testar_conexao(self, lado):
        con = None
        try:
            self.ambiente_firebird = self.firebird_service.detectar_ambiente_firebird()
            if self.lbl_status_conexao is not None:
                self.lbl_status_conexao.configure(text=self._montar_texto_ambiente())

            dados = self._obter_dados_conexao(lado)
            con, info = self._conectar_automatico(dados)

            cur = con.cursor()
            cur.execute("SELECT CURRENT_TIMESTAMP FROM RDB$DATABASE")
            linha = cur.fetchone()

            detalhe_cliente = "auto sem DLL fixa"
            if info["cliente"] and info["cliente"].get("dll"):
                detalhe_cliente = f"FB {info['cliente'].get('versao')} -> {info['cliente'].get('dll')}"

            messagebox.showinfo(
                "Conexão OK",
                f"Conexão {lado} realizada com sucesso.\n\n"
                f"Modo: {info['modo']}\n"
                f"Cliente: {detalhe_cliente}\n"
                f"Banco: {dados['banco']}\n"
                f"Data/hora do servidor: {linha[0]}",
            )
        except Exception as e:
            messagebox.showerror("Erro de conexão", f"Falha ao conectar na {lado}.\n\n{e}")
        finally:
            self._fechar_conexao(con)

    def _validar_conexoes(self):
        mensagens = []

        if not self.firebird_service.has_fdb():
            mensagens.append("- fdb não está instalado.")
        if not self.firebird_service.has_firebird_driver():
            mensagens.append("- firebird-driver não está instalado.")

        try:
            dados_origem = self._obter_dados_conexao("origem")
            if not dados_origem["banco"]:
                mensagens.append("- Informe o caminho do banco de origem.")
        except Exception as e:
            mensagens.append(f"- Origem: {e}")

        try:
            dados_destino = self._obter_dados_conexao("destino")
            if not dados_destino["banco"]:
                mensagens.append("- Informe o caminho do banco de destino.")
        except Exception as e:
            mensagens.append(f"- Destino: {e}")

        if mensagens:
            messagebox.showwarning(
                "Validação",
                "Ajuste os pontos abaixo antes de seguir:\n\n" + "\n".join(mensagens),
            )
            return

        con_origem = None
        con_destino = None

        try:
            con_origem, _ = self._conectar_automatico(dados_origem)
            con_destino, _ = self._conectar_automatico(dados_destino)

            self._escrever_log("Conexão origem validada com sucesso.")
            self._escrever_log("Conexão destino validada com sucesso.")
            self.lbl_resumo_execucao.configure(
                text="Conexões válidas. Já é possível analisar e iniciar a migração."
            )

            messagebox.showinfo(
                "Validação",
                "Origem e destino conectados com sucesso.",
            )
        except Exception as e:
            messagebox.showerror(
                "Erro na validação",
                f"Não foi possível validar as conexões.\n\n{e}",
            )
        finally:
            self._fechar_conexao(con_origem)
            self._fechar_conexao(con_destino)

    def _criar_pacotes_migracao(self):
        return [
            {
                "nome": "Cadastros básicos",
                "descricao": "Tabelas essenciais para iniciar qualquer processo de migração.",
                "tabelas": [
                    "TB_EMPRESA",
                    "TB_ESTADO",
                    "TB_CIDADE",
                    "TB_UNIDADE_MEDIDA",
                    "TB_USU_PERFIL",
                    "TB_USUARIO",
                    "TB_VENDEDOR",
                ],
            },
            {
                "nome": "Clientes",
                "descricao": "Migração de clientes e suas dependências diretas.",
                "tabelas": [
                    "TB_REGIAO",
                    "TB_CLIENTE_GRUPO",
                    "TB_CLIENTE",
                ],
            },
            {
                "nome": "Fornecedores",
                "descricao": "Migração da base de fornecedores.",
                "tabelas": [
                    "TB_FORNECEDOR",
                ],
            },
            {
                "nome": "Produtos",
                "descricao": "Migração da base de produtos e seus cadastros auxiliares.",
                "tabelas": [
                    "TB_PROD_MARCA",
                    "TB_PROD_GRUPO",
                    "TB_PROD_SUB_GRUPO",
                    "TB_PRODUTO",
                    "TB_PROD_CODIGO_BARRAS",
                ],
            },
            {
                "nome": "Financeiro em aberto",
                "descricao": "Financeiro em aberto com renumeração controlada do REC_ID e ramificações oficiais.",
                "tabelas": [
                    "TB_FORMA_PAGTO",
                    "TB_FORMA_PAGTO_PARCELAS",
                    "TB_CAIXA",
                    "TB_PLANO_CONTA",
                    "TB_CONTA_BANCARIA",
                    "TB_RECEBIMENTO",
                    "TB_RECEBIMENTO_ITEM",
                    "TB_BOLETO_CONF",
                    "TB_BOLETO",
                    "TB_RECEBIMENTO_COBRANCA",
                    "TB_BORDERO_COMP_CARTAO_REC",
                    "TB_BORDERO_COBRANCA_ITEM",
                    "TB_BORDERO_NEGOCIACAO_ITEM",
                    "TB_BORDERO_RECEBIMENTO_ITEM",
                    "TB_BORDERO_RESIDUO_REC",
                ],
            },
        ]
    
    def _pacote_esta_liberado(self, indice):
        if indice in (0, 1, 2, 3):
            return True

        return self.base_inicial_processada

    def _atualizar_pacotes_liberados(self):
        if self.lst_pacotes is None:
            return

        for indice in range(self.lst_pacotes.size()):
            if self._pacote_esta_liberado(indice):
                self.lst_pacotes.itemconfig(indice, foreground="#000000")
            else:
                self.lst_pacotes.itemconfig(indice, foreground="#9a9a9a")    

    def _obter_tabelas_financeiro_controlado(self):
        return {
            "TB_RECEBIMENTO",
            "TB_RECEBIMENTO_ITEM",
            "TB_BOLETO",
            "TB_RECEBIMENTO_COBRANCA",
            "TB_BORDERO_COMP_CARTAO_REC",
            "TB_BORDERO_COBRANCA_ITEM",
            "TB_BORDERO_NEGOCIACAO_ITEM",
            "TB_BORDERO_RECEBIMENTO_ITEM",
            "TB_BORDERO_RESIDUO_REC",
        }

    def _obter_campo_vinculo_recebimento(self, tabela):
        tabela = self.firebird_service.normalizar_nome_tabela(tabela)

        mapa = {
            "TB_RECEBIMENTO_ITEM": "RIT_RECEBIMENTO",
            "TB_BOLETO": "BOL_RECEBIMENTO",
            "TB_RECEBIMENTO_COBRANCA": "RCC_RECEBIMENTO",
            "TB_BORDERO_COMP_CARTAO_REC": "BDCR_RECEBIMENTO",
            "TB_BORDERO_COBRANCA_ITEM": "BCI_RECEBIMENTO",
            "TB_BORDERO_NEGOCIACAO_ITEM": "BNI_RECEBIMENTO",
            "TB_BORDERO_RECEBIMENTO_ITEM": "BRI_RECEBIMENTO",
            "TB_BORDERO_RESIDUO_REC": "BDSR_RECEBIMENTO",
        }

        return mapa.get(tabela)
    
    def _obter_campo_empresa_vinculo_recebimento(self, tabela):
        tabela = self.firebird_service.normalizar_nome_tabela(tabela)

        mapa = {
            "TB_RECEBIMENTO_ITEM": "RIT_EMPRESA",
            "TB_BOLETO": "BOL_EMPRESA",
            "TB_RECEBIMENTO_COBRANCA": "RCC_EMPRESA",
            "TB_BORDERO_COMP_CARTAO_REC": "BDCR_EMPRESA",
            "TB_BORDERO_COBRANCA_ITEM": "BCI_EMPRESA",
            "TB_BORDERO_NEGOCIACAO_ITEM": "BNI_EMPRESA",
            "TB_BORDERO_RECEBIMENTO_ITEM": "BRI_EMPRESA",
            "TB_BORDERO_RESIDUO_REC": "BDSR_EMPRESA",
        }

        return mapa.get(tabela)

    def _normalizar_texto_observacao(self, valor):
        if valor is None:
            return ""

        if isinstance(valor, bytes):
            try:
                return valor.decode("latin1")
            except Exception:
                try:
                    return valor.decode("utf-8", errors="ignore")
                except Exception:
                    return ""

        return str(valor)

    def _ajustar_sequencial_recebimento(self, con_destino, maiores_por_empresa):
        cur = con_destino.cursor()

        for empresa, maior_rec_id in maiores_por_empresa.items():
            cur.execute(
                """
                SELECT FIRST 1 1
                FROM TB_SEQUENCIAL
                WHERE SEQ_EMPRESA = ?
                  AND SEQ_TABELA = 'TB_RECEBIMENTO'
                """,
                [empresa],
            )

            existe = cur.fetchone() is not None

            if existe:
                cur.execute(
                    """
                    UPDATE TB_SEQUENCIAL
                    SET SEQ_SEQUENCIAL = ?
                    WHERE SEQ_EMPRESA = ?
                      AND SEQ_TABELA = 'TB_RECEBIMENTO'
                    """,
                    [maior_rec_id, empresa],
                )
            else:
                cur.execute(
                    """
                    INSERT INTO TB_SEQUENCIAL
                        (SEQ_EMPRESA, SEQ_TABELA, SEQ_SEQUENCIAL)
                    VALUES
                        (?, 'TB_RECEBIMENTO', ?)
                    """,
                    [empresa, maior_rec_id],
                )

            self._escrever_log(
                f"TB_SEQUENCIAL ajustada: empresa={empresa} | TB_RECEBIMENTO={maior_rec_id}"
            )


    def _obter_pacote_selecionado(self):
        if self.lst_pacotes is None:
            return None

        selecionados = self.lst_pacotes.curselection()
        if not selecionados:
            return None

        indice = selecionados[0]
        return self.pacotes_migracao[indice]

    def _ao_selecionar_pacote(self, event=None):
        if self.lst_pacotes is None:
            return

        selecionados = self.lst_pacotes.curselection()

        if selecionados:
            indice = selecionados[0]

            if not self._pacote_esta_liberado(indice):
                self.lst_pacotes.selection_clear(0, tk.END)
                self.lst_pacotes.selection_set(0)
                self.lst_pacotes.activate(0)

                self._escrever_log(
                    "Pacote bloqueado. Processe primeiro o pacote Cadastros básicos antes do financeiro."
                )

                messagebox.showwarning(
                    "Pacote bloqueado",
                    "Processe primeiro o pacote Cadastros básicos antes de migrar o financeiro em aberto.",
                )

        pacote = self._obter_pacote_selecionado()

        self.lst_tabelas.delete(0, tk.END)

        if not pacote:
            return

        for tabela in pacote["tabelas"]:
            self.lst_tabelas.insert(tk.END, tabela)

        self.lbl_resumo_execucao.configure(
            text=f"Pacote selecionado: {pacote['nome']} | {len(pacote['tabelas'])} tabela(s)."
        )

    def _obter_tabela_selecionada(self):
        if self.lst_tabelas is None:
            return None

        selecionados = self.lst_tabelas.curselection()
        if not selecionados:
            return None

        return self.lst_tabelas.get(selecionados[0])

    def _escrever_log(self, texto):
        if self.txt_log is None:
            return

        self.txt_log.insert(tk.END, texto + "\n")
        self.txt_log.see(tk.END)
        self.update_idletasks()

    def _limpar_log(self):
        if self.txt_log is not None:
            self.txt_log.delete("1.0", tk.END)

    def _analisar_destino_pacote(self):
        pacote = self._obter_pacote_selecionado()
        if not pacote:
            messagebox.showwarning("Pacote", "Selecione um pacote.")
            return

        con_origem = None
        con_destino = None

        try:
            dados_origem = self._obter_dados_conexao("origem")
            dados_destino = self._obter_dados_conexao("destino")

            con_origem, _ = self._conectar_automatico(dados_origem)
            con_destino, _ = self._conectar_automatico(dados_destino)

            self._escrever_log("=" * 70)
            self._escrever_log(f"Análise do pacote: {pacote['nome']}")

            for tabela in pacote["tabelas"]:
                qtd_origem = self._contar_registros(con_origem, tabela)
                qtd_destino = self._contar_registros(con_destino, tabela)

                tabela_norm = self.firebird_service.normalizar_nome_tabela(tabela)

                if tabela_norm in self._obter_tabelas_financeiro_controlado():
                    sql_count_filtrado = self._montar_sql_count_origem_tabela(tabela_norm)
                    qtd_filtrada = 0

                    if sql_count_filtrado:
                        cur_filtro = con_origem.cursor()
                        cur_filtro.execute(sql_count_filtrado)
                        linha_filtro = cur_filtro.fetchone()
                        qtd_filtrada = int(linha_filtro[0] or 0)

                    self._escrever_log(
                        f"{tabela}: origem_total={qtd_origem} | origem_filtrada={qtd_filtrada} | destino={qtd_destino}"
                    )
                else:
                    self._escrever_log(
                        f"{tabela}: origem={qtd_origem} | destino={qtd_destino}"
                    )

            self._escrever_log("=" * 70)
            self.lbl_resumo_execucao.configure(
                text=f"Análise concluída para o pacote: {pacote['nome']}."
            )
        except Exception as e:
            messagebox.showerror(
                "Erro na análise",
                f"Não foi possível analisar o pacote selecionado.\n\n{e}",
            )
        finally:
            self._fechar_conexao(con_origem)
            self._fechar_conexao(con_destino)

    def _contar_registros(self, con, tabela):
        tabela = self.firebird_service.normalizar_nome_tabela(tabela)
        cur = con.cursor()
        cur.execute(f"SELECT COUNT(*) FROM {tabela}")
        linha = cur.fetchone()
        return int(linha[0] or 0)

    def _migrar_pacote_selecionado(self):
        pacote = self._obter_pacote_selecionado()
        if not pacote:
            messagebox.showwarning("Pacote", "Selecione um pacote.")
            return

        selecionados = self.lst_pacotes.curselection() if self.lst_pacotes is not None else []
        if selecionados and not self._pacote_esta_liberado(selecionados[0]):
            messagebox.showwarning(
                "Pacote bloqueado",
                "Processe primeiro o pacote Cadastros básicos antes do financeiro em aberto.",
            )
            return

        resposta = messagebox.askyesno(
            "Confirmar migração",
            f"Deseja migrar o pacote '{pacote['nome']}'?",
        )
        if not resposta:
            return

        if pacote["nome"] == "Financeiro em aberto":
            self._migrar_financeiro_em_aberto()
            return

        self._migrar_lista_tabelas(pacote["tabelas"], pacote["nome"])


    def _obter_chave_upsert_tabela(self, tabela):
        tabela = (tabela or "").strip().upper()

        mapa = {
            # ==========================================================
            # CADASTROS BÁSICOS / DEFAULT DO BANCO LIMPO
            # ==========================================================
            "TB_EMPRESA": ["EMP_ID"],
            "TB_ESTADO": ["EST_ID"],
            "TB_CIDADE": ["CID_ID"],
            "TB_UNIDADE_MEDIDA": ["UN_SIGLA"],
            "TB_USU_PERFIL": ["UPL_ID"],
            "TB_USUARIO": ["USU_ID"],
            "TB_VENDEDOR": ["VDR_EMPRESA", "VDR_ID"],
            "TB_CAIXA": ["CAX_EMPRESA", "CAX_ID"],
            "TB_PLANO_CONTA": ["PLC_EMPRESA", "PLC_ID"],  
            "TB_BOLETO_CONF": ["BOLC_EMPRESA", "BOLC_ID"],   
            "TB_CONTA_BANCARIA": ["CBC_EMPRESA", "CBC_BANCO", "CBC_BANCO_AGENCIA", "CBC_NUMERO_CONTA"],                   
            "TB_BANCO_AGENCIA": ["BCA_CODIGO_BANCO", "BCA_CODIGO_AGENCIA"],
            "TB_BANCO": ["BCO_CODIGO_BANCO"],
            "TB_BANCO_AGENCIA": ["BCA_CODIGO_BANCO", "BCA_CODIGO_AGENCIA"],
            "TB_BORDERO_RECEBIMENTO": ["BDR_EMPRESA", "BDR_ID"],

            # ==========================================================
            # CLIENTES / FORNECEDORES
            # Banco multiempresa: preservar EMPRESA + ID
            # ==========================================================
            "TB_REGIAO": ["REG_ID"],
            "TB_CLIENTE_GRUPO": ["CLIG_EMPRESA", "CLIG_ID"],
            "TB_CLIENTE": ["CLI_EMPRESA", "CLI_ID"],
            "TB_FORNECEDOR": ["FOR_EMPRESA", "FOR_ID"],

            # ==========================================================
            # PRODUTOS
            # Banco multiempresa: preservar EMPRESA + ID
            # ==========================================================
            "TB_PROD_MARCA": ["PMAR_EMPRESA", "PMAR_ID"],
            "TB_PROD_GRUPO": ["PGRU_EMPRESA", "PGRU_ID"],
            "TB_PROD_SUB_GRUPO": ["PSGR_EMPRESA", "PSGR_GRUPO", "PSGR_ID"],
            "TB_PRODUTO": ["PRD_EMPRESA", "PRD_ID"],
            "TB_PROD_CODIGO_BARRAS": ["PRDC_EMPRESA", "PRDC_PRODUTO", "PRDC_COD_BARRAS"],

            # ==========================================================
            # FORMAS DE PAGAMENTO
            # ==========================================================
            "TB_FORMA_PAGTO": ["FPG_EMPRESA", "FPG_ID"],
            #"TB_FORMA_PAGTO_PARCELAS": ["FPGP_EMPRESA", "FPGP_FORMA_PAGTO", "FPGP_PARCELA"],
            "TB_FORMA_PAGTO_PARCELAS": ["FPGP_EMPRESA", "FPGP_FORMA_PAGTO", "FPGP_SEQUENCIA"],            
        }

        return mapa.get(tabela)

    def _registro_existe_destino(self, con_destino, tabela, campos_chave, dados):
        where = " AND ".join([f"{campo} = ?" for campo in campos_chave])
        valores = [dados[campo] for campo in campos_chave]

        cur = con_destino.cursor()
        cur.execute(
            f"SELECT FIRST 1 1 FROM {tabela} WHERE {where}",
            valores,
        )
        return cur.fetchone() is not None

    def _executar_update_destino(self, con_destino, tabela, dados, campos_chave):
        colunas_update = [col for col in dados.keys() if col not in campos_chave]

        if not colunas_update:
            return

        set_sql = ", ".join([f"{col} = ?" for col in colunas_update])
        where_sql = " AND ".join([f"{campo} = ?" for campo in campos_chave])

        sql = f"UPDATE {tabela} SET {set_sql} WHERE {where_sql}"

        valores = [dados[col] for col in colunas_update]
        valores.extend([dados[campo] for campo in campos_chave])

        cur = con_destino.cursor()
        cur.execute(sql, valores)
    def _limpar_valor_para_firebird(self, valor):
        if isinstance(valor, str):
            valor = valor.replace("\ufffd", "")
            valor = valor.replace("�", "")
            return valor

        return valor

    def _executar_insert_destino(self, con_destino, tabela, dados):
        if not dados:
            raise RuntimeError(f"Nenhum dado montado para inserir na tabela {tabela}.")

        colunas = list(dados.keys())
        placeholders = ", ".join(["?"] * len(colunas))
        sql = (
            f"INSERT INTO {tabela} ({', '.join(colunas)}) "
            f"VALUES ({placeholders})"
        )

        cur = con_destino.cursor()
        cur.execute(sql, [dados[col] for col in colunas])

    def _montar_dados_registro_por_colunas(self, registro, colunas_origem, colunas_destino):
        mapa_indices = {nome: i for i, nome in enumerate(colunas_origem)}
        colunas_comuns = [col for col in colunas_destino if col in mapa_indices]

        dados = {}
        for col in colunas_comuns:
            valor = registro[mapa_indices[col]]
            dados[col] = self._limpar_valor_para_firebird(valor)

        return dados
    
    def _migrar_tabela_selecionada(self):
        tabela = self._obter_tabela_selecionada()
        if not tabela:
            messagebox.showwarning("Tabela", "Selecione uma tabela.")
            return

        resposta = messagebox.askyesno(
            "Confirmar migração",
            f"Deseja migrar apenas a tabela '{tabela}'?",
        )
        if not resposta:
            return

        self._migrar_lista_tabelas([tabela], f"Tabela isolada: {tabela}")

    def _migrar_financeiro_em_aberto(self):
        con_origem = None
        con_destino = None

        total_lidos = 0
        total_inseridos = 0
        mapa_recebimento = {}
        maiores_por_empresa = {}

        try:
            dados_origem = self._obter_dados_conexao("origem")
            dados_destino = self._obter_dados_conexao("destino")

            con_origem, _ = self._conectar_automatico(dados_origem)
            con_destino, _ = self._conectar_automatico(dados_destino)

            self._escrever_log("")
            self._escrever_log("=" * 70)
            self._escrever_log("Iniciando financeiro em aberto com renumeração controlada.")
            self._escrever_log("=" * 70)

            # ==========================================================
            # 1) FORMAS DE PAGAMENTO
            # ==========================================================
            for tabela_auxiliar in (
                "TB_FORMA_PAGTO",
                "TB_FORMA_PAGTO_PARCELAS",
                "TB_CAIXA",
                "TB_PLANO_CONTA",
                "TB_BANCO",
                "TB_BANCO_AGENCIA",
                "TB_CONTA_BANCARIA",
                "TB_BOLETO_CONF",
                "TB_BORDERO_RECEBIMENTO",
                #"TB_RECEBIMENTO",
                #"TB_RECEBIMENTO_ITEM",
            ):
                self._escrever_log(f"Importando tabela auxiliar: {tabela_auxiliar}")

                lidos, inseridos = self._migrar_tabela(
                    con_origem,
                    con_destino,
                    tabela_auxiliar,
                )

                con_destino.commit()

                total_lidos += lidos
                total_inseridos += inseridos

                self._escrever_log(
                    f"[OK] {tabela_auxiliar} | lidos={lidos} | inseridos={inseridos}"
                )

            # ==========================================================
            # 2) RECEBIMENTOS EM ABERTO COM NOVO REC_ID
            # ==========================================================
            tabela = "TB_RECEBIMENTO"

            colunas_destino = [
                campo["nome"]
                for campo in self.firebird_service.obter_campos_tabela(con_destino, tabela)
            ]

            cur_origem = con_origem.cursor()
            cur_origem.execute(self._montar_sql_origem_tabela(tabela))

            descricao = cur_origem.description
            colunas_origem = [desc[0].strip() for desc in descricao]
            registros = cur_origem.fetchall()

            self._escrever_log(
                f"TB_RECEBIMENTO: {len(registros)} recebimento(s) em aberto encontrado(s)."
            )

            if self.pb_execucao is not None:
                self.pb_execucao.configure(maximum=max(len(registros), 1), value=0)

            proximo_rec_id_por_empresa = {}

            for registro in registros:
                dados = self._montar_dados_registro_por_colunas(
                    registro,
                    colunas_origem,
                    colunas_destino,
                )

                if not dados:
                    continue

                empresa = dados.get("REC_EMPRESA")
                rec_id_antigo = dados.get("REC_ID")

                if empresa is None or rec_id_antigo is None:
                    raise RuntimeError(
                        "TB_RECEBIMENTO sem REC_EMPRESA ou REC_ID. Importação interrompida."
                    )

                if empresa not in proximo_rec_id_por_empresa:
                    proximo_rec_id_por_empresa[empresa] = 1

                rec_id_novo = proximo_rec_id_por_empresa[empresa]
                proximo_rec_id_por_empresa[empresa] += 1

                mapa_recebimento[(empresa, rec_id_antigo)] = rec_id_novo
                maiores_por_empresa[empresa] = rec_id_novo

                observacao_original = self._normalizar_texto_observacao(
                    dados.get("REC_OBSERVACAO")
                )

                prefixo = f"ID ANTIGO TB_RECEBIMENTO: {rec_id_antigo} | "

                if observacao_original:
                    observacao_nova = prefixo + observacao_original
                else:
                    observacao_nova = prefixo.rstrip()

                dados["REC_OBSERVACAO"] = observacao_nova.encode(
                    "latin1",
                    errors="ignore",
                )

                dados["REC_ID"] = rec_id_novo

                self._executar_insert_destino(con_destino, tabela, dados)

                total_lidos += 1
                total_inseridos += 1

                if self.pb_execucao is not None:
                    self.pb_execucao.configure(value=total_lidos)

                if total_lidos == 1 or total_lidos % 50 == 0:
                    self.update_idletasks()

            con_destino.commit()

            self._escrever_log(
                f"[OK] TB_RECEBIMENTO | mapa criado com {len(mapa_recebimento)} vínculo(s)."
            )

            # ==========================================================
            # 3) RAMIFICAÇÕES OFICIAIS
            # ==========================================================
            ramificacoes = [
                "TB_RECEBIMENTO_ITEM",
                "TB_BOLETO",
                "TB_RECEBIMENTO_COBRANCA",
                "TB_BORDERO_COMP_CARTAO_REC",
                "TB_BORDERO_COBRANCA_ITEM",
                "TB_BORDERO_NEGOCIACAO_ITEM",
                #"TB_BORDERO_RECEBIMENTO",
                "TB_BORDERO_RECEBIMENTO_ITEM",
                "TB_BORDERO_RESIDUO_REC",
            ]

            for tabela_filha in ramificacoes:
                lidos, inseridos = self._migrar_ramificacao_recebimento(
                    con_origem,
                    con_destino,
                    tabela_filha,
                    mapa_recebimento,
                )

                con_destino.commit()

                total_lidos += lidos
                total_inseridos += inseridos

                self._escrever_log(
                    f"[OK] {tabela_filha} | lidos={lidos} | inseridos={inseridos}"
                )

            # ==========================================================
            # 4) SEQUENCIAL
            # ==========================================================
            self._ajustar_sequencial_recebimento(con_destino, maiores_por_empresa)
            con_destino.commit()

            resumo = (
                f"Financeiro em aberto concluído.\n\n"
                f"Recebimentos mapeados: {len(mapa_recebimento)}\n"
                f"Registros lidos/inseridos no processo: {total_lidos}\n"
                f"Registros inseridos: {total_inseridos}"
            )

            self._escrever_log("-" * 70)
            self._escrever_log(resumo.replace("\n", " | "))
            self._escrever_log("=" * 70)

            self.lbl_resumo_execucao.configure(
                text=(
                    f"Financeiro concluído | recebimentos={len(mapa_recebimento)} | "
                    f"inseridos={total_inseridos}"
                )
            )

            messagebox.showinfo("Financeiro concluído", resumo)

        except Exception as e:
            try:
                if con_destino is not None:
                    con_destino.rollback()
            except Exception:
                pass

            messagebox.showerror(
                "Erro no financeiro",
                f"Não foi possível concluir o financeiro em aberto.\n\n{e}",
            )

            self._escrever_log(f"[ERRO FINANCEIRO] {e}")

        finally:
            self._fechar_conexao(con_origem)
            self._fechar_conexao(con_destino)

    def _migrar_ramificacao_recebimento(
        self,
        con_origem,
        con_destino,
        tabela,
        mapa_recebimento,
    ):
        tabela = self.firebird_service.normalizar_nome_tabela(tabela)

        campo_recebimento = self._obter_campo_vinculo_recebimento(tabela)
        campo_empresa = self._obter_campo_empresa_vinculo_recebimento(tabela)

        if not campo_recebimento or not campo_empresa:
            raise RuntimeError(
                f"Campos de vínculo não configurados para a tabela {tabela}."
            )

        colunas_destino = [
            campo["nome"]
            for campo in self.firebird_service.obter_campos_tabela(con_destino, tabela)
        ]

        cur_origem = con_origem.cursor()
        cur_origem.execute(self._montar_sql_origem_tabela(tabela))

        descricao = cur_origem.description
        if not descricao:
            return 0, 0

        colunas_origem = [desc[0].strip() for desc in descricao]
        registros = cur_origem.fetchall()

        lidos = 0
        inseridos = 0

        for registro in registros:
            lidos += 1

            dados = self._montar_dados_registro_por_colunas(
                registro,
                colunas_origem,
                colunas_destino,
            )

            if not dados:
                continue

            empresa = dados.get(campo_empresa)
            recebimento_antigo = dados.get(campo_recebimento)

            chave_mapa = (empresa, recebimento_antigo)

            if chave_mapa not in mapa_recebimento:
                raise RuntimeError(
                    f"{tabela}: recebimento antigo não encontrado no mapa. "
                    f"empresa={empresa}, recebimento={recebimento_antigo}"
                )

            dados[campo_recebimento] = mapa_recebimento[chave_mapa]

            self._executar_insert_destino(con_destino, tabela, dados)
            inseridos += 1

            if lidos == 1 or lidos % 50 == 0 or lidos == len(registros):
                self.update_idletasks()

        return lidos, inseridos


    def _migrar_lista_tabelas(self, tabelas, titulo_execucao):
        con_origem = None
        con_destino = None

        total_tabelas = 0
        sucesso_tabelas = 0
        falha_tabelas = 0
        total_lidos = 0
        total_inseridos = 0

        try:
            dados_origem = self._obter_dados_conexao("origem")
            dados_destino = self._obter_dados_conexao("destino")

            con_origem, _ = self._conectar_automatico(dados_origem)
            con_destino, _ = self._conectar_automatico(dados_destino)

            self._escrever_log("")
            self._escrever_log("=" * 70)
            self._escrever_log(f"Iniciando execução: {titulo_execucao}")
            self._escrever_log(f"Somente 10 registros: {'SIM' if self.var_somente_10.get() else 'NÃO'}")
            self._escrever_log(f"Limpar destino antes: {'SIM' if self.var_limpar_destino.get() else 'NÃO'}")
            self._escrever_log(f"Continuar em caso de erro: {'SIM' if self.var_continuar_erro.get() else 'NÃO'}")
            
            self._escrever_log("=" * 70)

            if self.pb_execucao is not None:
                self.pb_execucao.configure(maximum=1, value=0)

            if self.lbl_progresso_execucao is not None:
                self.lbl_progresso_execucao.configure(
                    text=f"Iniciando execução: {titulo_execucao}"
                )

            self.update_idletasks()

            for tabela in tabelas:
                total_tabelas += 1
                self.lbl_resumo_execucao.configure(text=f"Migrando tabela: {tabela} ...")

                if self.lbl_progresso_execucao is not None:
                    self.lbl_progresso_execucao.configure(
                        text=f"Iniciando tabela {total_tabelas}/{len(tabelas)}: {tabela}"
                    )

                if self.pb_execucao is not None:
                    total_registros_tabela = self._contar_registros_origem_migracao(
                        con_origem,
                        tabela,
                    )
                    self.pb_execucao.configure(
                        maximum=max(total_registros_tabela, 1),
                        value=0,
                    )

                self.update_idletasks()

                try:
                    lidos, inseridos = self._migrar_tabela(con_origem, con_destino, tabela)

                    try:
                        con_destino.commit()
                    except Exception:
                        pass

                    total_lidos += lidos
                    total_inseridos += inseridos
                    sucesso_tabelas += 1
                    self._escrever_log(
                        f"[OK] {tabela} | lidos={lidos} | inseridos={inseridos}"
                    )
                except Exception as e:
                    falha_tabelas += 1
                    self._escrever_log(f"[ERRO] {tabela} | {e}")

                    try:
                        con_destino.rollback()
                    except Exception:
                        pass

                    if not self.var_continuar_erro.get():
                        raise RuntimeError(f"Execução interrompida na tabela {tabela}: {e}")

                finally:
                    self.update_idletasks()

            try:
                con_destino.commit()
            except Exception:
                pass

            resumo = (
                f"Execução concluída.\n\n"
                f"Tabelas processadas: {total_tabelas}\n"
                f"Tabelas com sucesso: {sucesso_tabelas}\n"
                f"Tabelas com falha: {falha_tabelas}\n"
                f"Registros lidos: {total_lidos}\n"
                f"Registros inseridos: {total_inseridos}"
            )

            self._escrever_log("-" * 70)
            self._escrever_log(resumo.replace("\n", " | "))
            self._escrever_log("=" * 70)

            
            self.lbl_resumo_execucao.configure(
                text=(
                    f"Concluído | sucesso={sucesso_tabelas} | "
                    f"falha={falha_tabelas} | inseridos={total_inseridos}"
                )
            )

            if self.lbl_progresso_execucao is not None:
                self.lbl_progresso_execucao.configure(
                    text=(
                        f"Concluído: {titulo_execucao} | "
                        f"sucesso={sucesso_tabelas} | falha={falha_tabelas}"
                    )
                )

            if titulo_execucao == "Cadastros básicos" and falha_tabelas == 0:
                self.base_inicial_processada = True
                self._atualizar_pacotes_liberados()
                self._escrever_log(
                    "Cadastros básicos processados com sucesso. Financeiro em aberto liberado."
                )

            messagebox.showinfo("Migração concluída", resumo)



        except Exception as e:
            messagebox.showerror(
                "Erro na migração",
                f"Não foi possível concluir a migração.\n\n{e}",
            )
        finally:
            self._fechar_conexao(con_origem)
            self._fechar_conexao(con_destino)

    def _montar_sql_origem_tabela(self, tabela):
        tabela = self.firebird_service.normalizar_nome_tabela(tabela)

        first = "FIRST 10 " if self.var_somente_10.get() else ""

        if tabela == "TB_RECEBIMENTO":
            return (
                f"SELECT {first}* "
                f"FROM TB_RECEBIMENTO "
                f"WHERE REC_STATUS IN ('AB', 'PB') "
                f"  AND COALESCE(REC_ABERTO, 'S') = 'S'"
            )

        if tabela == "TB_RECEBIMENTO_ITEM":
            return (
                f"SELECT {first}i.* "
                f"FROM TB_RECEBIMENTO_ITEM i "
                f"WHERE EXISTS ( "
                f"    SELECT 1 "
                f"    FROM TB_RECEBIMENTO r "
                f"    WHERE r.REC_EMPRESA = i.RIT_EMPRESA "
                f"      AND r.REC_ID = i.RIT_RECEBIMENTO "
                f"      AND r.REC_STATUS IN ('AB', 'PB') "
                f"      AND COALESCE(r.REC_ABERTO, 'S') = 'S' "
                f")"
            )

        campo_recebimento = self._obter_campo_vinculo_recebimento(tabela)

        if campo_recebimento:
            alias = "x"
            campo_empresa = None

            if tabela == "TB_BOLETO":
                campo_empresa = "BOL_EMPRESA"
            elif tabela == "TB_RECEBIMENTO_COBRANCA":
                campo_empresa = "RCC_EMPRESA"
            elif tabela == "TB_BORDERO_COMP_CARTAO_REC":
                campo_empresa = "BDCR_EMPRESA"
            elif tabela == "TB_BORDERO_COBRANCA_ITEM":
                campo_empresa = "BCI_EMPRESA"
            elif tabela == "TB_BORDERO_NEGOCIACAO_ITEM":
                campo_empresa = "BNI_EMPRESA"
            elif tabela == "TB_BORDERO_RECEBIMENTO_ITEM":
                campo_empresa = "BRI_EMPRESA"
            elif tabela == "TB_BORDERO_RESIDUO_REC":
                campo_empresa = "BDSR_EMPRESA"

            if campo_empresa:
                return (
                    f"SELECT {first}{alias}.* "
                    f"FROM {tabela} {alias} "
                    f"WHERE EXISTS ( "
                    f"    SELECT 1 "
                    f"    FROM TB_RECEBIMENTO r "
                    f"    WHERE r.REC_EMPRESA = {alias}.{campo_empresa} "
                    f"      AND r.REC_ID = {alias}.{campo_recebimento} "
                    f"      AND r.REC_STATUS IN ('AB', 'PB') "
                    f"      AND COALESCE(r.REC_ABERTO, 'S') = 'S' "
                    f")"
                )

        if self.var_somente_10.get():
            return f"SELECT FIRST 10 * FROM {tabela}"

        return f"SELECT * FROM {tabela}"

    def _montar_sql_count_origem_tabela(self, tabela):
        tabela = self.firebird_service.normalizar_nome_tabela(tabela)

        if self.var_somente_10.get():
            return None

        if tabela == "TB_RECEBIMENTO":
            return (
                "SELECT COUNT(*) "
                "FROM TB_RECEBIMENTO "
                "WHERE REC_STATUS IN ('AB', 'PB') "
                "  AND COALESCE(REC_ABERTO, 'S') = 'S'"
            )

        if tabela == "TB_RECEBIMENTO_ITEM":
            return (
                "SELECT COUNT(*) "
                "FROM TB_RECEBIMENTO_ITEM i "
                "WHERE EXISTS ( "
                "    SELECT 1 "
                "    FROM TB_RECEBIMENTO r "
                "    WHERE r.REC_EMPRESA = i.RIT_EMPRESA "
                "      AND r.REC_ID = i.RIT_RECEBIMENTO "
                "      AND r.REC_STATUS IN ('AB', 'PB') "
                "      AND COALESCE(r.REC_ABERTO, 'S') = 'S' "
                ")"
            )

        campo_recebimento = self._obter_campo_vinculo_recebimento(tabela)

        if campo_recebimento:
            alias = "x"
            campo_empresa = None

            if tabela == "TB_BOLETO":
                campo_empresa = "BOL_EMPRESA"
            elif tabela == "TB_RECEBIMENTO_COBRANCA":
                campo_empresa = "RCC_EMPRESA"
            elif tabela == "TB_BORDERO_COMP_CARTAO_REC":
                campo_empresa = "BDCR_EMPRESA"
            elif tabela == "TB_BORDERO_COBRANCA_ITEM":
                campo_empresa = "BCI_EMPRESA"
            elif tabela == "TB_BORDERO_NEGOCIACAO_ITEM":
                campo_empresa = "BNI_EMPRESA"
            elif tabela == "TB_BORDERO_RECEBIMENTO_ITEM":
                campo_empresa = "BRI_EMPRESA"
            elif tabela == "TB_BORDERO_RESIDUO_REC":
                campo_empresa = "BDSR_EMPRESA"

            if campo_empresa:
                return (
                    f"SELECT COUNT(*) "
                    f"FROM {tabela} {alias} "
                    f"WHERE EXISTS ( "
                    f"    SELECT 1 "
                    f"    FROM TB_RECEBIMENTO r "
                    f"    WHERE r.REC_EMPRESA = {alias}.{campo_empresa} "
                    f"      AND r.REC_ID = {alias}.{campo_recebimento} "
                    f"      AND r.REC_STATUS IN ('AB', 'PB') "
                    f"      AND COALESCE(r.REC_ABERTO, 'S') = 'S' "
                    f")"
                )

        return f"SELECT COUNT(*) FROM {tabela}"


    def _contar_registros_origem_migracao(self, con_origem, tabela):
        tabela = self.firebird_service.normalizar_nome_tabela(tabela)

        if self.var_somente_10.get():
            return 10

        sql_count = self._montar_sql_count_origem_tabela(tabela)

        if not sql_count:
            return 10

        cur = con_origem.cursor()
        cur.execute(sql_count)
        linha = cur.fetchone()

        return int(linha[0] or 0)


    def _migrar_tabela(self, con_origem, con_destino, tabela):
        tabela = self.firebird_service.normalizar_nome_tabela(tabela)

        if tabela in self._obter_tabelas_financeiro_controlado():
            raise RuntimeError(
                f"A tabela {tabela} pertence ao financeiro em aberto e precisa da rotina "
                f"controlada com mapa REC_ID antigo -> novo. "
                f"Use apenas a análise por enquanto. A migração será liberada no próximo patch."
            )

        colunas_destino = [
            campo["nome"]
            for campo in self.firebird_service.obter_campos_tabela(con_destino, tabela)
        ]

        if not colunas_destino:
            raise RuntimeError(f"Nenhuma coluna encontrada na tabela destino {tabela}.")

        campo_chave_upsert = self._obter_chave_upsert_tabela(tabela)

        if self.var_limpar_destino.get() and not campo_chave_upsert:
            self._limpar_tabela_destino(con_destino, tabela)
            self._escrever_log(f"Destino limpo: {tabela}")

        cur_origem = con_origem.cursor()

        sql_origem = self._montar_sql_origem_tabela(tabela)

        if tabela in ("TB_RECEBIMENTO", "TB_RECEBIMENTO_ITEM"):
            self._escrever_log(f"[FILTRO] {tabela}: migrando somente financeiro em aberto.")

        cur_origem.execute(sql_origem)



        descricao = cur_origem.description
        if not descricao:
            return 0, 0

        colunas_origem = [desc[0].strip() for desc in descricao]

        registros = cur_origem.fetchall()

        total_registros_tabela = len(registros)

        if self.pb_execucao is not None:
            self.pb_execucao.configure(
                maximum=max(total_registros_tabela, 1),
                value=0,
            )

        lidos = 0
        inseridos = 0
        atualizados = 0

        for registro in registros:
            lidos += 1

            if self.lbl_progresso_execucao is not None:
                self.lbl_progresso_execucao.configure(
                    text=f"{tabela}: registro {lidos}/{total_registros_tabela}"
                )

            if self.pb_execucao is not None:
                self.pb_execucao.configure(value=lidos)

            if lidos == 1 or lidos % 50 == 0 or lidos == total_registros_tabela:
                self.update_idletasks()            

            dados = self._montar_dados_registro_por_colunas(
                registro,
                colunas_origem,
                colunas_destino,
            )

            if not dados:
                continue

            if campo_chave_upsert:
                campos_chave = campo_chave_upsert

                for campo_chave in campos_chave:
                    if campo_chave not in dados:
                        raise RuntimeError(
                            f"A chave {campo_chave} não foi encontrada nos dados da tabela {tabela}."
                        )

                existe = self._registro_existe_destino(
                    con_destino,
                    tabela,
                    campos_chave,
                    dados,
                )

                if existe:
                    self._executar_update_destino(
                        con_destino,
                        tabela,
                        dados,
                        campos_chave,
                    )
                    atualizados += 1
                else:
                    self._executar_insert_destino(
                        con_destino,
                        tabela,
                        dados,
                    )
                    inseridos += 1

            else:
                self._executar_insert_destino(
                    con_destino,
                    tabela,
                    dados,
                )
                inseridos += 1

        if campo_chave_upsert:
            self._escrever_log(
                f"{tabela}: lidos={lidos} | inseridos={inseridos} | atualizados={atualizados}"
            )

        return lidos, inseridos

    def _limpar_tabela_destino(self, con_destino, tabela):
        tabela = self.firebird_service.normalizar_nome_tabela(tabela)
        cur = con_destino.cursor()
        cur.execute(f"DELETE FROM {tabela}")