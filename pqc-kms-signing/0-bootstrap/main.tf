/**
 * Copyright 2026 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

provider "google" {
  project = var.project_id
  region  = var.location
}

resource "google_project_service" "kms" {
  project            = var.project_id
  service            = "cloudkms.googleapis.com"
  disable_on_destroy = false
}

resource "google_kms_key_ring" "pqc_keyring" {
  name     = var.keyring_name
  location = var.location

  depends_on = [google_project_service.kms]
}

resource "google_kms_crypto_key" "pqc_signing_key" {
  name     = var.key_name
  key_ring = google_kms_key_ring.pqc_keyring.id
  purpose  = "ASYMMETRIC_SIGN"

  version_template {
    algorithm        = "PQ_SIGN_ML_DSA_87"
    protection_level = "SOFTWARE"
  }

  lifecycle {
    prevent_destroy = false
  }
}

data "google_client_openid_userinfo" "current" {}

resource "google_kms_crypto_key_iam_member" "signer_verifier" {
  crypto_key_id = google_kms_crypto_key.pqc_signing_key.id
  role          = "roles/cloudkms.signerVerifier"
  member        = "user:${data.google_client_openid_userinfo.current.email}"
}

resource "google_kms_crypto_key_iam_member" "public_key_viewer" {
  crypto_key_id = google_kms_crypto_key.pqc_signing_key.id
  role          = "roles/cloudkms.publicKeyViewer"
  member        = "user:${data.google_client_openid_userinfo.current.email}"
}
