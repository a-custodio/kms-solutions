#!/bin/bash

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

set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <file.pdf> [file.sig]"
  exit 1
fi

PDF_FILE="$1"
SIG_FILE="${2:-${PDF_FILE%.pdf}.sig}"

if [[ ! -f "$PDF_FILE" ]]; then
  echo "Error: PDF file not found: $PDF_FILE"
  exit 1
fi

if [[ ! -f "$SIG_FILE" ]]; then
  echo "Error: signature file not found: $SIG_FILE"
  echo "Run first: ./sign.sh $PDF_FILE"
  exit 1
fi

if [[ -z "${KMS_KEY_URI:-}" ]]; then
  echo "Error: KMS_KEY_URI environment variable is not set."
  echo "Run: export KMS_KEY_URI=\$(terraform output -raw kms_key_uri)"
  exit 1
fi

if ! command -v gcloud &>/dev/null; then
  echo "Error: gcloud CLI not found."
  exit 1
fi

if ! command -v docker &>/dev/null; then
  echo "Error: docker not found."
  echo "Please install Docker: https://docs.docker.com/engine/install/"
  exit 1
fi

KMS_RESOURCE="${KMS_KEY_URI#gcp-kms://}"

PROJECT=$(echo "$KMS_RESOURCE"  | cut -d'/' -f2)
LOCATION=$(echo "$KMS_RESOURCE" | cut -d'/' -f4)
KEYRING=$(echo "$KMS_RESOURCE"  | cut -d'/' -f6)
KEY=$(echo "$KMS_RESOURCE"      | cut -d'/' -f8)
VERSION=$(echo "$KMS_RESOURCE"  | cut -d'/' -f10)

echo "Verifying ML-DSA-87 signature..."
echo "  File      : $PDF_FILE"
echo "  Signature : $SIG_FILE"
echo "  Project   : $PROJECT"
echo "  Location  : $LOCATION"
echo "  Key Ring  : $KEYRING"
echo "  Key       : $KEY"
echo "  Version   : $VERSION"
echo ""

WORK_DIR=$(mktemp -d /tmp/ml_dsa_verify_XXXXXX)
PUB_KEY_FILE="$WORK_DIR/pubkey.pem"
trap 'rm -rf "$WORK_DIR"' EXIT

echo "Exporting public key from KMS..."
gcloud kms keys versions get-public-key "$VERSION" \
  --project="$PROJECT" \
  --location="$LOCATION" \
  --keyring="$KEYRING" \
  --key="$KEY" \
  --output-file="$PUB_KEY_FILE"

echo "  Public key saved to: $PUB_KEY_FILE"
echo ""

cp "$PDF_FILE" "$WORK_DIR/document.pdf"
cp "$SIG_FILE" "$WORK_DIR/document.sig"

DOCKER_IMAGE="ml-dsa-verifier"

if ! docker image inspect "$DOCKER_IMAGE" &>/dev/null; then
  echo "Building Docker image ($DOCKER_IMAGE) with OpenSSL 3.5 (alpine:latest)..."
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  docker build -t "$DOCKER_IMAGE" "$SCRIPT_DIR"
  echo ""
fi

echo "Verifying with OpenSSL 3.5 (alpine:latest Docker container)..."

if docker run --rm \
  -v "$WORK_DIR:/verify" \
  "$DOCKER_IMAGE" \
  -inkey /verify/pubkey.pem \
  -sigfile /verify/document.sig \
  -in /verify/document.pdf; then
  echo ""
  echo "Signature is VALID!"
  exit 0
else
  echo ""
  echo "Signature is INVALID!"
  exit 1
fi
