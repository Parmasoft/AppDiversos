from __future__ import annotations

from configparser import ConfigParser
from dataclasses import dataclass
from pathlib import Path


ARQUIVO_CONFIG_PADRAO = Path(__file__).resolve().parent / "config.ini"


@dataclass(frozen=True)
class ConfigAplicacao:
    cliente: str
    identificador: str
    intervalo_segundos: int


@dataclass(frozen=True)
class ConfigFirebird:
    dsn: str
    usuario: str
    senha: str
    charset: str


@dataclass(frozen=True)
class ConfigApi:
    url_base: str
    timeout_segundos: int
    token: str
    verificar_ssl: bool


@dataclass(frozen=True)
class ConfigSincronizacaoProdutos:
    ativo: bool
    sql: str
    tamanho_lote: int


@dataclass(frozen=True)
class ConfigLog:
    nivel: str
    arquivo: str
    rotacao_mb: int
    backups: int


@dataclass(frozen=True)
class Configuracao:
    aplicacao: ConfigAplicacao
    firebird: ConfigFirebird
    api: ConfigApi
    sincronizacao_produtos: ConfigSincronizacaoProdutos
    log: ConfigLog


def _obrigatorio(parser: ConfigParser, secao: str, chave: str) -> str:
    if not parser.has_option(secao, chave):
        raise ValueError(f"Configuração obrigatória ausente: [{secao}] {chave}")

    valor = parser.get(secao, chave).strip()
    if not valor:
        raise ValueError(f"Configuração vazia: [{secao}] {chave}")

    return valor


def carregar_configuracao(caminho: Path | None = None) -> Configuracao:
    arquivo = caminho or ARQUIVO_CONFIG_PADRAO

    if not arquivo.exists():
        raise FileNotFoundError(f"Arquivo de configuração não encontrado: {arquivo}")

    parser = ConfigParser(interpolation=None)
    parser.read(arquivo, encoding="utf-8")

    aplicacao = ConfigAplicacao(
        cliente=_obrigatorio(parser, "aplicacao", "cliente"),
        identificador=_obrigatorio(parser, "aplicacao", "identificador"),
        intervalo_segundos=parser.getint("aplicacao", "intervalo_segundos", fallback=300),
    )

    firebird = ConfigFirebird(
        dsn=_obrigatorio(parser, "firebird", "dsn"),
        usuario=_obrigatorio(parser, "firebird", "usuario"),
        senha=_obrigatorio(parser, "firebird", "senha"),
        charset=parser.get("firebird", "charset", fallback="ISO8859_1").strip(),
    )

    api = ConfigApi(
        url_base=_obrigatorio(parser, "api", "url_base").rstrip("/"),
        timeout_segundos=parser.getint("api", "timeout_segundos", fallback=60),
        token=parser.get("api", "token", fallback="").strip(),
        verificar_ssl=parser.getboolean("api", "verificar_ssl", fallback=True),
    )

    sincronizacao_produtos = ConfigSincronizacaoProdutos(
        ativo=parser.getboolean("sincronizacao_produtos", "ativo", fallback=True),
        sql=_obrigatorio(parser, "sincronizacao_produtos", "sql"),
        tamanho_lote=parser.getint(
            "sincronizacao_produtos", "tamanho_lote", fallback=500
        ),
    )

    log = ConfigLog(
        nivel=parser.get("log", "nivel", fallback="INFO").strip().upper(),
        arquivo=parser.get(
            "log", "arquivo", fallback="logs/ParmaCloudSync.log"
        ).strip(),
        rotacao_mb=parser.getint("log", "rotacao_mb", fallback=10),
        backups=parser.getint("log", "backups", fallback=5),
    )

    if aplicacao.intervalo_segundos < 10:
        raise ValueError("intervalo_segundos deve ser igual ou maior que 10.")

    if sincronizacao_produtos.tamanho_lote <= 0:
        raise ValueError("tamanho_lote deve ser maior que zero.")

    return Configuracao(
        aplicacao=aplicacao,
        firebird=firebird,
        api=api,
        sincronizacao_produtos=sincronizacao_produtos,
        log=log,
    )
