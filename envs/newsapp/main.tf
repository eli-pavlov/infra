locals {
  total_ocpus = var.instances * var.ocpus
  total_mem   = var.instances * var.memory_gb
}

data "oci_identity_availability_domains" "ads" {
  compartment_id = var.tenancy_ocid
}

locals {
  ad_name = data.oci_identity_availability_domains.ads.availability_domains[var.availability_domain_number - 1].name
}

data "oci_core_vcns" "this" {
  compartment_id = var.tenancy_ocid
  display_name   = var.vcn_display_name
}

locals { vcn_id = one(data.oci_core_vcns.this.virtual_networks).id }

data "oci_core_subnets" "this" {
  compartment_id = var.tenancy_ocid
  vcn_id         = local.vcn_id
  display_name   = var.subnet_display_name
}

locals { subnet_id = one(data.oci_core_subnets.this.subnets).id }

data "oci_core_images" "ubuntu" {
  compartment_id = var.tenancy_ocid
  shape          = "VM.Standard.A1.Flex"
  filter {
    name   = "display_name"
    values = [var.ubuntu_image_display_name]
    regex  = false
  }
}

locals {
  image_id       = one(data.oci_core_images.ubuntu.images).id
  cloud_init_b64 = var.cloud_init == "" ? "" : base64encode(var.cloud_init)
}

resource "null_resource" "free_tier_guards" {
  lifecycle {
    precondition {
      condition     = local.total_ocpus <= 4
      error_message = "Exceeds limit: ocpus=${local.total_ocpus} (max 4)."
    }
    precondition {
      condition     = local.total_mem <= 24
      error_message = "Exceeds limit: memory=${local.total_mem} GB (max 24 GB)."
    }
  }
}

module "nodes" {
  source = "../../modules/instance"
  count  = var.instances

  name                     = "${var.name_prefix}-${count.index + 1}"
  hostname                 = "${var.name_prefix}-${count.index + 1}"
  role                     = var.role
  availability_domain_name = local.ad_name
  fault_domain             = var.fault_domain
  compartment_ocid         = var.tenancy_ocid
  subnet_ocid              = local.subnet_id
  image_ocid               = local.image_id
  ssh_public_key           = var.ssh_public_key
  ocpus                    = var.ocpus
  memory_gb                = var.memory_gb
  cloud_init_base64        = local.cloud_init_b64
  tags                     = var.tags
}

output "public_ips"   { value = [for m in module.nodes : m.public_ip] }
output "private_ips"  { value = [for m in module.nodes : m.private_ip] }
output "instance_ids" { value = [for m in module.nodes : m.id] }
