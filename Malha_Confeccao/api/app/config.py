import os


class Config:
    @classmethod
    def from_environment(cls):
        """Lê o ambiente no instante de criar a aplicação, não na importação."""
        return {
            "API_HOST": os.getenv("MALHA_API_HOST", "127.0.0.1"),
            "API_PORT": int(os.getenv("MALHA_API_PORT", "5056")),
            "API_DEBUG": os.getenv("MALHA_API_DEBUG", "0") == "1",
            "FB_HOST": os.getenv("FB_HOST", "localhost"),
            "FB_PORT": int(os.getenv("FB_PORT", "3050")),
            "FB_DATABASE": os.getenv("FB_DATABASE", ""),
            "FB_USER": os.getenv("FB_USER", ""),
            "FB_PASSWORD": os.getenv("FB_PASSWORD", ""),
            "FB_CHARSET": os.getenv("FB_CHARSET", "WIN1252"),
            "JSON_SORT_KEYS": False,
        }
