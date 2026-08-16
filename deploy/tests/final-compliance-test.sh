#!/usr/bin/env bash

set -u

BASE_URL="${BASE_URL:-https://localhost}"
NAMESPACE="cafe-boreal"

PASS=0
FAIL=0
WARN=0

CATALOG_TEST_ID=""
CUSTOMER_TEST_ID=""
ORDER_TEST_ID=""

PROM_PF=""
GRAFANA_PF=""
LOKI_PF=""


pass() {
    echo "PASS  $1"
    PASS=$((PASS + 1))
}


fail() {
    echo "FAIL  $1"
    FAIL=$((FAIL + 1))
}


warn() {
    echo "WARN  $1"
    WARN=$((WARN + 1))
}


cleanup() {
    if [[ -n "${ORDER_TEST_ID}" ]]; then
        curl -ksS \
            -X DELETE \
            "${BASE_URL}/api/orders/orders/${ORDER_TEST_ID}" \
            >/dev/null 2>&1 || true
    fi

    if [[ -n "${CUSTOMER_TEST_ID}" ]]; then
        curl -ksS \
            -X DELETE \
            "${BASE_URL}/api/customers/customers/${CUSTOMER_TEST_ID}" \
            >/dev/null 2>&1 || true
    fi

    if [[ -n "${CATALOG_TEST_ID}" ]]; then
        curl -ksS \
            -X DELETE \
            "${BASE_URL}/api/catalog/products/${CATALOG_TEST_ID}" \
            >/dev/null 2>&1 || true
    fi

    [[ -n "${PROM_PF}" ]] && kill "${PROM_PF}" 2>/dev/null || true
    [[ -n "${GRAFANA_PF}" ]] && kill "${GRAFANA_PF}" 2>/dev/null || true
    [[ -n "${LOKI_PF}" ]] && kill "${LOKI_PF}" 2>/dev/null || true
}


trap cleanup EXIT


echo "=================================================="
echo " CAFE BOREAL - TEST FINAL DE CUMPLIMIENTO"
echo "=================================================="
echo


echo "=== 1. INFRAESTRUCTURA ==="

if minikube status 2>/dev/null | grep -q "Running"; then
    pass "Minikube está ejecutándose"
else
    fail "Minikube no está ejecutándose"
fi


if kubectl get node minikube 2>/dev/null \
    -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' \
    | grep -q "True"; then
    pass "Nodo Kubernetes está Ready"
else
    fail "Nodo Kubernetes no está Ready"
fi


if kubectl get namespace "${NAMESPACE}" >/dev/null 2>&1; then
    pass "Namespace cafe-boreal existe"
else
    fail "Namespace cafe-boreal no existe"
fi


CRASH_COUNT="$(
    kubectl get pods -n "${NAMESPACE}" \
        --no-headers 2>/dev/null \
        | grep -c 'CrashLoopBackOff' || true
)"

if [[ "${CRASH_COUNT}" -eq 0 ]]; then
    pass "No existen pods en CrashLoopBackOff"
else
    fail "Existen pods en CrashLoopBackOff"
fi


NOT_READY="$(
    kubectl get pods -n "${NAMESPACE}" \
        --no-headers 2>/dev/null \
        | awk '$3 != "Running" && $3 != "Completed" {count++} END {print count+0}'
)"

if [[ "${NOT_READY}" -eq 0 ]]; then
    pass "Todos los pods están Running/Completed"
else
    fail "Existen pods en estado incorrecto"
fi


echo
echo "=== 2. POSTGRESQL Y DATOS ==="

if kubectl exec -n "${NAMESPACE}" postgres-0 -- \
    pg_isready \
    -U cafe_boreal \
    -d cafe_boreal \
    >/dev/null 2>&1; then

    pass "PostgreSQL acepta conexiones"
else
    fail "PostgreSQL no acepta conexiones"
fi


PRODUCTS="$(
    kubectl exec -n "${NAMESPACE}" postgres-0 -- \
    psql -U cafe_boreal -d cafe_boreal \
    -Atc "SELECT COUNT(*) FROM products;" \
    2>/dev/null
)"

if [[ "${PRODUCTS}" -ge 50 ]]; then
    pass "Existen al menos 50 productos (${PRODUCTS})"
else
    fail "No existen 50 productos (${PRODUCTS})"
fi


CUSTOMERS="$(
    kubectl exec -n "${NAMESPACE}" postgres-0 -- \
    psql -U cafe_boreal -d cafe_boreal \
    -Atc "SELECT COUNT(*) FROM customers;" \
    2>/dev/null
)"

if [[ "${CUSTOMERS}" -ge 10 ]]; then
    pass "Existen al menos 10 clientes (${CUSTOMERS})"
else
    fail "No existen 10 clientes (${CUSTOMERS})"
fi


PLAIN_IDENTITIES="$(
    kubectl exec -n "${NAMESPACE}" postgres-0 -- \
    psql -U cafe_boreal -d cafe_boreal \
    -Atc \
    "SELECT COUNT(*) FROM customers WHERE numero_identidad ~ '^[0-9]+$';" \
    2>/dev/null
)"

if [[ "${PLAIN_IDENTITIES}" -eq 0 ]]; then
    pass "No hay identidades almacenadas en texto claro"
else
    fail "Hay identidades almacenadas en texto claro"
fi


V2_IDENTITIES="$(
    kubectl exec -n "${NAMESPACE}" postgres-0 -- \
    psql -U cafe_boreal -d cafe_boreal \
    -Atc \
    "SELECT COUNT(*) FROM customers WHERE numero_identidad LIKE 'v2:%';" \
    2>/dev/null
)"

if [[ "${V2_IDENTITIES}" -ge 10 ]]; then
    pass "Las identidades utilizan KEY_V2 (${V2_IDENTITIES})"
else
    fail "No todas las identidades utilizan KEY_V2"
fi


echo
echo "=== 3. SEGURIDAD Y HTTPS ==="

HTTP_CODE="$(
    curl -sS \
        -o /dev/null \
        -w '%{http_code}' \
        http://localhost/ \
        2>/dev/null
)"

if [[ "${HTTP_CODE}" == "301" || "${HTTP_CODE}" == "302" ]]; then
    pass "HTTP redirige a HTTPS"
else
    fail "HTTP no redirige a HTTPS (HTTP ${HTTP_CODE})"
fi


HTTPS_CODE="$(
    curl -ksS \
        -o /dev/null \
        -w '%{http_code}' \
        "${BASE_URL}/" \
        2>/dev/null
)"

if [[ "${HTTPS_CODE}" == "200" ]]; then
    pass "Frontend responde mediante HTTPS"
else
    fail "Frontend HTTPS falló (HTTP ${HTTPS_CODE})"
fi


KEYS="$(
    kubectl get secret customer-crypto-secret \
        -n "${NAMESPACE}" \
        -o jsonpath='{.data}' \
        2>/dev/null \
        | jq -r 'keys | join(",")'
)"

if [[ "${KEYS}" == "KEY_V2" ]]; then
    pass "Solo KEY_V2 está activa en Kubernetes"
else
    fail "Secret de cifrado contiene claves inesperadas: ${KEYS}"
fi


SECRET_LEAK="$(
    grep -RIlE \
        --exclude-dir=.git \
        --exclude-dir=generated \
        --exclude='*.dump' \
        --exclude='*.sqlite' \
        '(KEY_V1=[0-9a-fA-F]{64}|KEY_V2=[0-9a-fA-F]{64})' \
        source deploy docs \
        2>/dev/null \
        | head -n 1
)"

if [[ -z "${SECRET_LEAK}" ]]; then
    pass "No se detectaron claves AES reales en el repositorio"
else
    fail "Posible secreto encontrado en ${SECRET_LEAK}"
fi


for SERVICE in catalog-api customers-api orders-api; do
    UID_VALUE="$(
        kubectl exec \
            -n "${NAMESPACE}" \
            deployment/"${SERVICE}" \
            -- id -u \
            2>/dev/null
    )"

    if [[ -n "${UID_VALUE}" && "${UID_VALUE}" != "0" ]]; then
        pass "${SERVICE} corre como usuario non-root (${UID_VALUE})"
    else
        fail "${SERVICE} está ejecutándose como root"
    fi
done


echo
echo "=== 4. HEALTH CHECKS ==="

for SERVICE in catalog customers orders; do
    STATUS="$(
        curl -ksS \
            "${BASE_URL}/api/${SERVICE}/healthz" \
            2>/dev/null \
            | jq -r '.status // empty'
    )"

    if [[ "${STATUS}" == "ok" ]]; then
        pass "${SERVICE}-api /healthz responde OK"
    else
        fail "${SERVICE}-api /healthz falló"
    fi
done


echo
echo "=== 5. CRUD CATALOG API ==="

CATALOG_RESPONSE="$(
    curl -ksS \
        -X POST \
        "${BASE_URL}/api/catalog/products" \
        -H 'Content-Type: application/json' \
        -d '{
            "nombre":"TEST-CUMPLIMIENTO",
            "precio":1000,
            "stock":10,
            "descripcion":"Producto temporal",
            "imagen":null
        }'
)"

CATALOG_TEST_ID="$(
    echo "${CATALOG_RESPONSE}" | jq -r '.id // empty'
)"

if [[ -n "${CATALOG_TEST_ID}" ]]; then
    pass "Catalog POST crea producto"
else
    fail "Catalog POST falló"
fi


if [[ -n "${CATALOG_TEST_ID}" ]]; then
    UPDATED_STOCK="$(
        curl -ksS \
            -X PUT \
            "${BASE_URL}/api/catalog/products/${CATALOG_TEST_ID}" \
            -H 'Content-Type: application/json' \
            -d '{"stock":15}' \
            | jq -r '.stock // empty'
    )"

    if [[ "${UPDATED_STOCK}" == "15" ]]; then
        pass "Catalog PUT actualiza producto"
    else
        fail "Catalog PUT falló"
    fi
fi


echo
echo "=== 6. CRUD CUSTOMERS + CIFRADO ==="

TEST_EMAIL="cumplimiento.$(date +%s)@example.com"

CUSTOMER_RESPONSE="$(
    curl -ksS \
        -X POST \
        "${BASE_URL}/api/customers/customers" \
        -H 'Content-Type: application/json' \
        -d "{
            \"nombre\":\"Cliente Cumplimiento\",
            \"email\":\"${TEST_EMAIL}\",
            \"numero_identidad\":\"998877665\"
        }"
)"

CUSTOMER_TEST_ID="$(
    echo "${CUSTOMER_RESPONSE}" | jq -r '.id // empty'
)"

RETURNED_IDENTITY="$(
    echo "${CUSTOMER_RESPONSE}" \
        | jq -r '.numero_identidad // empty'
)"

if [[ -n "${CUSTOMER_TEST_ID}" &&
      "${RETURNED_IDENTITY}" == "998877665" ]]; then
    pass "Customers POST devuelve identidad descifrada"
else
    fail "Customers POST falló"
fi


if [[ -n "${CUSTOMER_TEST_ID}" ]]; then
    DB_IDENTITY="$(
        kubectl exec \
            -n "${NAMESPACE}" \
            postgres-0 \
            -- psql \
            -U cafe_boreal \
            -d cafe_boreal \
            -Atc \
            "SELECT numero_identidad FROM customers WHERE id=${CUSTOMER_TEST_ID};" \
            2>/dev/null
    )"

    if [[ "${DB_IDENTITY}" == v2:* &&
          "${DB_IDENTITY}" != "998877665" ]]; then
        pass "Customers almacena identidad cifrada v2 en PostgreSQL"
    else
        fail "Customers almacenó identidad incorrectamente"
    fi
fi


echo
echo "=== 7. ORDERS + TOTAL + STOCK ==="

if [[ -n "${CATALOG_TEST_ID}" &&
      -n "${CUSTOMER_TEST_ID}" ]]; then

    ORDER_RESPONSE="$(
        curl -ksS \
            -X POST \
            "${BASE_URL}/api/orders/orders" \
            -H 'Content-Type: application/json' \
            -d "{
                \"customer_id\":${CUSTOMER_TEST_ID},
                \"items\":[
                    {
                        \"product_id\":${CATALOG_TEST_ID},
                        \"quantity\":2
                    }
                ]
            }"
    )"

    ORDER_TEST_ID="$(
        echo "${ORDER_RESPONSE}" | jq -r '.id // empty'
    )"

    ORDER_TOTAL="$(
        echo "${ORDER_RESPONSE}" | jq -r '.total // empty'
    )"

    if [[ -n "${ORDER_TEST_ID}" &&
          "${ORDER_TOTAL}" == "2000.00" ]]; then
        pass "Orders calcula correctamente total 2 x 1000 = 2000"
    else
        fail "Orders POST/total falló: ${ORDER_TOTAL}"
    fi


    STOCK_AFTER="$(
        curl -ksS \
            "${BASE_URL}/api/catalog/products/${CATALOG_TEST_ID}" \
            | jq -r '.stock // empty'
    )"

    if [[ "${STOCK_AFTER}" == "13" ]]; then
        pass "Orders descuenta stock correctamente"
    else
        fail "Orders no descontó correctamente stock (${STOCK_AFTER})"
    fi


    DELETE_CODE="$(
        curl -ksS \
            -o /dev/null \
            -w '%{http_code}' \
            -X DELETE \
            "${BASE_URL}/api/orders/orders/${ORDER_TEST_ID}"
    )"

    if [[ "${DELETE_CODE}" == "204" ]]; then
        pass "Orders DELETE funciona"
        ORDER_TEST_ID=""
    else
        fail "Orders DELETE falló"
    fi


    STOCK_RESTORED="$(
        curl -ksS \
            "${BASE_URL}/api/catalog/products/${CATALOG_TEST_ID}" \
            | jq -r '.stock // empty'
    )"

    if [[ "${STOCK_RESTORED}" == "15" ]]; then
        pass "Eliminar orden restaura el stock"
    else
        fail "Stock no fue restaurado (${STOCK_RESTORED})"
    fi
fi


echo
echo "=== 8. LIMPIEZA CRUD ==="

if [[ -n "${CUSTOMER_TEST_ID}" ]]; then
    CODE="$(
        curl -ksS \
            -o /dev/null \
            -w '%{http_code}' \
            -X DELETE \
            "${BASE_URL}/api/customers/customers/${CUSTOMER_TEST_ID}"
    )"

    if [[ "${CODE}" == "204" ]]; then
        pass "Cliente temporal eliminado"
        CUSTOMER_TEST_ID=""
    else
        fail "No se pudo eliminar cliente temporal"
    fi
fi


if [[ -n "${CATALOG_TEST_ID}" ]]; then
    CODE="$(
        curl -ksS \
            -o /dev/null \
            -w '%{http_code}' \
            -X DELETE \
            "${BASE_URL}/api/catalog/products/${CATALOG_TEST_ID}"
    )"

    if [[ "${CODE}" == "204" ]]; then
        pass "Producto temporal eliminado"
        CATALOG_TEST_ID=""
    else
        fail "No se pudo eliminar producto temporal"
    fi
fi


echo
echo "=== 9. LEGACY ==="

LEGACY_COUNT="$(
    curl -ksS \
        "${BASE_URL}/legacy/inventory" \
        | jq -r '.count // 0'
)"

if [[ "${LEGACY_COUNT}" -ge 5 ]]; then
    pass "Legacy inventory responde (${LEGACY_COUNT} registros)"
else
    fail "Legacy inventory falló"
fi


LEGACY_SKU="$(
    curl -ksS \
        "${BASE_URL}/legacy/inventory?sku=LEG-001" \
        | jq -r '.items[0].sku // empty'
)"

if [[ "${LEGACY_SKU}" == "LEG-001" ]]; then
    pass "Legacy soporta filtro ?sku=LEG-001"
else
    fail "Filtro SKU Legacy falló"
fi


echo
echo "=== 10. INGRESS ==="

if kubectl get ingress cafe-boreal-ingress \
    -n "${NAMESPACE}" >/dev/null 2>&1; then
    pass "Ingress cafe-boreal-ingress existe"
else
    fail "Ingress no existe"
fi


echo
echo "=== 11. OBSERVABILIDAD ==="

for COMPONENT in prometheus grafana loki; do
    READY="$(
        kubectl get deployment "${COMPONENT}" \
            -n "${NAMESPACE}" \
            -o jsonpath='{.status.readyReplicas}' \
            2>/dev/null
    )"

    if [[ "${READY}" == "1" ]]; then
        pass "${COMPONENT} está Ready"
    else
        fail "${COMPONENT} no está Ready"
    fi
done


for COMPONENT in promtail cadvisor; do
    DESIRED="$(
        kubectl get daemonset "${COMPONENT}" \
            -n "${NAMESPACE}" \
            -o jsonpath='{.status.desiredNumberScheduled}' \
            2>/dev/null
    )"

    READY="$(
        kubectl get daemonset "${COMPONENT}" \
            -n "${NAMESPACE}" \
            -o jsonpath='{.status.numberReady}' \
            2>/dev/null
    )"

    if [[ -n "${DESIRED}" &&
          "${DESIRED}" == "${READY}" ]]; then
        pass "${COMPONENT} DaemonSet está Ready"
    else
        fail "${COMPONENT} DaemonSet no está Ready"
    fi
done


kubectl port-forward \
    -n "${NAMESPACE}" \
    service/prometheus \
    29090:9090 \
    >/tmp/final-prometheus.log 2>&1 &
PROM_PF=$!

kubectl port-forward \
    -n "${NAMESPACE}" \
    service/grafana \
    25555:3000 \
    >/tmp/final-grafana.log 2>&1 &
GRAFANA_PF=$!

kubectl port-forward \
    -n "${NAMESPACE}" \
    service/loki \
    23100:3100 \
    >/tmp/final-loki.log 2>&1 &
LOKI_PF=$!

sleep 4


DOWN_TARGETS="$(
    curl -sS \
        http://127.0.0.1:29090/api/v1/targets \
        2>/dev/null \
        | jq \
        '[.data.activeTargets[] | select(.health != "up")] | length' \
        2>/dev/null
)"

if [[ "${DOWN_TARGETS}" == "0" ]]; then
    pass "Todos los targets de Prometheus están up"
else
    fail "Hay targets de Prometheus down"
fi


GRAFANA_STATUS="$(
    curl -sS \
        http://127.0.0.1:25555/api/health \
        2>/dev/null \
        | jq -r '.database // empty'
)"

if [[ "${GRAFANA_STATUS}" == "ok" ]]; then
    pass "Grafana responde correctamente"
else
    fail "Grafana no responde correctamente"
fi


LOKI_READY="$(
    curl -sS \
        http://127.0.0.1:23100/ready \
        2>/dev/null
)"

if echo "${LOKI_READY}" | grep -qi 'ready'; then
    pass "Loki está Ready"
else
    fail "Loki no está Ready"
fi


echo
echo "=== 12. BACKUP / SCRIPTS ==="

if [[ -x deploy/backup/backup.sh ]]; then
    pass "backup.sh existe y es ejecutable"
else
    fail "backup.sh falta"
fi


if [[ -x deploy/backup/restore.sh ]]; then
    pass "restore.sh existe y es ejecutable"
else
    fail "restore.sh falta"
fi


if [[ -x deploy/scripts/start-all.sh ]]; then
    pass "start-all.sh existe y es ejecutable"
else
    fail "start-all.sh falta"
fi


if [[ -x deploy/scripts/status.sh ]]; then
    pass "status.sh existe y es ejecutable"
else
    fail "status.sh falta"
fi


if [[ -x deploy/tests/smoke-test.sh ]]; then
    if deploy/tests/smoke-test.sh >/tmp/final-smoke.txt 2>&1; then
        pass "Smoke test completo pasa"
    else
        fail "Smoke test tiene errores"
    fi
else
    fail "smoke-test.sh no existe"
fi


echo
echo "=== 13. ELEMENTOS DEL PROYECTO ==="

if grep -q 'CAFE-BOREAL-ITI522-X7K9-2026' \
    source/frontend/index.html 2>/dev/null; then
    pass "Frontend contiene frase anti-fraude"
else
    fail "Frontend no contiene frase anti-fraude"
fi


for API in catalog customers orders; do
    if [[ -f "source/${API}-api/Dockerfile" &&
          -f "source/${API}-api/.env.example" &&
          -f "source/${API}-api/requirements.txt" ]]; then

        pass "${API}-api contiene Dockerfile, requirements y .env.example"
    else
        fail "${API}-api tiene archivos obligatorios faltantes"
    fi
done


echo
echo "=================================================="
echo " RESULTADO"
echo "=================================================="

TOTAL=$((PASS + FAIL))

if [[ "${TOTAL}" -gt 0 ]]; then
    PERCENT=$((PASS * 100 / TOTAL))
else
    PERCENT=0
fi

echo
echo "PASS : ${PASS}"
echo "FAIL : ${FAIL}"
echo "WARN : ${WARN}"
echo
echo "CUMPLIMIENTO TECNICO: ${PERCENT}%"
echo

if [[ "${FAIL}" -eq 0 ]]; then
    echo "RESULTADO: APROBADO"
    echo "El sistema pasó todos los controles técnicos automatizados."
else
    echo "RESULTADO: REVISAR"
    echo "Hay ${FAIL} control(es) que requieren corrección."
fi

echo
echo "NOTA:"
echo "Este script valida la parte técnica."
echo "La documentación y las capturas/evidencias se revisan por separado."
echo "=================================================="

if [[ "${FAIL}" -gt 0 ]]; then
    exit 1
fi

exit 0
