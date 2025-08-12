locals {
  node_names        = ["master", "node-1", "node-2", "node-3"]
  node_roles        = ["control-plane", "worker", "worker", "worker"]
  instances_count   = length(local.node_names)
  total_ocpus       = local.instances_count * var.ocpus
  total_mem         = local.instances_count * var.memory_gb
}

data "oci_identity_availability_domains" "ads" {
  compartment_id = var.tenancy_ocid
}

locals {
  ad_name = data.oci_identity_availability_domains.ads.availability_domains[var.availability_domain_number - 1].name
}

data "oci_core_vcns" "this" {
  compartment_id = var.network_compartment_ocid
  display_name   = var.vcn_display_name
}

locals {
  vcn_id                 = one(data.oci_core_vcns.this.virtual_networks).id
  default_sl_id          = one(data.oci_core_vcns.this.virtual_networks).default_security_list_id
}

data "oci_core_subnets" "this" {
  compartment_id = var.network_compartment_ocid
  vcn_id         = local.vcn_id
  display_name   = var.subnet_display_name
}

locals {
  subnet_id      = one(data.oci_core_subnets.this.subnets).id
  cloud_init_b64 = var.cloud_init == "" ? "" : base64encode(var.cloud_init)
}

# Default Security List management (rules come from secrets as JSON)
locals {
  ingress_rules = try(jsondecode(var.ingress_rules_json), [])
  egress_rules  = try(jsondecode(var.egress_rules_json),  [ { protocol = "all", destination = "0.0.0.0/0" } ])
}

resource "oci_core_default_security_list" "managed" {
  manage_default_resource_id = local.default_sl_id

  dynamic "ingress_security_rules" {
    for_each = local.ingress_rules
    content {
      protocol      = ingress_security_rules.value.protocol
      source        = ingress_security_rules.value.cidr
      source_type   = "CIDR_BLOCK"
      is_stateless  = false
    }
  }

  dynamic "egress_security_rules" {
    for_each = local.egress_rules
    content {
      protocol          = egress_security_rules.value.protocol
      destination       = egress_security_rules.value.destination
      destination_type  = "CIDR_BLOCK"
      is_stateless      = false
    }
  }
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
  count  = local.instances_count

  name                     = local.node_names[count.index]
  hostname                 = local.node_names[count.index]
  role                     = local.node_roles[count.index]
  availability_domain_name = local.ad_name
  fault_domain             = var.fault_domain

  compartment_ocid = var.compartment_ocid
  subnet_ocid      = local.subnet_id
  image_ocid       = var.image_ocid
  ssh_public_key   = var.ssh_public_key

  ocpus             = var.ocpus
  memory_gb         = var.memory_gb
  cloud_init_base64 = local.cloud_init_b64
  tags              = var.tags
}

output "public_ips"   { value = [for m in module.nodes : m.public_ip] }
output "private_ips"  { value = [for m in module.nodes : m.private_ip] }
output "instance_ids" { value = [for m in module.nodes : m.id] }
