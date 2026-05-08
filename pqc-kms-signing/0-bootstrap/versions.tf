terraform {
  required_version = ">= 1.5.7"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 5.11, < 8"
    }
  }

  provider_meta "google" {
    module_name = "blueprints/terraform/kms-solutions:pqc-kms-signing-bootstrap/v0.1.0"
  }
}
