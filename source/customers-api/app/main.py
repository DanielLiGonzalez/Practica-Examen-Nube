from fastapi import Depends, FastAPI, HTTPException, Response, status
from sqlalchemy import select, text
from sqlalchemy.exc import IntegrityError, SQLAlchemyError
from sqlalchemy.orm import Session

from app.crypto import decrypt_identity, encrypt_identity
from app.database import get_db
from app.models import Customer
from app.schemas import (
    CustomerCreate,
    CustomerResponse,
    CustomerUpdate,
)


app = FastAPI(
    title="Cafe Boreal - Customers API",
    version="1.0.0",
)


def customer_response(
    customer: Customer,
) -> CustomerResponse:
    return CustomerResponse(
        id=customer.id,
        nombre=customer.nombre,
        email=customer.email,
        numero_identidad=decrypt_identity(
            customer.numero_identidad
        ),
    )


@app.get("/healthz")
def healthz(
    db: Session = Depends(get_db),
):
    try:
        db.execute(text("SELECT 1"))

        return {
            "status": "ok",
            "service": "customers-api",
            "database": "ok",
        }

    except SQLAlchemyError as exc:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Database unavailable",
        ) from exc


@app.get(
    "/customers",
    response_model=list[CustomerResponse],
)
def list_customers(
    db: Session = Depends(get_db),
):
    customers = db.scalars(
        select(Customer).order_by(Customer.id)
    ).all()

    return [
        customer_response(customer)
        for customer in customers
    ]


@app.get(
    "/customers/{customer_id}",
    response_model=CustomerResponse,
)
def get_customer(
    customer_id: int,
    db: Session = Depends(get_db),
):
    customer = db.get(Customer, customer_id)

    if customer is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Customer not found",
        )

    return customer_response(customer)


@app.post(
    "/customers",
    response_model=CustomerResponse,
    status_code=status.HTTP_201_CREATED,
)
def create_customer(
    payload: CustomerCreate,
    db: Session = Depends(get_db),
):
    customer = Customer(
        nombre=payload.nombre,
        email=str(payload.email),
        numero_identidad=encrypt_identity(
            payload.numero_identidad
        ),
    )

    db.add(customer)

    try:
        db.commit()
    except IntegrityError as exc:
        db.rollback()

        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Email already exists",
        ) from exc

    db.refresh(customer)

    return customer_response(customer)


@app.put(
    "/customers/{customer_id}",
    response_model=CustomerResponse,
)
def update_customer(
    customer_id: int,
    payload: CustomerUpdate,
    db: Session = Depends(get_db),
):
    customer = db.get(Customer, customer_id)

    if customer is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Customer not found",
        )

    changes = payload.model_dump(
        exclude_unset=True,
    )

    if "email" in changes:
        changes["email"] = str(changes["email"])

    if "numero_identidad" in changes:
        changes["numero_identidad"] = encrypt_identity(
            changes["numero_identidad"]
        )

    for field, value in changes.items():
        setattr(customer, field, value)

    try:
        db.commit()
    except IntegrityError as exc:
        db.rollback()

        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Email already exists",
        ) from exc

    db.refresh(customer)

    return customer_response(customer)


@app.delete(
    "/customers/{customer_id}",
    status_code=status.HTTP_204_NO_CONTENT,
)
def delete_customer(
    customer_id: int,
    db: Session = Depends(get_db),
):
    customer = db.get(Customer, customer_id)

    if customer is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Customer not found",
        )

    db.delete(customer)
    db.commit()

    return Response(
        status_code=status.HTTP_204_NO_CONTENT,
    )
