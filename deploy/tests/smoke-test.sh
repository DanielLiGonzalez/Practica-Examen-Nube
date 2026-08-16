#!/usr/bin/env bash

set -u

BASE_URL="${BASE_URL:-https://localhost}"

PASS=0
FAIL=0


check() {
    local name="$1"
    local command="$2"

    if eval "$command" >/dev/null 2>&1; then
        echo "PASS - ${name}"
        PASS=$((PASS + 1))
    else
        echo "FAIL - ${name}"
        FAIL=$((FAIL + 1))
    fi
}


check \
    "HTTPS Frontend" \
    "curl -ksSf '${BASE_URL}/'"

check \
    "Catalog healthz" \
    "curl -ksSf '${BASE_URL}/api/catalog/healthz' | jq -e '.status == \"ok\"'"

check \
    "Customers healthz" \
    "curl -ksSf '${BASE_URL}/api/customers/healthz' | jq -e '.status == \"ok\"'"

check \
    "Orders healthz" \
    "curl -ksSf '${BASE_URL}/api/orders/healthz' | jq -e '.status == \"ok\"'"

check \
    "Legacy inventory" \
    "curl -ksSf '${BASE_URL}/legacy/inventory' | jq -e '.count >= 1'"


echo
echo "PASS: ${PASS}"
echo "FAIL: ${FAIL}"

if [[ "${FAIL}" -gt 0 ]]; then
    exit 1
fi

exit 0
