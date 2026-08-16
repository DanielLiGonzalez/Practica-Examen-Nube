#!/usr/bin/env bash

set -Eeuo pipefail

ROOT_DIR="$(
    cd "$(dirname "${BASH_SOURCE[0]}")/../.." &&
    pwd
)"

cd "${ROOT_DIR}"


echo "=== Cafe Boreal: inicio ==="


if ! minikube status >/dev/null 2>&1; then
    minikube start \
        --driver=docker \
        --cpus=3 \
        --memory=7000
fi


kubectl apply \
    -f deploy/kubernetes/namespace.yaml


if [[ -f "${HOME}/.cafe-boreal/secrets/postgres.env" ]]; then
    kubectl create secret generic postgres-secret \
        -n cafe-boreal \
        --from-env-file="${HOME}/.cafe-boreal/secrets/postgres.env" \
        --dry-run=client \
        -o yaml \
    | kubectl apply -f -
fi


if [[ -f "${HOME}/.cafe-boreal/secrets/customer-crypto.env" ]]; then
    kubectl create secret generic customer-crypto-secret \
        -n cafe-boreal \
        --from-env-file="${HOME}/.cafe-boreal/secrets/customer-crypto.env" \
        --dry-run=client \
        -o yaml \
    | kubectl apply -f -
fi


if [[ -f "${HOME}/.cafe-boreal/secrets/grafana.env" ]]; then
    set -a
    source "${HOME}/.cafe-boreal/secrets/grafana.env"
    set +a

    kubectl create secret generic grafana-admin-secret \
        -n cafe-boreal \
        --from-literal=admin-user="${GRAFANA_ADMIN_USER}" \
        --from-literal=admin-password="${GRAFANA_ADMIN_PASSWORD}" \
        --dry-run=client \
        -o yaml \
    | kubectl apply -f -

    unset GRAFANA_ADMIN_USER
    unset GRAFANA_ADMIN_PASSWORD
fi


kubectl apply \
    -f deploy/kubernetes/database/postgres-configmap.yaml \
    -f deploy/kubernetes/database/postgres-pvc.yaml \
    -f deploy/kubernetes/database/postgres.yaml


kubectl wait \
    -n cafe-boreal \
    --for=condition=Ready \
    pod/postgres-0 \
    --timeout=180s


for SERVICE in catalog customers orders; do
    IMAGE="cafe-boreal/${SERVICE}-api:v1"

    if ! minikube image ls | grep -q "${IMAGE}"; then
        minikube image build \
            -t "${IMAGE}" \
            "source/${SERVICE}-api"
    fi
done


kubectl apply \
    -f deploy/kubernetes/catalog/ \
    -f deploy/kubernetes/customers/ \
    -f deploy/kubernetes/orders/ \
    -f deploy/kubernetes/ingress.yaml \
    -f deploy/kubernetes/monitoring/


kubectl rollout status \
    deployment/catalog-api \
    -n cafe-boreal \
    --timeout=180s

kubectl rollout status \
    deployment/customers-api \
    -n cafe-boreal \
    --timeout=180s

kubectl rollout status \
    deployment/orders-api \
    -n cafe-boreal \
    --timeout=180s


sudo mkdir -p /var/www/cafe-boreal
sudo cp -a source/frontend/. /var/www/cafe-boreal/


php source/legacy/init-db.php

sudo mkdir -p /var/www/html/legacy
sudo cp -a source/legacy/. /var/www/html/legacy/


sudo chown -R root:www-data /var/www/cafe-boreal
sudo chown -R root:www-data /var/www/html/legacy


MINIKUBE_IP="$(minikube ip)"

sed \
    -E \
    "s#proxy_pass http://[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+;#proxy_pass http://${MINIKUBE_IP};#" \
    deploy/nginx/cafe-boreal.conf \
    > /tmp/cafe-boreal.conf


sudo cp \
    /tmp/cafe-boreal.conf \
    /etc/nginx/sites-available/cafe-boreal.conf


sudo systemctl restart apache2

sudo nginx -t

sudo systemctl restart nginx


pkill -f \
    'kubectl port-forward.*service/grafana.*5555:3000' \
    2>/dev/null || true


nohup kubectl port-forward \
    -n cafe-boreal \
    service/grafana \
    5555:3000 \
    >/tmp/grafana-5555.log 2>&1 &


echo
echo "Cafe Boreal iniciado."
echo "Frontend: https://localhost/"
echo "Grafana:  http://localhost:5555/"
