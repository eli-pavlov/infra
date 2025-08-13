terraform {
  required_version = ">= 1.4.0"
  required_providers {
    oci = {
      source  = "oracle/oci"
      version = "~> 6.0"
    }
  }
}

provider "oci" {
  tenancy_ocid = var.tenancy_ocid
  user_ocid    = var.user_ocid
  fingerprint  = var.fingerprint
  region       = var.region

  # Prefer file path if provided; otherwise use the in-memory PEM
  private_key_path = var.private_key_path
  private_key      = (
    var.private_key_path != null && trimspace(var.private_key_path) != ""
  ) ? null : var.private_key_pem
}
