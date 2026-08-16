import base64
import os

from cryptography.hazmat.primitives.ciphers.aead import AESGCM


ACTIVE_KEY_VERSION = os.getenv(
    "IDENTITY_KEY_VERSION",
    "v2",
)


def load_key(version: str) -> bytes:
    env_name = f"KEY_{version.upper()}"

    raw_key = os.getenv(env_name)

    if not raw_key:
        raise RuntimeError(
            f"La variable {env_name} no está definida."
        )

    if len(raw_key) != 64:
        raise ValueError(
            f"{env_name} debe contener 64 caracteres hexadecimales."
        )

    try:
        key = bytes.fromhex(raw_key)
    except ValueError as exc:
        raise ValueError(
            f"{env_name} no contiene una clave hexadecimal válida."
        ) from exc

    if len(key) != 32:
        raise ValueError(
            f"{env_name} debe representar 256 bits."
        )

    return key


def associated_data(version: str) -> bytes:
    return (
        f"cafe-boreal:customers:numero-identidad:{version}"
    ).encode("utf-8")


def encrypt_identity(
    numero_identidad: str,
    version: str | None = None,
) -> str:
    value = numero_identidad.strip()

    if not value:
        raise ValueError(
            "numero_identidad no puede estar vacío."
        )

    selected_version = version or ACTIVE_KEY_VERSION

    key = load_key(selected_version)
    aesgcm = AESGCM(key)

    nonce = os.urandom(12)

    ciphertext = aesgcm.encrypt(
        nonce,
        value.encode("utf-8"),
        associated_data(selected_version),
    )

    payload = base64.urlsafe_b64encode(
        nonce + ciphertext
    ).decode("ascii")

    return f"{selected_version}:{payload}"


def decrypt_identity(encrypted_value: str) -> str:
    if ":" not in encrypted_value:
        raise ValueError(
            "Ciphertext sin versión de clave."
        )

    version, payload = encrypted_value.split(":", 1)

    key = load_key(version)

    try:
        raw = base64.urlsafe_b64decode(
            payload.encode("ascii")
        )
    except Exception as exc:
        raise ValueError(
            "Ciphertext Base64 inválido."
        ) from exc

    if len(raw) <= 12:
        raise ValueError(
            "Ciphertext inválido."
        )

    nonce = raw[:12]
    ciphertext = raw[12:]

    aesgcm = AESGCM(key)

    plaintext = aesgcm.decrypt(
        nonce,
        ciphertext,
        associated_data(version),
    )

    return plaintext.decode("utf-8")
