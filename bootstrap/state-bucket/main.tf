# bootstrap/state-bucket/main.tf

# We pass the namespace from secrets (no extra lookup)
# vars: compartment_ocid, bucket_name, os_namespace

data "oci_objectstorage_bucket_summaries" "list" {
  compartment_id = var.compartment_ocid
  namespace      = var.os_namespace
}

locals {
  # Be robust: if provider returns null, treat as empty list
  bucket_summaries       = try(data.oci_objectstorage_bucket_summaries.list.bucket_summaries, [])
  exists_in_compartment  = length([for b in local.bucket_summaries : b.name if b.name == var.bucket_name]) > 0
}

resource "oci_objectstorage_bucket" "state" {
  count          = local.exists_in_compartment ? 0 : 1
  compartment_id = var.compartment_ocid
  name           = var.bucket_name
  namespace      = var.os_namespace
  # (optional) prevent_destroy = true via lifecycle if you want extra safety
}