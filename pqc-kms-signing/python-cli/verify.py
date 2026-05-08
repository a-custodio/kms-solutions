#!/usr/bin/env python3

# Copyright 2026 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

import argparse
import hashlib
import sys
from pathlib import Path

from google.cloud import kms_v1

KMS_MAX_DATA_BYTES = 65536


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Sign a document with a Cloud KMS "
                    "post-quantum key (ML-DSA-65)."
    )
    parser.add_argument(
        "--project", required=True, help="Google Cloud project ID"
    )
    parser.add_argument(
        "--location", required=True,
        help="KMS key ring location (e.g. us-east1)"
    )
    parser.add_argument(
        "--keyring", required=True, help="KMS key ring name"
    )
    parser.add_argument(
        "--key", required=True, help="KMS crypto key name"
    )
    parser.add_argument(
        "--input", required=True, help="Path to the document to sign"
    )
    parser.add_argument(
        "--output", required=True, help="Path to save the .sig file"
    )
    return parser.parse_args()


def get_enabled_key_version(
    client: kms_v1.KeyManagementServiceClient, key_name: str
) -> str:
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

    print(
        "[WARN] Primary field not populated. Searching for ENABLED versions..."
    )
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
    Return the payload to send to KMS and whether it is a digest.

    - Files <= 65536 bytes : send raw content directly.
    - Files  > 65536 bytes : send SHA-512 digest (64 bytes) of the content.

    The verify.py counterpart must apply the same logic so both sides
    always agree on what was signed.
    """
    if len(content) <= KMS_MAX_DATA_BYTES:
        return content, False

    digest = hashlib.sha512(content).digest()
    print(
        f"[INFO] File exceeds {KMS_MAX_DATA_BYTES} bytes — "
        f"signing SHA-512 digest ({len(digest)} bytes) instead of raw content."
    )
    return digest, True


def sign_document(
    project_id: str,
    location: str,
    keyring_name: str,
    key_name: str,
    input_path: str,
    output_path: str,
) -> None:
    """Sign a document using a Cloud KMS ML-DSA-65 post-quantum key."""

    document = Path(input_path)
    if not document.exists():
        print(f"[ERROR] Input file not found: {input_path}")
        sys.exit(1)

    print(f"[INFO] Reading document: {input_path}")
    content = document.read_bytes()
    print(f"[INFO] Document size: {len(content)} bytes")

    payload, is_digest = prepare_payload(content)

    client = kms_v1.KeyManagementServiceClient()
    key_path = client.crypto_key_path(
        project_id, location, keyring_name, key_name
    )

    print("[INFO] Fetching KMS key version details...")
    key_version_name = get_enabled_key_version(client, key_path)
    key_version = client.get_crypto_key_version(
        request={"name": key_version_name}
    )
    algorithm = kms_v1.CryptoKeyVersion.CryptoKeyVersionAlgorithm(
        key_version.algorithm
    ).name
    print(f"[INFO] Algorithm: {algorithm}")

    print("[INFO] Signing with KMS...")
    sign_response = client.asymmetric_sign(
        request={
            "name": key_version_name,
            "data": payload,
        }
    )

    sig_path = Path(output_path)
    sig_path.write_bytes(sign_response.signature)
    print(
        f"[INFO] Signature saved to: {output_path} "
        f"({len(sign_response.signature)} bytes)"
    )

    if is_digest:
        print(
            "[NOTE] Large file: signature covers the SHA-512 digest "
            "of the document."
        )
        print(
            "[NOTE] Use verify.py with the original file — "
            "it applies the same digest logic."
        )

    print("[SUCCESS] Document signed successfully!")


def main() -> None:
    args = parse_args()
    sign_document(
        project_id=args.project,
        location=args.location,
        keyring_name=args.keyring,
        key_name=args.key,
        input_path=args.input,
        output_path=args.output,
    )


if __name__ == "__main__":
    main()
