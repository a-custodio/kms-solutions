provider "google" {
  project = var.project_id
  region  = var.location
}

# Enable the Cloud KMS API
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
    algorithm        = "PQ_SIGN_ML_DSA_65"
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
