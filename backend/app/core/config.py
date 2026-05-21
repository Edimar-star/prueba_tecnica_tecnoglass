from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8")

    DB_SERVER: str = "localhost"
    DB_NAME: str = "TecnoglassDB"
    DB_USER: str = "sa"
    DB_PASSWORD: str = ""
    # Driver 18 en Linux/Docker, Driver 17 o 18 en Windows — configurable vía .env
    DB_DRIVER: str = "ODBC Driver 18 for SQL Server"
    # Requerido en Docker con SQL Server sin certificado TLS firmado
    DB_TRUST_CERT: bool = False

    JWT_SECRET_KEY: str = "insecure-default-change-in-env"
    JWT_ALGORITHM: str = "HS256"
    JWT_EXPIRE_MINUTES: int = 480

    CORS_ORIGINS: str = "http://localhost:4200"

    @property
    def database_url(self) -> str:
        extras = ";TrustServerCertificate=yes;Encrypt=yes" if self.DB_TRUST_CERT else ""
        return (
            f"DRIVER={{{self.DB_DRIVER}}};"
            f"SERVER={self.DB_SERVER};"
            f"DATABASE={self.DB_NAME};"
            f"UID={self.DB_USER};"
            f"PWD={self.DB_PASSWORD}"
            f"{extras}"
        )

    @property
    def cors_origins_list(self) -> list[str]:
        return [o.strip() for o in self.CORS_ORIGINS.split(",")]


settings = Settings()
