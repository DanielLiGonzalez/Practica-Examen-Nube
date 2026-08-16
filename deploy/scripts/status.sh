#!/usr/bin/env bash

set -u


echo "========================================"
echo " CAFE BOREAL - STATUS"
echo "========================================"


echo
echo "=== MINIKUBE ==="
minikube status || true


echo
echo "=== NODES ==="
kubectl get nodes || true


echo
echo "=== PODS ==="
kubectl get pods -n cafe-boreal || true


echo
echo "=== POSTGRESQL ==="

kubectl exec \
    -n cafe-boreal \
    postgres-0 \
    -- pg_isready \
    -U cafe_boreal \
    -d cafe_boreal \
    || true


echo
echo "=== INGRESS ==="
kubectl get ingress -n cafe-boreal || true


echo
echo "=== APACHE ==="
systemctl is-active apache2 || true


echo
echo "=== NGINX ==="
systemctl is-active nginx || true


echo
echo "=== FRONTEND HTTPS ==="

curl -ksS \
    -o /dev/null \
    -w "HTTP %{http_code}\n" \
    https://localhost/ \
    || true


echo
echo "=== CATALOG ==="
curl -ksS https://localhost/api/catalog/healthz \
    | jq \
    || true


echo
echo "=== CUSTOMERS ==="
curl -ksS https://localhost/api/customers/healthz \
    | jq \
    || true


echo
echo "=== ORDERS ==="
curl -ksS https://localhost/api/orders/healthz \
    | jq \
    || true


echo
echo "=== LEGACY ==="
curl -ksS https://localhost/legacy/inventory \
    | jq '.count' \
    || true


echo
echo "=== MONITORING ==="

kubectl get pods \
    -n cafe-boreal \
    | grep -E \
    'prometheus|grafana|loki|promtail|cadvisor' \
    || true


echo
echo "=== GRAFANA 5555 ==="

curl -sS \
    http://127.0.0.1:5555/api/health \
    | jq \
    || true
