from collections import defaultdict
from decimal import Decimal

from fastapi import Depends, FastAPI, HTTPException, Response, status
from sqlalchemy import select, text
from sqlalchemy.exc import SQLAlchemyError
from sqlalchemy.orm import Session, selectinload

from app.database import get_db
from app.models import Customer, Order, OrderItem, Product
from app.schemas import OrderCreate, OrderResponse, OrderUpdate


app = FastAPI(
    title="Cafe Boreal - Orders API",
    version="1.0.0",
)


def aggregate_items(items):
    quantities = defaultdict(int)

    for item in items:
        quantities[item.product_id] += item.quantity

    return dict(quantities)


def load_order(
    db: Session,
    order_id: int,
):
    statement = (
        select(Order)
        .options(selectinload(Order.items))
        .where(Order.id == order_id)
    )

    return db.scalar(statement)


def lock_products(
    db: Session,
    product_ids: set[int],
):
    if not product_ids:
        return {}

    statement = (
        select(Product)
        .where(Product.id.in_(product_ids))
        .order_by(Product.id)
        .with_for_update()
    )

    products = db.scalars(statement).all()

    return {
        product.id: product
        for product in products
    }


def validate_customer(
    db: Session,
    customer_id: int,
):
    customer = db.get(
        Customer,
        customer_id,
    )

    if customer is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Customer not found",
        )


def validate_products_exist(
    products: dict[int, Product],
    requested: dict[int, int],
):
    missing = [
        product_id
        for product_id in requested
        if product_id not in products
    ]

    if missing:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail={
                "message": "Product not found",
                "product_ids": missing,
            },
        )


def validate_stock(
    products: dict[int, Product],
    requested: dict[int, int],
):
    insufficient = []

    for product_id, quantity in requested.items():
        product = products[product_id]

        if product.stock < quantity:
            insufficient.append(
                {
                    "product_id": product_id,
                    "available": product.stock,
                    "requested": quantity,
                }
            )

    if insufficient:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail={
                "message": "Insufficient stock",
                "products": insufficient,
            },
        )


@app.get("/healthz")
def healthz(
    db: Session = Depends(get_db),
):
    try:
        db.execute(text("SELECT 1"))

        return {
            "status": "ok",
            "service": "orders-api",
            "database": "ok",
        }

    except SQLAlchemyError as exc:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Database unavailable",
        ) from exc


@app.get(
    "/orders",
    response_model=list[OrderResponse],
)
def list_orders(
    db: Session = Depends(get_db),
):
    statement = (
        select(Order)
        .options(selectinload(Order.items))
        .order_by(Order.id)
    )

    return db.scalars(statement).all()


@app.get(
    "/orders/{order_id}",
    response_model=OrderResponse,
)
def get_order(
    order_id: int,
    db: Session = Depends(get_db),
):
    order = load_order(
        db,
        order_id,
    )

    if order is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Order not found",
        )

    return order


@app.post(
    "/orders",
    response_model=OrderResponse,
    status_code=status.HTTP_201_CREATED,
)
def create_order(
    payload: OrderCreate,
    db: Session = Depends(get_db),
):
    try:
        validate_customer(
            db,
            payload.customer_id,
        )

        requested = aggregate_items(
            payload.items
        )

        products = lock_products(
            db,
            set(requested.keys()),
        )

        validate_products_exist(
            products,
            requested,
        )

        validate_stock(
            products,
            requested,
        )

        order = Order(
            customer_id=payload.customer_id,
            total=Decimal("0.00"),
        )

        db.add(order)
        db.flush()

        total = Decimal("0.00")

        for product_id, quantity in requested.items():
            product = products[product_id]

            unit_price = product.precio
            line_total = unit_price * quantity

            product.stock -= quantity
            total += line_total

            db.add(
                OrderItem(
                    order_id=order.id,
                    product_id=product_id,
                    quantity=quantity,
                    unit_price=unit_price,
                )
            )

        order.total = total

        db.commit()

        return load_order(
            db,
            order.id,
        )

    except HTTPException:
        db.rollback()
        raise

    except SQLAlchemyError as exc:
        db.rollback()

        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Database operation failed",
        ) from exc


@app.put(
    "/orders/{order_id}",
    response_model=OrderResponse,
)
def update_order(
    order_id: int,
    payload: OrderUpdate,
    db: Session = Depends(get_db),
):
    try:
        order = load_order(
            db,
            order_id,
        )

        if order is None:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Order not found",
            )

        validate_customer(
            db,
            payload.customer_id,
        )

        requested = aggregate_items(
            payload.items
        )

        old_product_ids = {
            item.product_id
            for item in order.items
        }

        new_product_ids = set(
            requested.keys()
        )

        products = lock_products(
            db,
            old_product_ids | new_product_ids,
        )

        validate_products_exist(
            products,
            requested,
        )

        for old_item in order.items:
            products[
                old_item.product_id
            ].stock += old_item.quantity

        validate_stock(
            products,
            requested,
        )

        for old_item in list(order.items):
            db.delete(old_item)

        db.flush()

        total = Decimal("0.00")

        for product_id, quantity in requested.items():
            product = products[product_id]

            unit_price = product.precio
            line_total = unit_price * quantity

            product.stock -= quantity
            total += line_total

            db.add(
                OrderItem(
                    order_id=order.id,
                    product_id=product_id,
                    quantity=quantity,
                    unit_price=unit_price,
                )
            )

        order.customer_id = payload.customer_id
        order.total = total

        db.commit()

        return load_order(
            db,
            order.id,
        )

    except HTTPException:
        db.rollback()
        raise

    except SQLAlchemyError as exc:
        db.rollback()

        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Database operation failed",
        ) from exc


@app.delete(
    "/orders/{order_id}",
    status_code=status.HTTP_204_NO_CONTENT,
)
def delete_order(
    order_id: int,
    db: Session = Depends(get_db),
):
    try:
        order = load_order(
            db,
            order_id,
        )

        if order is None:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Order not found",
            )

        product_ids = {
            item.product_id
            for item in order.items
        }

        products = lock_products(
            db,
            product_ids,
        )

        for item in order.items:
            products[
                item.product_id
            ].stock += item.quantity

        db.delete(order)
        db.commit()

        return Response(
            status_code=status.HTTP_204_NO_CONTENT,
        )

    except HTTPException:
        db.rollback()
        raise

    except SQLAlchemyError as exc:
        db.rollback()

        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Database operation failed",
        ) from exc
