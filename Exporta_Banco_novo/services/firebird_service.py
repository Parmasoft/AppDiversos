import re
from pathlib import Path

try:
    import fdb
except ImportError:
    fdb = None

try:
    from firebird.driver import connect as fb_driver_connect
    from firebird.driver import driver_config
except ImportError:
    fb_driver_connect = None
    driver_config = None


class FirebirdService:
    def detectar_ambiente_firebird(self):
        candidatos = []
        vistos = set()

        bases = [
            Path(r"C:\Program Files\Firebird"),
            Path(r"C:\Program Files (x86)\Firebird"),
            Path(r"C:\Firebird"),
        ]

        for base in bases:
            if not base.exists():
                continue

            for pasta in base.rglob("*"):
                if not pasta.is_dir():
                    continue

                nome = pasta.name.upper()
                if "FIREBIRD" not in nome:
                    continue

                dll = pasta / "fbclient.dll"
                if not dll.exists():
                    dll = pasta / "bin" / "fbclient.dll"
                    if not dll.exists():
                        continue

                versao = self._extrair_versao_firebird(str(pasta))
                conf = dll.parent / "firebird.conf"
                if not conf.exists():
                    conf = dll.parent.parent / "firebird.conf"

                porta = self._ler_porta_firebird_conf(conf)
                item = {
                    "versao": versao,
                    "dll": str(dll),
                    "porta": porta,
                    "pasta": str(pasta),
                    "familia": self._familia_firebird(versao),
                }

                chave = (item["versao"], item["dll"])
                if chave not in vistos:
                    vistos.add(chave)
                    candidatos.append(item)

        candidatos.sort(key=lambda x: (self._versao_para_numero(x["versao"]), x["dll"]))
        return candidatos

    def montar_texto_ambiente(self, ambiente_firebird):
        itens = []

        if not ambiente_firebird:
            itens.append("Nenhuma instalação local do Firebird foi detectada automaticamente.")
        else:
            partes = []
            for item in ambiente_firebird:
                porta = item["porta"] or "?"
                partes.append(f"FB {item['versao']} (porta {porta})")
            itens.append("Ambiente Firebird detectado: " + ", ".join(partes) + ".")

        itens.append("fdb OK." if fdb is not None else "fdb não instalado.")
        itens.append("firebird-driver OK." if fb_driver_connect is not None else "firebird-driver não instalado.")
        return "  ".join(itens)

    def porta_padrao_detectada(self, ambiente_firebird):
        for item in reversed(ambiente_firebird):
            if item["porta"]:
                return item["porta"]
        return "3050"

    def conectar_automatico(self, dados, ambiente_firebird):
        if not dados["banco"]:
            raise ValueError("Informe o caminho do banco.")

        cliente = self._resolver_cliente_preferencial(dados["porta"], ambiente_firebird)
        erros = []
        tentativas = []

        if cliente:
            if cliente["familia"] == "legacy":
                tentativas.append(("fdb", cliente))
                tentativas.append(("driver", None))
            else:
                tentativas.append(("driver", cliente))
                tentativas.append(("fdb", cliente))
        else:
            tentativas.append(("driver", None))
            tentativas.append(("fdb", None))

        usados = set()
        tentativas_filtradas = []

        for modo, cli in tentativas:
            chave = (modo, cli["dll"] if cli else None)
            if chave not in usados:
                usados.add(chave)
                tentativas_filtradas.append((modo, cli))

        for modo, cli in tentativas_filtradas:
            try:
                if modo == "driver":
                    con = self._conectar_firebird_driver(dados, cli)
                    return con, {"modo": "firebird-driver", "cliente": cli}

                if modo == "fdb":
                    con = self._conectar_fdb(dados, cli)
                    return con, {"modo": "fdb", "cliente": cli}
            except Exception as e:
                detalhe = modo
                if cli and cli.get("versao"):
                    detalhe += f" / FB {cli['versao']}"
                erros.append(f"{detalhe}: {e}")

        raise RuntimeError(
            "Nenhuma estratégia automática de conexão funcionou.\n\n"
            + "\n\n".join(erros)
        )

    def ler_tabelas(self, con):
        cur = con.cursor()
        cur.execute(
            """
            SELECT TRIM(RDB$RELATION_NAME)
            FROM RDB$RELATIONS
            WHERE COALESCE(RDB$SYSTEM_FLAG, 0) = 0
              AND RDB$VIEW_BLR IS NULL
            ORDER BY RDB$RELATION_NAME
            """
        )
        return [linha[0].strip() for linha in cur.fetchall() if linha[0]]

    def obter_campos_tabela(self, con, nome_tabela):
        nome_tabela = self.normalizar_nome_tabela(nome_tabela)
        cur = con.cursor()

        cur.execute(
            """
            SELECT
                TRIM(rf.RDB$FIELD_NAME) AS CAMPO,
                f.RDB$FIELD_TYPE,
                f.RDB$FIELD_SUB_TYPE,
                f.RDB$FIELD_LENGTH,
                f.RDB$FIELD_PRECISION,
                f.RDB$FIELD_SCALE,
                rf.RDB$NULL_FLAG
            FROM RDB$RELATION_FIELDS rf
            JOIN RDB$FIELDS f
              ON f.RDB$FIELD_NAME = rf.RDB$FIELD_SOURCE
            WHERE TRIM(rf.RDB$RELATION_NAME) = ?
            ORDER BY rf.RDB$FIELD_POSITION
            """,
            (nome_tabela,),
        )

        campos = []
        for linha in cur.fetchall():
            campo = (linha[0] or "").strip()
            field_type = linha[1]
            field_length = linha[3]
            field_precision = linha[4]
            field_scale = linha[5]
            null_flag = linha[6]

            tipo_texto = self._traduzir_tipo_firebird(
                field_type,
                field_length,
                field_precision,
                field_scale,
            )

            campos.append(
                {
                    "nome": campo,
                    "tipo": tipo_texto,
                    "obrigatorio": str(null_flag or "").strip() == "1",
                }
            )

        return campos

    def normalizar_nome_tabela(self, nome_tabela):
        nome_tabela = (nome_tabela or "").strip().upper()

        if not nome_tabela:
            raise ValueError("Informe uma tabela.")

        if not re.fullmatch(r"[A-Z0-9_$]+", nome_tabela):
            raise ValueError(
                "Nome de tabela inválido. Use uma tabela carregada pelo botão 'Ler tabelas'."
            )

        return nome_tabela

    def fechar_conexao(self, con):
        if con:
            try:
                con.close()
            except Exception:
                pass

    def has_fdb(self):
        return fdb is not None

    def has_firebird_driver(self):
        return fb_driver_connect is not None

    def _traduzir_tipo_firebird(self, field_type, field_length, field_precision, field_scale):
        mapa = {
            7: "SMALLINT",
            8: "INTEGER",
            10: "FLOAT",
            12: "DATE",
            13: "TIME",
            14: "CHAR",
            16: "BIGINT/NUMERIC",
            27: "DOUBLE",
            35: "TIMESTAMP",
            37: "VARCHAR",
            261: "BLOB",
        }

        base = mapa.get(field_type, f"TIPO_{field_type}")

        if field_type in (14, 37):
            return f"{base}({field_length})"

        if field_type == 16:
            if field_scale and int(field_scale) < 0:
                escala = abs(int(field_scale))
                if field_precision:
                    return f"NUMERIC({field_precision},{escala})"
                return f"NUMERIC(*,{escala})"
            return "BIGINT"

        return base

    def _extrair_versao_firebird(self, texto):
        texto_upper = (texto or "").upper().replace("-", "_")

        padroes = [
            r"FIREBIRD[_\s]?(\d+)[._](\d+)",
            r"FIREBIRD[_\s]?(\d+)",
        ]

        for padrao in padroes:
            m = re.search(padrao, texto_upper)
            if m:
                if len(m.groups()) >= 2:
                    return f"{m.group(1)}.{m.group(2)}"
                return m.group(1)

        return "desconhecida"

    def _familia_firebird(self, versao):
        try:
            major = int(float(str(versao)))
        except Exception:
            return "desconhecida"

        if major <= 2:
            return "legacy"
        return "moderno"

    def _versao_para_numero(self, versao):
        try:
            return float(str(versao))
        except Exception:
            return 0.0

    def _ler_porta_firebird_conf(self, caminho_conf):
        try:
            if not caminho_conf or not Path(caminho_conf).exists():
                return None

            linhas = Path(caminho_conf).read_text(
                encoding="utf-8",
                errors="ignore",
            ).splitlines()

            for linha in linhas:
                linha_limpa = linha.strip()
                if not linha_limpa or linha_limpa.startswith("#"):
                    continue
                if linha_limpa.upper().startswith("REMOTESERVICEPORT"):
                    partes = linha_limpa.split("=")
                    if len(partes) == 2:
                        return partes[1].strip()
        except Exception:
            pass

        return None

    def _resolver_cliente_preferencial(self, porta, ambiente_firebird):
        porta_txt = str(porta).strip()

        if ambiente_firebird:
            ordenados = sorted(
                ambiente_firebird,
                key=lambda x: self._versao_para_numero(x["versao"]),
                reverse=True,
            )

            for item in ordenados:
                if item["porta"] and str(item["porta"]) == porta_txt:
                    return item

            for item in ordenados:
                if porta_txt == "3050" and item["familia"] == "legacy":
                    return item

            for item in ordenados:
                if item["familia"] == "moderno":
                    return item

            return ambiente_firebird[-1]

        return None

    def _conectar_fdb(self, dados, cliente=None):
        if fdb is None:
            raise RuntimeError("Biblioteca Python 'fdb' não está instalada. Rode: pip install fdb")

        kwargs = {
            "dsn": f"{dados['servidor']}/{dados['porta']}:{dados['banco']}",
            "user": dados["usuario"],
            "password": dados["senha"],
            "charset": dados["charset"],
        }

        if cliente and cliente.get("dll"):
            kwargs["fb_library_name"] = cliente["dll"]

        return fdb.connect(**kwargs)

    def _conectar_firebird_driver(self, dados, cliente=None):
        if fb_driver_connect is None:
            raise RuntimeError(
                "Biblioteca Python 'firebird-driver' não está instalada. Rode: pip install firebird-driver"
            )

        dsn = f"{dados['servidor']}/{dados['porta']}:{dados['banco']}"

        if driver_config is not None:
            try:
                if cliente and cliente.get("dll"):
                    driver_config.fb_client_library.value = cliente["dll"]
                else:
                    driver_config.fb_client_library.value = None
            except Exception:
                pass

        kwargs = {
            "user": dados["usuario"],
            "password": dados["senha"],
            "charset": dados["charset"],
        }

        try:
            return fb_driver_connect(
                dsn=dsn,
                **kwargs,
            )
        except TypeError:
            return fb_driver_connect(
                database=dsn,
                **kwargs,
            )