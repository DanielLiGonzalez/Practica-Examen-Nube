#!/usr/bin/env python3

import argparse
import base64
import os
import sys

from cryptography.hazmat.primitives.ciphers.aead import AESGCM


KEY_ENV_BY_VERSION = {
    "v1": "KEY_V1",
    "v2": "KEY_V2",
}


def load_key(version: str) -> bytes:
    env_name = KEY_ENV_BY_VERSION.get(version)

    if env_name is None:
        raise ValueError(f"Versión de clave no soportada: {version}")

    raw_key = os.getenv(env_name)

    if not raw_key:
        raise RuntimeError(
            f"La variable de entorno {env_name} no está definida."
        )

    if len(raw_key) != 64:
        raise ValueError(
            f"{env_name} debe contener exactamente 64 caracteres hexadecimales."
        )

    try:
        key = bytes.fromhex(raw_key)
    except ValueError as exc:
        raise ValueError(
            f"{env_name} debe contener únicamente caracteres hexadecimales."
        ) from exc

    if len(key) != 32:
        raise ValueError(
            f"{env_name} debe representar exactamente 32 bytes (256 bits)."
        )

    return key


def associated_data(version: str) -> bytes:
    return f"cafe-boreal:customers:numero-identidad:{version}".encode("utf-8")


def encrypt_identity(numero_identidad: str, version: str = "v1") -> str:
    numero_identidad = numero_identidad.strip()

    if not numero_identidad:
        raise ValueError("numero_identidad no puede estar vacío.")

    key = load_key(version)
    aesgcm = AESGCM(key)

    nonce = os.urandom(12)

    ciphertext = aesgcm.encrypt(
        nonce,
        numero_identidad.encode("utf-8"),
        associated_data(version),
    )

    payload = base64.urlsafe_b64encode(
        nonce + ciphertext
    ).decode("ascii")

    return f"{version}:{payload}"


def decrypt_identity(encrypted_value: str) -> str:
    if ":" not in encrypted_value:
        raise ValueError(
            "El valor cifrado no contiene una versión de clave."
        )

    version, payload = encrypted_value.split(":", 1)

    key = load_key(version)

    try:
        decoded = base64.urlsafe_b64decode(payload.encode("ascii"))
    except Exception as exc:
        raise ValueError("El ciphertext no contiene Base64 válido.") from exc

    if len(decoded) <= 12:
        raise ValueError("El ciphertext es demasiado corto.")

    nonce = decoded[:12]
    ciphertext = decoded[12:]

    aesgcm = AESGCM(key)

    plaintext = aesgcm.decrypt(
        nonce,
        ciphertext,
        associated_data(version),
    )

    return plaintext.decode("utf-8")


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Cifrado de numero_identidad para Cafe Boreal."
    )

    subparsers = parser.add_subparsers(
        dest="command",
        required=True,
    )

    encrypt_parser = subparsers.add_parser(
        "encrypt",
        help="Cifra una identidad.",
    )
    encrypt_parser.add_argument(
        "value",
        help="Identidad en texto claro.",
    )
    encrypt_parser.add_argument(
        "--version",
        default="v1",
        choices=sorted(KEY_ENV_BY_VERSION.keys()),
        help="Versión de clave a utilizar.",
    )

    decrypt_parser = subparsers.add_parser(
        "decrypt",
        help="Descifra una identidad.",
    )
    decrypt_parser.add_argument(
        "value",
        help="Ciphertext versionado.",
    )

    return parser


def main() -> int:
    parser = build_parser()
    args = parser.parse_args()

    try:
        if args.command == "encrypt":
            print(
                encrypt_identity(
                    args.value,
                    version=args.version,
                )
            )
            return 0

        if args.command == "decrypt":
            print(decrypt_identity(args.value))
            return 0

        parser.error("Comando no reconocido.")
        return 2

    except Exception as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
