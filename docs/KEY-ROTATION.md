# Rotación de claves de cifrado

## Café Boreal S.R.L.

El campo `numero_identidad` de los clientes se almacena cifrado en PostgreSQL.

## Algoritmo

Se utiliza:

- AES-256-GCM.
- Claves de 256 bits.
- Nonce aleatorio de 12 bytes.
- Versionado del ciphertext.

Los valores cifrados utilizan un formato como:

v1:<ciphertext>

o:

v2:<ciphertext>

## Generación de claves

Las claves se generan mediante OpenSSL:

openssl rand -hex 32

Los 32 bytes generados equivalen a 256 bits.

Las claves reales nunca deben almacenarse en Git.

## Procedimiento de rotación

1. Se creó inicialmente KEY_V1.
2. Los 10 clientes fueron cifrados utilizando KEY_V1.
3. Se generó KEY_V2 de 256 bits.
4. Durante la transición se mantuvieron KEY_V1 y KEY_V2.
5. Se creó un backup antes de modificar los datos.
6. Los registros v1 fueron descifrados con KEY_V1.
7. Las identidades fueron cifradas nuevamente con KEY_V2.
8. La actualización se realizó mediante una transacción.
9. Se verificó que ningún cliente permaneciera utilizando v1.
10. Se comprobó el descifrado correcto utilizando KEY_V2.
11. KEY_V1 fue retirada del Kubernetes Secret activo.
12. KEY_V1 se conserva únicamente fuera de Git para recuperar backups históricos que todavía dependan de ella.

## Resultado validado

Antes:

KEY_V1: 10 registros
KEY_V2: 0 registros

Después:

KEY_V1: 0 registros
KEY_V2: 10 registros

## Kubernetes Secret

Durante la transición:

KEY_V1
KEY_V2

Después de completar y validar la rotación:

KEY_V2

## Protección de secretos

Las claves reales:

- no se guardan en Git;
- no se incluyen en documentación;
- no deben aparecer en capturas;
- no deben aparecer en logs;
- se almacenan fuera del repositorio;
- utilizan permisos restringidos.

## Backups históricos

Los backups anteriores a una rotación pueden contener información cifrada con una clave retirada.

Por esta razón, una clave antigua debe conservarse de forma protegida mientras existan respaldos que dependan de ella.
