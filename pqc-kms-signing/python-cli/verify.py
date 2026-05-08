import argparse
import hashlib
import sys
from pathlib import Path

from cryptography.hazmat.primitives.serialization import load_pem_public_key
from cryptography.exceptions import InvalidSignature
from google.cloud import kms_v1

KMS_MAX_DATA_BYTES = 65536


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Verify a document signature using a Cloud KMS post-quantum key."
    )
    parser.add_argument("--project",  required=True, help="Google Cloud project ID")
    parser.add_argument("--location", required=True, help="KMS key ring location (e.g. us-east1)")
    parser.add_argument("--keyring",  required=True, help="KMS key ring name")
    parser.add_argument("--key",      required=True, help="KMS crypto key name")
    parser.add_argument("--input",    required=True, help="Path to the original document")
    parser.add_argument("--sig",      required=True, help="Path to the .sig file")
    return parser.parse_args()


def get_enabled_key_version(client: kms_v1.KeyManagementServiceClient, key_name: str) -> str:
    """
    Retrieve the primary key version, falling back to listing
    ENABLED versions if the primary field is not populated.
    """
    crypto_key = client.get_crypto_key(request={"name": key_name})

    if (
        crypto_key.primary
        and crypto_key.primary.state
        == kms_v1.CryptoKeyVersion.CryptoKeyVersionState.ENABLED
    ):
        print(f"[INFO] Using primary key version: {crypto_key.primary.name}")
        return crypto_key.primary.name

    print("[WARN] Primary field not populated. Searching for ENABLED versions...")
    versions = sorted(
        client.list_crypto_key_versions(
            request=kms_v1.ListCryptoKeyVersionsRequest(
                parent=key_name,
                filter="state=ENABLED",
            )
        ),
        key=lambda v: int(v.name.split("/")[-1]),
    )

    if not versions:
        print("[ERROR] No ENABLED key versions found.")
        sys.exit(1)

    selected = versions[0].name
    print(f"[INFO] Found ENABLED key version: {selected}")
    return selected


def prepare_payload(content: bytes) -> tuple[bytes, bool]:
    """
    Mirror of sign.py's prepare_payload — must always return the same bytes
    that were sent to KMS during signing.

    - Files <= 65536 bytes : raw content.
    - Files  > 65536 bytes : SHA-512 digest (64 bytes).
    """
    if len(content) <= KMS_MAX_DATA_BYTES:
        return content, False

    digest = hashlib.sha512(content).digest()
    print(
        f"[INFO] File exceeds {KMS_MAX_DATA_BYTES} bytes — "
        f"verifying against SHA-512 digest ({len(digest)} bytes)."
    )
    return digest, True


def verify_document(
    project_id: str,
    location: str,
    keyring_name: str,
    key_name: str,
    input_path: str,
    sig_path: str,
) -> None:
    """Verify a document signature using a Cloud KMS ML-DSA-65 post-quantum key."""

    document = Path(input_path)
    if not document.exists():
        print(f"[ERROR] Input file not found: {input_path}")
        sys.exit(1)

    print(f"[INFO] Reading document: {input_path}")
    content = document.read_bytes()
    print(f"[INFO] Document size: {len(content)} bytes")

    signature_file = Path(sig_path)
    if not signature_file.exists():
        print(f"[ERROR] Signature file not found: {sig_path}")
        sys.exit(1)

    print(f"[INFO] Reading signature: {sig_path} ({signature_file.stat().st_size} bytes)")
    signature = signature_file.read_bytes()

    payload, is_digest = prepare_payload(content)

    client   = kms_v1.KeyManagementServiceClient()
    key_path = client.crypto_key_path(project_id, location, keyring_name, key_name)

    print("[INFO] Fetching KMS key version details...")
    key_version_name = get_enabled_key_version(client, key_path)
    key_version      = client.get_crypto_key_version(request={"name": key_version_name})
    algorithm        = kms_v1.CryptoKeyVersion.CryptoKeyVersionAlgorithm(key_version.algorithm).name
    print(f"[INFO] Algorithm: {algorithm}")

    print("[INFO] Fetching public key from KMS...")
    public_key_response = client.get_public_key(request={"name": key_version_name})
    public_key_pem      = public_key_response.pem.encode("utf-8")
    public_key          = load_pem_public_key(public_key_pem)
    print(f"[INFO] Public key loaded ({len(public_key_pem)} bytes PEM)")

    print("[INFO] Verifying signature locally with public key...")
    try:
        public_key.verify(signature, payload)
        print("[SUCCESS] Signature is VALID! Document integrity confirmed.")
        if is_digest:
            print("[NOTE] Verification covered the SHA-512 digest of the original document.")
    except InvalidSignature:
        print("[FAILURE] Signature is INVALID! The document may have been tampered with.")
        sys.exit(1)
    except Exception as e:
        print(f"[ERROR] Verification failed unexpectedly: {e}")
        sys.exit(1)


def main() -> None:
    args = parse_args()
    verify_document(
        project_id   = args.project,
        location     = args.location,
        keyring_name = args.keyring,
        key_name     = args.key,
        input_path   = args.input,
        sig_path     = args.sig,
    )


if __name__ == "__main__":
    main()
