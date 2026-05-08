variable "project_id" {
  description = "The Google Cloud project ID where KMS resources will be created."
  type        = string
}

variable "location" {
  description = "The Google Cloud location for the KMS key ring."
  type        = string
  default     = "us-east1"
}

variable "keyring_name" {
  description = "The name of the KMS key ring."
  type        = string
  default     = "pqc-keyring"
}

variable "key_name" {
  description = "The name of the post-quantum signing key."
  type        = string
  default     = "pqc-signing-key"
}
