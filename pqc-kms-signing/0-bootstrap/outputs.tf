output "key_ring_id" {
  description = "The ID of the created KMS key ring."
  value       = google_kms_key_ring.pqc_keyring.id
}

output "signing_key_id" {
  description = "The resource ID of the post-quantum signing key."
  value       = google_kms_crypto_key.pqc_signing_key.id
}

output "location" {
  description = "The location of the KMS key ring."
  value       = var.location
}

output "keyring_name" {
  description = "The name of the KMS key ring."
  value       = var.keyring_name
}

output "key_name" {
  description = "The name of the post-quantum signing key."
  value       = var.key_name
}
