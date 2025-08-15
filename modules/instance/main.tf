resource "oci_core_instance" "this" {
  availability_domain = var.availability_domain_name
  compartment_id      = var.compartment_ocid
  display_name        = var.name
  shape               = "VM.Standard.A1.Flex"
  fault_domain        = var.fault_domain

  shape_config {
    ocpus         = var.ocpus
    memory_in_gbs = var.memory_gb
  }

  create_vnic_details {
    subnet_id              = var.subnet_ocid
    assign_public_ip       = var.assign_public_ip
    hostname_label         = var.hostname
    nsg_ids                = length(var.nsg_ids) > 0 ? var.nsg_ids : null
    skip_source_dest_check = false
  }

  source_details {
    source_type = "image"
    source_id   = var.image_ocid
  }

  metadata = {
    ssh_authorized_keys = var.ssh_public_key
    user_data           = var.cloud_init_base64
  }

  freeform_tags = merge({ "managed-by" = "terraform", "role" = var.role }, var.tags)
}
