@'
# Café Boreal S.R.L. — Práctica de Examen Integrador ITI-522

Proyecto individual para la Práctica de Examen Integrador del curso ITI-522.

## Objetivo

Diseñar, implementar, desplegar, asegurar, monitorear y documentar una arquitectura completa para Café Boreal S.R.L. utilizando una única máquina virtual Ubuntu Server 22.04 LTS.

## Arquitectura general

La solución utilizará:

- Ubuntu Server 22.04 LTS
- Git
- Docker
- Minikube
- Kubernetes
- PostgreSQL
- Python
- FastAPI
- SQLAlchemy
- Nginx
- Apache
- PHP
- TLS autofirmado
- Prometheus
- cAdvisor
- Grafana
- Loki
- Promtail

## Microservicios

El proyecto contendrá tres servicios principales:

- Catalog API
- Customers API
- Orders API

Además contará con:

- Frontend web
- Sistema Legacy en PHP
- PostgreSQL
- Observabilidad
- Backups
- Pruebas de carga
- Smoke tests

## Estructura

```text
cafe-boreal-practica-examen/
├── source/
│   ├── catalog-api/
│   ├── customers-api/
│   ├── orders-api/
│   ├── frontend/
│   └── legacy/
├── deploy/
│   ├── kubernetes/
│   │   ├── catalog/
│   │   ├── customers/
│   │   ├── orders/
│   │   ├── database/
│   │   └── monitoring/
│   ├── nginx/
│   ├── backup/
│   ├── scripts/
│   └── tests/
├── docs/
│   └── diagramas/
├── evidence/
│   ├── fase0/
│   ├── fase1/
│   ├── fase2/
│   ├── fase3/
│   ├── fase4/
│   ├── fase5/
│   └── fase6/
├── .gitignore
├── README.md
└── CHANGELOG.md