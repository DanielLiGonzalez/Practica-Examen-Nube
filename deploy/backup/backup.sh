#!/usr/bin/env bash

set -Eeuo pipefail

NAMESPACE="${NAMESPACE:-cafe-boreal}"
POD="${POSTGRES_POD:-postgres-0}"
DB_NAME="${POSTGRES_DB:-cafe_boreal}"
DB_USER="${POSTGRES_USER:-cafe_boreal}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DIR="${BACKUP_DIR:-${SCRIPT_DIR}/generated}"

TIMESTAMP="$(date -u +%Y%m%dT%H%M%SZ)"
BACKUP_FILE="${BACKUP_DIR}/cafe-boreal-${TIMESTAMP}.dump"
CHECKSUM_FILE="${BACKUP_FILE}.sha256"

echo "=========================================="
echo " CAFE BOREAL - BACKUP POSTGRESQL"
echo "=========================================="
echo
echo "Namespace : ${NAMESPACE}"
echo "Pod       : ${POD}"
echo "Database  : ${DB_NAME}"
echo "Destino   : ${BACKUP_FILE}"
echo

mkdir -p "${BACKUP_DIR}"

echo "[1/5] Verificando pod PostgreSQL..."

kubectl get pod "${POD}" \
    -n "${NAMESPACE}" \
    >/dev/null

echo "[2/5] Verificando disponibilidad..."

kubectl exec \
    -n "${NAMESPACE}" \
    "${POD}" \
    -- pg_isready \
    -U "${DB_USER}" \
    -d "${DB_NAME}"

echo "[3/5] Generando backup..."

kubectl exec \
    -n "${NAMESPACE}" \
    "${POD}" \
    -- pg_dump \
    -U "${DB_USER}" \
    -d "${DB_NAME}" \
    -Fc \
    > "${BACKUP_FILE}"

if [[ ! -s "${BACKUP_FILE}" ]]; then
    echo "ERROR: El archivo de backup está vacío." >&2
    rm -f "${BACKUP_FILE}"
    exit 1
fi

echo "[4/5] Validando archivo..."

kubectl exec \
    -i \
    -n "${NAMESPACE}" \
    "${POD}" \
    -- pg_restore --list \
    < "${BACKUP_FILE}" \
    >/dev/null

echo "[5/5] Generando SHA256..."

sha256sum "${BACKUP_FILE}" > "${CHECKSUM_FILE}"

echo
echo "BACKUP COMPLETADO"
echo
echo "Archivo:"
echo "${BACKUP_FILE}"
echo
echo "Tamaño:"
du -h "${BACKUP_FILE}"
echo
echo "SHA256:"
cat "${CHECKSUM_FILE}"
echo
echo "=========================================="
