#!/usr/bin/env bash

set -Eeuo pipefail

BASE_URL="${BASE_URL:-https://localhost}"
OUT_DIR="${OUT_DIR:-evidence/fase5}"

mkdir -p "${OUT_DIR}"

TIMESTAMP="$(date -u +%Y%m%dT%H%M%SZ)"
OUTPUT="${OUT_DIR}/load-test-light-${TIMESTAMP}.txt"

echo "Cafe Boreal - Load Test LIGHT"
echo "Requests: 100"
echo "Concurrency: 5"
echo "Endpoint: ${BASE_URL}/api/catalog/products"
echo

ab \
  -n 100 \
  -c 5 \
  "${BASE_URL}/api/catalog/products" \
  | tee "${OUTPUT}"

echo
echo "Resultado guardado en:"
echo "${OUTPUT}"
