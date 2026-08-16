from pydantic import BaseModel, EmailStr, Field


class CustomerCreate(BaseModel):
    nombre: str = Field(
        min_length=1,
        max_length=150,
    )

    email: EmailStr

    numero_identidad: str = Field(
        min_length=1,
        max_length=100,
    )


class CustomerUpdate(BaseModel):
    nombre: str | None = Field(
        default=None,
        min_length=1,
        max_length=150,
    )

    email: EmailStr | None = None

    numero_identidad: str | None = Field(
        default=None,
        min_length=1,
        max_length=100,
    )


class CustomerResponse(BaseModel):
    id: int
    nombre: str
    email: EmailStr
    numero_identidad: str
