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

variable "algorithm" {
  description = "The post-quantum signing algorithm for the KMS crypto key."
  type        = string
  default     = "PQ_SIGN_ML_DSA_87"
}

variable "enable_services" {
  description = "Controla se os serviços devem ser habilitados."
  type        = bool
  default     = true
}

variable "prevent_destroy" {
  description = "Controla se os recursos podem ser destruídos."
  type        = bool
  default     = true
}
