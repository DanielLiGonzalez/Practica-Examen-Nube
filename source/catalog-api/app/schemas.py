from decimal import Decimal

from pydantic import BaseModel, ConfigDict, Field


class ProductCreate(BaseModel):
    nombre: str = Field(
        min_length=1,
        max_length=150,
    )

    precio: Decimal = Field(
        ge=0,
    )

    stock: int = Field(
        default=0,
        ge=0,
    )

    descripcion: str | None = None
    imagen: str | None = None


class ProductUpdate(BaseModel):
    nombre: str | None = Field(
        default=None,
        min_length=1,
        max_length=150,
    )

    precio: Decimal | None = Field(
        default=None,
        ge=0,
    )

    stock: int | None = Field(
        default=None,
        ge=0,
    )

    descripcion: str | None = None
    imagen: str | None = None


class ProductResponse(BaseModel):
    model_config = ConfigDict(
        from_attributes=True,
    )

    id: int
    nombre: str
    precio: Decimal
    stock: int
    descripcion: str | None
    imagen: str | None
