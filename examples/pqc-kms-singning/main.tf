module "pqc_signing" {
  source = "../../pqc-kms-signing/0-bootstrap"

  project_id   = var.project_id
  location     = var.location
  keyring_name = var.keyring_name
  key_name     = var.key_name
}
