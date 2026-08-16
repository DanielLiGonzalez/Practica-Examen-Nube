# CHANGELOG

Registro de cambios del proyecto Café Boreal S.R.L.

---

## Desarrollo

### Preparación inicial

Fecha: 2026-08-15

Responsable:

DanielLiGonzalez

Cambios:

- Inicio de la práctica individual.
- Preparación de la estructura base del repositorio.
- Creación de directorios para código fuente.
- Creación de directorios para Kubernetes.
- Creación de directorios para documentación.
- Creación de directorios para evidencias.
- Creación inicial de README.md.
- Creación inicial de CHANGELOG.md.
- Creación inicial de .gitignore.

Estado:

En preparación.

---

## Tags previstos

### v1-Infraestructura

Fecha: 2026-08-15

Responsable:

DanielLiGonzalez

Estado: Completada y validada.

Principales cambios:

- VM Ubuntu Server 22.04.5 LTS configurada.
- 4 vCPU, aproximadamente 12 GB RAM y disco raíz ampliado a 76 GB.
- Acceso SSH configurado para el usuario devops.
- Docker Engine y Docker Compose instalados y validados.
- kubectl instalado.
- Minikube desplegado utilizando el driver Docker.
- Nodo Kubernetes validado en estado Ready.
- Ingress Nginx habilitado en Minikube.
- Namespace cafe-boreal creado.
- PostgreSQL 16 desplegado mediante StatefulSet.
- PersistentVolumeClaim de 10 GiB validado en estado Bound.
- Secret y ConfigMap configurados para PostgreSQL.
- Conectividad de PostgreSQL comprobada.
- Nginx instalado como punto frontal.
- Apache y PHP instalados para el futuro módulo Legacy.
- Apache configurado en el puerto 8080.
- Certificado TLS autofirmado generado.
- HTTPS configurado en Nginx.
- Redirección HTTP a HTTPS validada.
- UFW habilitado con política deny incoming.
- Puertos 22, 80 y 443 permitidos.
- Validación final completada sin CrashLoopBackOff.

Resultado:

Infraestructura base operativa y lista para iniciar la fase de datos.

---

### v2-Datos

Estado: Pendiente.

Alcance:

- PostgreSQL
- esquema de datos
- migraciones
- seeds
- cifrado
- Secrets
- backup inicial

---

### v3-Servicios

Estado: Pendiente.

Alcance:

- Catalog API
- Customers API
- Orders API
- Dockerfiles
- Kubernetes Deployments
- Services
- Ingress

---

### v4-Seguridad

Estado: Pendiente.

Alcance:

- Legacy
- Frontend
- Nginx HTTPS
- cifrado
- política de datos
- STRIDE
- hardening

---

### v5-Observabilidad

Estado: Pendiente.

Alcance:

- Prometheus
- cAdvisor
- Grafana
- Loki
- Promtail
- pruebas de carga
- backup y restore
- smoke tests
- scripts de operación

---

### v6-Docs

Estado: Pendiente.

Alcance:

- documentación final
- arquitectura
- runbook
- SLA
- decisiones de arquitectura
- bitácora
- evidencias
- validación final
