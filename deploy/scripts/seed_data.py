#!/usr/bin/env python3

import subprocess
import sys

from crypto_identity import encrypt_identity


PRODUCTS = [
    ("Café Americano", "1800.00", 100, "Café espresso diluido con agua caliente.", "/images/productos/americano.jpg"),
    ("Café Espresso", "1500.00", 100, "Shot concentrado de café.", "/images/productos/espresso.jpg"),
    ("Café Doble Espresso", "2200.00", 80, "Doble shot de espresso.", "/images/productos/doble-espresso.jpg"),
    ("Café Cappuccino", "2500.00", 90, "Espresso con leche vaporizada y espuma.", "/images/productos/cappuccino.jpg"),
    ("Café Latte", "2600.00", 90, "Espresso con abundante leche vaporizada.", "/images/productos/latte.jpg"),
    ("Café Mocha", "2900.00", 75, "Café con leche y chocolate.", "/images/productos/mocha.jpg"),
    ("Café Macchiato", "2100.00", 70, "Espresso con una pequeña cantidad de leche.", "/images/productos/macchiato.jpg"),
    ("Flat White", "2700.00", 65, "Espresso con leche microespumada.", "/images/productos/flat-white.jpg"),
    ("Café Cortado", "2000.00", 65, "Espresso cortado con leche caliente.", "/images/productos/cortado.jpg"),
    ("Café Vainilla", "2800.00", 70, "Latte aromatizado con vainilla.", "/images/productos/vainilla.jpg"),
    ("Café Caramelo", "2900.00", 70, "Latte con jarabe de caramelo.", "/images/productos/caramelo.jpg"),
    ("Café Avellana", "2900.00", 65, "Latte aromatizado con avellana.", "/images/productos/avellana.jpg"),
    ("Café Canela", "2600.00", 60, "Café con leche y toque de canela.", "/images/productos/canela.jpg"),
    ("Café Miel", "2750.00", 55, "Café endulzado con miel.", "/images/productos/miel.jpg"),
    ("Café Frío", "2700.00", 80, "Café servido frío con hielo.", "/images/productos/cafe-frio.jpg"),
    ("Cold Brew", "3000.00", 60, "Café extraído en frío durante varias horas.", "/images/productos/cold-brew.jpg"),
    ("Cold Brew Vainilla", "3200.00", 50, "Cold brew con vainilla.", "/images/productos/cold-brew-vainilla.jpg"),
    ("Frappé de Café", "3300.00", 65, "Bebida fría licuada a base de café.", "/images/productos/frappe-cafe.jpg"),
    ("Frappé de Mocha", "3500.00", 60, "Frappé de café y chocolate.", "/images/productos/frappe-mocha.jpg"),
    ("Frappé de Caramelo", "3500.00", 60, "Frappé de café con caramelo.", "/images/productos/frappe-caramelo.jpg"),
    ("Chocolate Caliente", "2700.00", 70, "Chocolate caliente con leche.", "/images/productos/chocolate-caliente.jpg"),
    ("Chocolate Frío", "2800.00", 65, "Bebida fría de chocolate.", "/images/productos/chocolate-frio.jpg"),
    ("Té Negro", "1800.00", 80, "Infusión clásica de té negro.", "/images/productos/te-negro.jpg"),
    ("Té Verde", "1900.00", 80, "Infusión de té verde.", "/images/productos/te-verde.jpg"),
    ("Té de Manzanilla", "1900.00", 75, "Infusión de manzanilla.", "/images/productos/manzanilla.jpg"),
    ("Té de Frutas", "2100.00", 70, "Infusión aromática de frutas.", "/images/productos/te-frutas.jpg"),
    ("Chai Latte", "2800.00", 60, "Té chai especiado con leche.", "/images/productos/chai-latte.jpg"),
    ("Matcha Latte", "3200.00", 50, "Té matcha con leche vaporizada.", "/images/productos/matcha-latte.jpg"),
    ("Limonada Natural", "2200.00", 80, "Limonada preparada al momento.", "/images/productos/limonada.jpg"),
    ("Limonada con Hierbabuena", "2500.00", 70, "Limonada natural con hierbabuena.", "/images/productos/limonada-hierbabuena.jpg"),
    ("Jugo de Naranja", "2400.00", 70, "Jugo natural de naranja.", "/images/productos/naranja.jpg"),
    ("Batido de Fresa", "2900.00", 60, "Batido natural de fresa.", "/images/productos/batido-fresa.jpg"),
    ("Batido de Mango", "2900.00", 60, "Batido natural de mango.", "/images/productos/batido-mango.jpg"),
    ("Batido de Mora", "2900.00", 60, "Batido natural de mora.", "/images/productos/batido-mora.jpg"),
    ("Croissant de Mantequilla", "1800.00", 40, "Croissant clásico de mantequilla.", "/images/productos/croissant.jpg"),
    ("Croissant de Jamón y Queso", "2800.00", 35, "Croissant relleno de jamón y queso.", "/images/productos/croissant-jamon.jpg"),
    ("Empanada de Pollo", "2200.00", 40, "Empanada horneada rellena de pollo.", "/images/productos/empanada-pollo.jpg"),
    ("Empanada de Carne", "2300.00", 40, "Empanada horneada rellena de carne.", "/images/productos/empanada-carne.jpg"),
    ("Queque de Chocolate", "2500.00", 30, "Porción de queque de chocolate.", "/images/productos/queque-chocolate.jpg"),
    ("Queque de Zanahoria", "2600.00", 30, "Porción de queque de zanahoria.", "/images/productos/queque-zanahoria.jpg"),
    ("Cheesecake", "3000.00", 25, "Porción de cheesecake tradicional.", "/images/productos/cheesecake.jpg"),
    ("Brownie", "2200.00", 35, "Brownie de chocolate.", "/images/productos/brownie.jpg"),
    ("Galleta de Chocolate", "1500.00", 50, "Galleta con chispas de chocolate.", "/images/productos/galleta-chocolate.jpg"),
    ("Galleta de Avena", "1500.00", 50, "Galleta artesanal de avena.", "/images/productos/galleta-avena.jpg"),
    ("Sándwich de Pollo", "3500.00", 30, "Sándwich preparado con pollo.", "/images/productos/sandwich-pollo.jpg"),
    ("Sándwich de Jamón y Queso", "3200.00", 30, "Sándwich de jamón y queso.", "/images/productos/sandwich-jamon.jpg"),
    ("Wrap Vegetariano", "3600.00", 25, "Wrap relleno de vegetales frescos.", "/images/productos/wrap-vegetariano.jpg"),
    ("Panini de Pollo", "3900.00", 25, "Panini caliente de pollo.", "/images/productos/panini-pollo.jpg"),
    ("Desayuno Boreal", "5500.00", 20, "Desayuno completo de la casa.", "/images/productos/desayuno-boreal.jpg"),
    ("Café Boreal Especial", "3400.00", 50, "Bebida especial de café de la casa.", "/images/productos/boreal-especial.jpg"),
]


CUSTOMERS = [
    ("Ana Rodríguez", "ana.rodriguez@example.com", "101010101"),
    ("Carlos Vargas", "carlos.vargas@example.com", "202020202"),
    ("María González", "maria.gonzalez@example.com", "303030303"),
    ("José Hernández", "jose.hernandez@example.com", "404040404"),
    ("Laura Jiménez", "laura.jimenez@example.com", "505050505"),
    ("Andrés Solano", "andres.solano@example.com", "606060606"),
    ("Sofía Ramírez", "sofia.ramirez@example.com", "707070707"),
    ("Daniel Mora", "daniel.mora@example.com", "808080808"),
    ("Valeria Chaves", "valeria.chaves@example.com", "909090909"),
    ("Gabriel Rojas", "gabriel.rojas@example.com", "111222333"),
]


def sql_literal(value: str) -> str:
    return "'" + value.replace("'", "''") + "'"


def build_products_sql() -> str:
    rows = []

    for nombre, precio, stock, descripcion, imagen in PRODUCTS:
        rows.append(
            "("
            + ", ".join(
                [
                    sql_literal(nombre),
                    precio,
                    str(stock),
                    sql_literal(descripcion),
                    sql_literal(imagen),
                ]
            )
            + ")"
        )

    values = ",\n".join(rows)

    return f"""
INSERT INTO products (nombre, precio, stock, descripcion, imagen)
SELECT
    seed.nombre,
    seed.precio,
    seed.stock,
    seed.descripcion,
    seed.imagen
FROM (
    VALUES
{values}
) AS seed(nombre, precio, stock, descripcion, imagen)
WHERE NOT EXISTS (
    SELECT 1
    FROM products p
    WHERE p.nombre = seed.nombre
);
"""


def build_customers_sql() -> str:
    rows = []

    for nombre, email, numero_identidad in CUSTOMERS:
        encrypted_identity = encrypt_identity(
            numero_identidad,
            version="v1",
        )

        rows.append(
            "("
            + ", ".join(
                [
                    sql_literal(nombre),
                    sql_literal(email),
                    sql_literal(encrypted_identity),
                ]
            )
            + ")"
        )

    values = ",\n".join(rows)

    return f"""
INSERT INTO customers (nombre, email, numero_identidad)
SELECT
    seed.nombre,
    seed.email,
    seed.numero_identidad
FROM (
    VALUES
{values}
) AS seed(nombre, email, numero_identidad)
WHERE NOT EXISTS (
    SELECT 1
    FROM customers c
    WHERE c.email = seed.email
);
"""


def run_psql(sql: str) -> None:
    command = [
        "kubectl",
        "exec",
        "-i",
        "-n",
        "cafe-boreal",
        "postgres-0",
        "--",
        "psql",
        "-U",
        "cafe_boreal",
        "-d",
        "cafe_boreal",
        "-v",
        "ON_ERROR_STOP=1",
    ]

    result = subprocess.run(
        command,
        input=sql,
        text=True,
        check=False,
    )

    if result.returncode != 0:
        raise RuntimeError(
            f"psql terminó con código {result.returncode}"
        )


def main() -> int:
    try:
        products_sql = build_products_sql()
        customers_sql = build_customers_sql()

        sql = f"""
BEGIN;

{products_sql}

{customers_sql}

COMMIT;

SELECT 'products' AS tabla, COUNT(*) AS total
FROM products
UNION ALL
SELECT 'customers' AS tabla, COUNT(*) AS total
FROM customers;
"""

        run_psql(sql)

        print("Seeds aplicados correctamente.")
        return 0

    except Exception as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
