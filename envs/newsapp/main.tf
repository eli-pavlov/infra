locals {
  node_names = ["master", "node-1", "node-2", "node-3"]
  node_roles = ["control-plane", "frontend", "worker", "worker"]

  instances_count = length(local.node_names)
  total_ocpus     = local.instances_count * var.ocpus
  total_mem       = local.instances_count * var.memory_gb
}

# --- AD name from number ---
data "oci_identity_availability_domains" "ads" {
  compartment_id = var.tenancy_ocid
}

locals {
  ad_name        = data.oci_identity_availability_domains.ads.availability_domains[var.availability_domain_number - 1].name
  cloud_init_b64 = var.cloud_init == "" ? "" : base64encode(var.cloud_init)
}

# --- VCN & existing PUBLIC subnet (for node-1) ---
data "oci_core_vcns" "vcn" {
  compartment_id = var.network_compartment_ocid
  display_name   = var.vcn_display_name
}

locals {
  vcn_id = one(data.oci_core_vcns.vcn.virtual_networks).id
}

data "oci_core_subnets" "public_existing" {
  compartment_id = var.network_compartment_ocid
  vcn_id         = local.vcn_id
  display_name   = var.subnet_display_name
}

locals {
  public_subnet_id = one(data.oci_core_subnets.public_existing.subnets).id
}

# --- NAT + private route table + PRIVATE subnet (new) ---
resource "oci_core_nat_gateway" "nat" {
  compartment_id = var.network_compartment_ocid
  vcn_id         = local.vcn_id
  display_name   = "newsapp-nat"
}

resource "oci_core_route_table" "private_rt" {
  compartment_id = var.network_compartment_ocid
  vcn_id         = local.vcn_id
  display_name   = "newsapp-private-rt"

  route_rules {
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_nat_gateway.nat.id
  }
}

resource "oci_core_subnet" "private" {
  compartment_id             = var.network_compartment_ocid
  vcn_id                     = local.vcn_id
  cidr_block                 = var.private_subnet_cidr
  display_name               = "newsapp-private-1"
  prohibit_public_ip_on_vnic = true
  route_table_id             = oci_core_route_table.private_rt.id
  dns_label                  = "newsapppriv"
}

# --- NSGs ---
resource "oci_core_network_security_group" "nsg_internal" {
  compartment_id = var.network_compartment_ocid
  vcn_id         = local.vcn_id
  display_name   = "nsg-k8s-internal"
}

# allow all traffic within the NSG (cluster internal)
resource "oci_core_network_security_group_security_rule" "nsg_internal_self_ingress" {
  network_security_group_id = oci_core_network_security_group.nsg_internal.id
  direction                 = "INGRESS"
  protocol                  = "all"
  source_type               = "NETWORK_SECURITY_GROUP"
  source                    = oci_core_network_security_group.nsg_internal.id
}

resource "oci_core_network_security_group_security_rule" "nsg_internal_egress_all" {
  network_security_group_id = oci_core_network_security_group.nsg_internal.id
  direction                 = "EGRESS"
  protocol                  = "all"
  destination_type          = "CIDR_BLOCK"
  destination               = "0.0.0.0/0"
}

# Public NSG for HTTP/HTTPS on node-1
resource "oci_core_network_security_group" "nsg_public_www" {
  compartment_id = var.network_compartment_ocid
  vcn_id         = local.vcn_id
  display_name   = "nsg-public-www"
}

# Build ingress rules for ports 80 and 443 from your allowlisted CIDRs JSON
locals {
  public_cidrs = [
    for r in try(jsondecode(var.ingress_rules_json), []) : r.cidr
  ]
}

# 80/tcp from allowed CIDRs
resource "oci_core_network_security_group_security_rule" "nsg_public_http" {
  for_each                  = toset(local.public_cidrs)
  network_security_group_id = oci_core_network_security_group.nsg_public_www.id
  direction                 = "INGRESS"
  protocol                  = "6"            # TCP
  source_type               = "CIDR_BLOCK"
  source                    = each.value

  tcp_options {
    destination_port_range {
      min = 80
      max = 80
    }
  }
}

# 443/tcp from allowed CIDRs
resource "oci_core_network_security_group_security_rule" "nsg_public_https" {
  for_each                  = toset(local.public_cidrs)
  network_security_group_id = oci_core_network_security_group.nsg_public_www.id
  direction                 = "INGRESS"
  protocol                  = "6"            # TCP
  source_type               = "CIDR_BLOCK"
  source                    = each.value

  tcp_options {
    destination_port_range {
      min = 443
      max = 443
    }
  }
}

# Egress all for public NSG
resource "oci_core_network_security_group_security_rule" "nsg_public_egress_all" {
  network_security_group_id = oci_core_network_security_group.nsg_public_www.id
  direction                 = "EGRESS"
  protocol                  = "all"
  destination_type          = "CIDR_BLOCK"
  destination               = "0.0.0.0/0"
}

# --- Free tier guardrails ---
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

# --- Instances ---
module "nodes" {
  source = "../../modules/instance"
  count  = length(local.node_names)

  name                     = local.node_names[count.index]
  hostname                 = local.node_names[count.index]
  role                     = local.node_roles[count.index]
  availability_domain_name = local.ad_name
  fault_domain             = var.fault_domain

  compartment_ocid = var.compartment_ocid
  subnet_ocid      = count.index == 1 ? local.public_subnet_id : oci_core_subnet.private.id
  image_ocid       = var.image_ocid
  ssh_public_key   = var.ssh_public_key

  # node-1 (index 1) gets public IP + public NSG; others private only
  assign_public_ip = count.index == 1
  nsg_ids          = count.index == 1
                      ? [oci_core_network_security_group.nsg_internal.id, oci_core_network_security_group.nsg_public_www.id]
                      : [oci_core_network_security_group.nsg_internal.id]

  ocpus             = var.ocpus
  memory_gb         = var.memory_gb
  cloud_init_base64 = local.cloud_init_b64
  tags              = var.tags
}
