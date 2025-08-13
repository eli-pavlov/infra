# ---------- Sensitive provider auth ----------
variable "tenancy_ocid" {
  type      = string
  sensitive = true
}

variable "user_ocid" {
  type      = string
  sensitive = true
}

variable "fingerprint" {
  type      = string
  sensitive = true
}

variable "private_key_pem" {
  type      = string
  sensitive = true
}

variable "region" {
  type      = string
  sensitive = true
}

# Optional: use a file path to the PEM on the runner instead of the PEM string
variable "private_key_path" {
  type        = string
  default     = null
  sensitive   = true
  description = "Absolute path to OCI API key PEM; leave null to use private_key_pem."
}

# ---------- Inputs for the bucket ----------
variable "compartment_ocid" {
  type        = string
  description = "OCID of the compartment where the state bucket lives."
  sensitive   = true
}

variable "bucket_name" {
  type        = string
  description = "Object Storage bucket used for Terraform state."
}
