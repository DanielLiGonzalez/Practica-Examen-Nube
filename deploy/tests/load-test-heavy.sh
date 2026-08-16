#!/usr/bin/env bash

set -Eeuo pipefail

BASE_URL="${BASE_URL:-https://localhost}"
OUT_DIR="${OUT_DIR:-evidence/fase5}"

mkdir -p "${OUT_DIR}"

TIMESTAMP="$(date -u +%Y%m%dT%H%M%SZ)"
OUTPUT="${OUT_DIR}/load-test-heavy-${TIMESTAMP}.txt"

echo "Cafe Boreal - Load Test HEAVY"
echo "Requests: 500"
echo "Concurrency: 20"
echo "Endpoint: ${BASE_URL}/api/catalog/products"
echo

ab \
  -n 500 \
  -c 20 \
  "${BASE_URL}/api/catalog/products" \
  | tee "${OUTPUT}"

echo
echo "Resultado guardado en:"
echo "${OUTPUT}"
