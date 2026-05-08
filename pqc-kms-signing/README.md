# Post-Quantum KMS: Signing and Verifying Documents with ML-DSA-65

## Overview

This example demonstrates how to use Google Cloud KMS with a post-quantum cryptographic key (ML-DSA-65) to sign a document and verify its signature, generating a `.sig` file.

ML-DSA-65 (Module Lattice Digital Signature Algorithm, security level 3) is a NIST-standardized post-quantum signature scheme designed to remain secure against attacks from future quantum computers.

> **Note:** For files larger than 64 KB, both scripts automatically compute a SHA-512 digest of the file and use that as the signing payload, staying within the KMS API limit. The verify script applies the same logic, so both sides always agree on what was signed.

## Prerequisites

- [Terraform](https://developer.hashicorp.com/terraform/install) >= 1.5.7;
- [Python 3.9+](https://www.python.org/downloads/);
- [pip](https://pip.pypa.io/en/stable/installation/);
- [Google Cloud CLI (`gcloud`)](https://cloud.google.com/sdk/docs/install-sdk);
- A Google Cloud project with billing enabled.

**Note:** It is recommended that you create and enable a Python [virtual environment](https://docs.python.org/3/library/venv.html) before running the Python scripts.

## Authenticate with Google Cloud

1. Log in to your Google Cloud account.
    ```sh
    gcloud auth login
    ```

1. Set up Application Default Credentials, required by both Terraform and the Python scripts.
    ```sh
    gcloud auth application-default login
    ```

1. Set your project as the active project.
    ```sh
    gcloud config set project YOUR_PROJECT_ID
    ```

## Deploy the Infrastructure

1. Navigate to the bootstrap directory.
    ```sh
    cd pqc-kms-signing/0-bootstrap
    ```

1. Copy the example tfvars file and fill in your values.
    ```sh
    cp terraform.example.tfvars terraform.tfvars
    ```

1. Edit `terraform.tfvars` and replace the placeholder with your project ID.
    ```hcl
    project_id   = "YOUR_PROJECT_ID"
    location     = "us-east1"
    keyring_name = "pqc-keyring"
    key_name     = "pqc-signing-key"
    ```

1. Initialize and apply Terraform.
    ```sh
    terraform init
    terraform apply
    ```

    **Note:** Review the planned changes and type `yes` to confirm. Terraform will enable the Cloud KMS API, create the key ring, the ML-DSA-65 signing key, and grant the required IAM roles to your user.

## Set Up the Python Environment

1. Navigate to the python-cli directory.
    ```sh
    cd pqc-kms-signing/python-cli
    ```

1. Create and activate a virtual environment.
    ```sh
    python3 -m venv .venv
    source .venv/bin/activate
    ```

1. Install dependencies.
    ```sh
    pip install -r requirements.txt
    ```

## Download the Sample Document

1. Download the RFC 5126 PDF, which will be used as the document to sign.
    ```sh
    curl -o rfc5126.txt.pdf https://www.rfc-editor.org/rfc/pdfrfc/rfc5126.txt.pdf
    ```

## Sign the Document

1. Run the sign script passing your GCP info, the input document, and the desired output `.sig` file.
    ```sh
    python sign.py \
      --project "YOUR_PROJECT_ID" \
      --location "us-east1" \
      --keyring "pqc-keyring" \
      --key "pqc-signing-key" \
      --input rfc5126.txt.pdf \
      --output rfc5126.txt.pdf.sig
    ```

    The expected output is:
    ```
    [INFO] Reading document: rfc5126.txt.pdf
    [INFO] Document size: 183867 bytes
    [INFO] File exceeds 65536 bytes — signing SHA-512 digest (64 bytes) instead of raw content.
    [INFO] Fetching KMS key version details...
    [INFO] Found ENABLED key version: projects/.../cryptoKeyVersions/1
    [INFO] Algorithm: PQ_SIGN_ML_DSA_65
    [INFO] Signing with KMS...
    [INFO] Signature saved to: rfc5126.txt.pdf.sig (3309 bytes)
    [NOTE] Large file: signature covers the SHA-512 digest of the document.
    [SUCCESS] Document signed successfully!
    ```

    **Note:** The `.sig` file contains the raw binary signature produced by the ML-DSA-65 key. Keep both the original document and the `.sig` file to perform verification.

## Verify the Signature

1. Run the verify script passing the original document and the `.sig` file.
    ```sh
    python verify.py \
      --project "YOUR_PROJECT_ID" \
      --location "us-east1" \
      --keyring "pqc-keyring" \
      --key "pqc-signing-key" \
      --input rfc5126.txt.pdf \
      --sig rfc5126.txt.pdf.sig
    ```

    The expected output is:
    ```
    [INFO] Reading document: rfc5126.txt.pdf
    [INFO] Document size: 183867 bytes
    [INFO] File exceeds 65536 bytes — verifying against SHA-512 digest (64 bytes).
    [INFO] Fetching KMS key version details...
    [INFO] Found ENABLED key version: projects/.../cryptoKeyVersions/1
    [INFO] Algorithm: PQ_SIGN_ML_DSA_65
    [INFO] Fetching public key from KMS...
    [INFO] Public key loaded (... bytes PEM)
    [INFO] Verifying signature locally with public key...
    [SUCCESS] Signature is VALID! Document integrity confirmed.
    ```

## Tamper Test (Optional)

This test confirms that the verification correctly rejects a document that has been modified after signing.

1. Create a tampered copy of the document.
    ```sh
    cp rfc5126.txt.pdf rfc5126_tampered.txt.pdf
    echo "tampered" >> rfc5126_tampered.txt.pdf
    ```

1. Run the verify script against the tampered file using the original signature.
    ```sh
    python verify.py \
      --project "YOUR_PROJECT_ID" \
      --location "us-east1" \
      --keyring "pqc-keyring" \
      --key "pqc-signing-key" \
      --input rfc5126_tampered.txt.pdf \
      --sig rfc5126.txt.pdf.sig
    ```

    The expected output is:
    ```
    [FAILURE] Signature is INVALID! The document may have been tampered with.
    ```

## Cleanup

1. Deactivate the Python virtual environment.
    ```sh
    deactivate
    ```

1. Navigate to the bootstrap directory and destroy the infrastructure.
    ```sh
    cd pqc-kms-signing/0-bootstrap
    terraform destroy
    ```

    **Note:** Review the planned destruction and type `yes` to confirm. This will schedule the KMS key version for destruction and delete the key ring. Make sure you no longer need the key before proceeding.
