# providers.tf
terraform {
  required_version = ">= 1.4.0"
  required_providers {
    oci = {
      source  = "oracle/oci"
      version = "~> 6.0"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
  }
}

provider "oci" {
  tenancy_ocid = var.tenancy_ocid
  user_ocid    = var.user_ocid
  fingerprint  = var.fingerprint
  region       = var.region

  private_key_path = var.private_key_path
  private_key      = var.private_key_pem
}
