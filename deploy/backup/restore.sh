#!/usr/bin/env bash

set -Eeuo pipefail

NAMESPACE="${NAMESPACE:-cafe-boreal}"
POD="${POSTGRES_POD:-postgres-0}"
DB_NAME="${POSTGRES_DB:-cafe_boreal}"
DB_USER="${POSTGRES_USER:-cafe_boreal}"

if [[ $# -ne 1 ]]; then
    echo "Uso:"
    echo "  $0 archivo.dump"
    exit 1
fi

BACKUP_FILE="$1"

if [[ ! -f "${BACKUP_FILE}" ]]; then
    echo "ERROR: No existe el backup: ${BACKUP_FILE}" >&2
    exit 1
fi

if [[ ! -s "${BACKUP_FILE}" ]]; then
    echo "ERROR: El backup está vacío." >&2
    exit 1
fi

echo "=========================================="
echo " CAFE BOREAL - RESTORE POSTGRESQL"
echo "=========================================="
echo
echo "Namespace : ${NAMESPACE}"
echo "Pod       : ${POD}"
echo "Database  : ${DB_NAME}"
echo "Backup    : ${BACKUP_FILE}"
echo

echo "[1/4] Verificando PostgreSQL..."

kubectl exec \
    -n "${NAMESPACE}" \
    "${POD}" \
    -- pg_isready \
    -U "${DB_USER}" \
    -d "${DB_NAME}"

echo "[2/4] Validando formato del backup..."

kubectl exec \
    -i \
    -n "${NAMESPACE}" \
    "${POD}" \
    -- pg_restore --list \
    < "${BACKUP_FILE}" \
    >/dev/null

echo "[3/4] Restaurando base de datos..."

kubectl exec \
    -i \
    -n "${NAMESPACE}" \
    "${POD}" \
    -- pg_restore \
    -U "${DB_USER}" \
    -d "${DB_NAME}" \
    --clean \
    --if-exists \
    --no-owner \
    --no-privileges \
    --single-transaction \
    < "${BACKUP_FILE}"

echo "[4/4] Verificando restauración..."

kubectl exec \
    -n "${NAMESPACE}" \
    "${POD}" \
    -- psql \
    -U "${DB_USER}" \
    -d "${DB_NAME}" \
    -c "
SELECT 'products' AS tabla, COUNT(*) AS total FROM products
UNION ALL
SELECT 'customers', COUNT(*) FROM customers
UNION ALL
SELECT 'orders', COUNT(*) FROM orders
UNION ALL
SELECT 'order_items', COUNT(*) FROM order_items;
"

echo
echo "RESTORE COMPLETADO"
echo "=========================================="
