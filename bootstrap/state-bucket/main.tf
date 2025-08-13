# Discover namespace automatically – no input var needed
data "oci_objectstorage_namespace" "ns" {
  compartment_id = var.compartment_ocid
}

# List existing buckets and check whether the target exists
data "oci_objectstorage_bucket_summaries" "list" {
  compartment_id = var.compartment_ocid
  namespace      = data.oci_objectstorage_namespace.ns.namespace
}

locals {
  bucket_summaries = try(data.oci_objectstorage_bucket_summaries.list.bucket_summaries, [])
  bucket_exists    = length([for b in local.bucket_summaries : b.name if b.name == var.bucket_name]) > 0
}

# Create the bucket only if it doesn't exist
resource "oci_objectstorage_bucket" "state" {
  count          = local.bucket_exists ? 0 : 1
  compartment_id = var.compartment_ocid
  namespace      = data.oci_objectstorage_namespace.ns.namespace
  name           = var.bucket_name
  access_type    = "NoPublicAccess"
  storage_tier   = "Standard"
}

output "bucket_namespace" { value = data.oci_objectstorage_namespace.ns.namespace }
output "bucket_created"   { value = !local.bucket_exists }
