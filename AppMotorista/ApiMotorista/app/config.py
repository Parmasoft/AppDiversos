import os


class Config:
    FB_DATABASE = os.getenv("FB_DATABASE", "")
    FB_HOST = os.getenv("FB_HOST", "localhost")
    FB_PORT = int(os.getenv("FB_PORT", "3050"))
    FB_USER = os.getenv("FB_USER", "SYSDBA")
    FB_PASSWORD = os.getenv("FB_PASSWORD", "")
    FB_CHARSET = os.getenv("FB_CHARSET", "WIN1252")

    ACCESS_TOKEN_MINUTES = int(os.getenv("ACCESS_TOKEN_MINUTES", "15"))
    REFRESH_TOKEN_DAYS = int(os.getenv("REFRESH_TOKEN_DAYS", "30"))

    JSON_SORT_KEYS = False
    MAX_CONTENT_LENGTH = 16 * 1024

