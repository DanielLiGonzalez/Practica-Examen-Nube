import os
from urllib.parse import quote_plus

from sqlalchemy import create_engine
from sqlalchemy.orm import DeclarativeBase, sessionmaker


def build_database_url() -> str:
    explicit_url = os.getenv("DATABASE_URL")

    if explicit_url:
        return explicit_url

    host = os.getenv("DB_HOST", "postgres")
    port = os.getenv("DB_PORT", "5432")
    database = os.getenv("POSTGRES_DB", "cafe_boreal")
    user = os.getenv("POSTGRES_USER", "cafe_boreal")
    password = os.getenv("POSTGRES_PASSWORD")

    if not password:
        raise RuntimeError("POSTGRES_PASSWORD no está definida.")

    return (
        "postgresql+psycopg://"
        f"{quote_plus(user)}:"
        f"{quote_plus(password)}@"
        f"{host}:{port}/"
        f"{database}"
    )


DATABASE_URL = build_database_url()


class Base(DeclarativeBase):
    pass


engine = create_engine(
    DATABASE_URL,
    pool_pre_ping=True,
)


SessionLocal = sessionmaker(
    bind=engine,
    autoflush=False,
    autocommit=False,
)


def get_db():
    db = SessionLocal()

    try:
        yield db
    finally:
        db.close()
