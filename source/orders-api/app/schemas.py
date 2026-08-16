from datetime import datetime
from decimal import Decimal

from pydantic import BaseModel, ConfigDict, Field


class OrderItemInput(BaseModel):
    product_id: int = Field(gt=0)
    quantity: int = Field(gt=0)


class OrderCreate(BaseModel):
    customer_id: int = Field(gt=0)

    items: list[OrderItemInput] = Field(
        min_length=1,
    )


class OrderUpdate(BaseModel):
    customer_id: int = Field(gt=0)

    items: list[OrderItemInput] = Field(
        min_length=1,
    )


class OrderItemResponse(BaseModel):
    model_config = ConfigDict(
        from_attributes=True,
    )

    id: int
    product_id: int
    quantity: int
    unit_price: Decimal
    subtotal: Decimal


class OrderResponse(BaseModel):
    model_config = ConfigDict(
        from_attributes=True,
    )

    id: int
    customer_id: int
    created_at: datetime
    total: Decimal
    items: list[OrderItemResponse]
