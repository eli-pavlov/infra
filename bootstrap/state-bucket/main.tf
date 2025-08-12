data "oci_objectstorage_namespace" "ns" {
  compartment_id = var.tenancy_ocid
}

# List buckets; if none with the same name, we'll create one.
data "oci_objectstorage_bucket_summaries" "list" {
  compartment_id = var.compartment_ocid
  namespace      = data.oci_objectstorage_namespace.ns.namespace
}

locals {
  exists = length([
    for b in data.oci_objectstorage_bucket_summaries.list.bucket_summaries :
    b.name if b.name == var.bucket_name
  ]) > 0
}

resource "oci_objectstorage_bucket" "state" {
  count         = local.exists ? 0 : 1
  compartment_id = var.compartment_ocid
  name           = var.bucket_name
  namespace      = data.oci_objectstorage_namespace.ns.namespace
}
