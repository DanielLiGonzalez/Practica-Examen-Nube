#!/usr/bin/env python3

import subprocess
import sys

from crypto_identity import decrypt_identity, encrypt_identity


NAMESPACE = "cafe-boreal"
POD = "postgres-0"
DATABASE = "cafe_boreal"
USER = "cafe_boreal"


def sql_literal(value: str) -> str:
    return "'" + value.replace("'", "''") + "'"


def run_psql_query(sql: str) -> str:
    command = [
        "kubectl",
        "exec",
        "-n",
        NAMESPACE,
        POD,
        "--",
        "psql",
        "-U",
        USER,
        "-d",
        DATABASE,
        "-At",
        "-F",
        "\t",
        "-v",
        "ON_ERROR_STOP=1",
        "-c",
        sql,
    ]

    result = subprocess.run(
        command,
        capture_output=True,
        text=True,
        check=False,
    )

    if result.returncode != 0:
        raise RuntimeError(result.stderr.strip())

    return result.stdout.strip()


def run_psql_script(sql: str) -> None:
    command = [
        "kubectl",
        "exec",
        "-i",
        "-n",
        NAMESPACE,
        POD,
        "--",
        "psql",
        "-U",
        USER,
        "-d",
        DATABASE,
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


def read_v1_customers():
    output = run_psql_query(
        """
        SELECT id, numero_identidad
        FROM customers
        WHERE numero_identidad LIKE 'v1:%'
        ORDER BY id;
        """
    )

    if not output:
        return []

    customers = []

    for line in output.splitlines():
        customer_id, encrypted_identity = line.split("\t", 1)

        customers.append(
            (
                int(customer_id),
                encrypted_identity,
            )
        )

    return customers


def build_rotation_sql(customers) -> str:
    statements = ["BEGIN;"]

    for customer_id, old_ciphertext in customers:
        plaintext = decrypt_identity(old_ciphertext)

        new_ciphertext = encrypt_identity(
            plaintext,
            version="v2",
        )

        statements.append(
            f"""
UPDATE customers
SET numero_identidad = {sql_literal(new_ciphertext)}
WHERE id = {customer_id}
  AND numero_identidad = {sql_literal(old_ciphertext)};
""".strip()
        )

    statements.append(
        """
DO $$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM customers
        WHERE numero_identidad LIKE 'v1:%'
    ) THEN
        RAISE EXCEPTION 'Todavía existen identidades cifradas con KEY_V1';
    END IF;
END
$$;
""".strip()
    )

    statements.append("COMMIT;")

    return "\n\n".join(statements)


def main() -> int:
    try:
        customers = read_v1_customers()

        print(f"Registros encontrados con KEY_V1: {len(customers)}")

        if not customers:
            print("No existen registros pendientes de rotación.")
            return 0

        rotation_sql = build_rotation_sql(customers)

        run_psql_script(rotation_sql)

        remaining_v1 = run_psql_query(
            """
            SELECT COUNT(*)
            FROM customers
            WHERE numero_identidad LIKE 'v1:%';
            """
        )

        total_v2 = run_psql_query(
            """
            SELECT COUNT(*)
            FROM customers
            WHERE numero_identidad LIKE 'v2:%';
            """
        )

        print(f"Registros restantes con KEY_V1: {remaining_v1}")
        print(f"Registros cifrados con KEY_V2: {total_v2}")

        if remaining_v1 != "0":
            raise RuntimeError(
                "La rotación no terminó correctamente."
            )

        print("Rotación KEY_V1 -> KEY_V2 completada correctamente.")
        return 0

    except Exception as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
