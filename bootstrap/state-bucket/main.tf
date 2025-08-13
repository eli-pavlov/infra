# List buckets in the compartment/namespace; create only if missing
data "oci_objectstorage_bucket_summaries" "list" {
  compartment_id = var.compartment_ocid
  namespace      = var.os_namespace
}

locals {
  exists = length([
    for b in data.oci_objectstorage_bucket_summaries.list.bucket_summaries :
    b.name if b.name == var.bucket_name
  ]) > 0
}

resource "oci_objectstorage_bucket" "state" {
  count          = local.exists ? 0 : 1
  compartment_id = var.compartment_ocid
  name           = var.bucket_name
  namespace      = var.os_namespace
}
