locals {
  node_names = ["master", "node-1", "node-2", "node-3"]
  node_roles = ["control-plane", "frontend", "worker", "worker"]

  instances_count = length(local.node_names)
  total_ocpus     = local.instances_count * var.ocpus
  total_mem       = local.instances_count * var.memory_gb
}

# ---- ADs / cloud-init ---------------------------------------------
data "oci_identity_availability_domains" "ads" {
  compartment_id = var.tenancy_ocid
}

locals {
  ads_names      = [for ad in try(data.oci_identity_availability_domains.ads.availability_domains, []) : ad.name]
  ad_index       = var.availability_domain_number - 1
  ad_name        = (local.ad_index >= 0 && local.ad_index < length(local.ads_names)) ? local.ads_names[local.ad_index] : ""
  cloud_init_b64 = var.cloud_init == "" ? "" : base64encode(var.cloud_init)
}

resource "null_resource" "validate_ad" {
  lifecycle {
    precondition {
      condition     = length(local.ads_names) > 0 && local.ad_index >= 0 && local.ad_index < length(local.ads_names)
      error_message = "Invalid availability_domain_number; must be within the available AD range."
    }
  }
}

# ---- VCN lookup (null-safe) ---------------------------------------
data "oci_core_vcns" "vcns" {
  compartment_id = var.network_compartment_ocid
}

locals {
  vcns_all  = try([for v in data.oci_core_vcns.vcns.virtual_networks : v], [])
  vcn_match = [for v in local.vcns_all : v if v.display_name == var.vcn_display_name]
  vcn_id    = (length(local.vcn_match) == 1) ? local.vcn_match[0].id : null
}

resource "null_resource" "validate_vcn" {
  lifecycle {
    precondition {
      condition     = length(local.vcn_match) == 1
      error_message = "Required VCN not found or not unique in the selected compartment."
    }
  }
}

# ---- Existing PUBLIC subnet lookup (null-safe) ---------------------
data "oci_core_subnets" "subnets" {
  count          = local.vcn_id == null ? 0 : 1
  compartment_id = var.network_compartment_ocid
  vcn_id         = local.vcn_id
}

locals {
  subnets_all          = local.vcn_id == null ? [] : try([for s in data.oci_core_subnets.subnets[0].subnets : s], [])
  public_subnet_match  = [for s in local.subnets_all : s if s.display_name == var.subnet_display_name]
  public_subnet_id     = (length(local.public_subnet_match) == 1) ? local.public_subnet_match[0].id : null
}

resource "null_resource" "validate_public_subnet" {
  lifecycle {
    precondition {
      condition     = local.vcn_id != null && length(local.public_subnet_match) == 1
      error_message = "Required PUBLIC subnet not found or not unique in the target VCN."
    }
  }
}

# ---- NAT, Route, Private Subnet – gated by VCN presence -----------
# Key resources by vcn_id so they are skipped entirely when vcn_id=null
resource "oci_core_nat_gateway" "nat" {
  for_each      = local.vcn_id == null ? {} : { (local.vcn_id) = true }
  compartment_id = var.network_compartment_ocid
  vcn_id         = each.key
  display_name   = "newsapp-nat"
}

resource "oci_core_route_table" "private_rt" {
  for_each      = oci_core_nat_gateway.nat
  compartment_id = var.network_compartment_ocid
  vcn_id         = each.key
  display_name   = "newsapp-private-rt"

  route_rules {
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_nat_gateway.nat[each.key].id
  }
}

resource "oci_core_subnet" "private" {
  for_each                 = oci_core_route_table.private_rt
  compartment_id           = var.network_compartment_ocid
  vcn_id                   = each.key
  cidr_block               = var.private_subnet_cidr
  display_name             = "newsapp-private-1"
  prohibit_public_ip_on_vnic = true
  route_table_id           = oci_core_route_table.private_rt[each.key].id
  dns_label                = "newsapppriv"
}

# ---- NSGs – gated by VCN presence ---------------------------------
resource "oci_core_network_security_group" "nsg_internal" {
  for_each      = local.vcn_id == null ? {} : { (local.vcn_id) = true }
  compartment_id = var.network_compartment_ocid
  vcn_id         = each.key
  display_name   = "nsg-k8s-internal"
}

resource "oci_core_network_security_group" "nsg_public_www" {
  for_each      = local.vcn_id == null ? {} : { (local.vcn_id) = true }
  compartment_id = var.network_compartment_ocid
  vcn_id         = each.key
  display_name   = "nsg-public-www"
}

# Derive the single NSG IDs safely (null when VCN absent)
locals {
  internal_nsg_id = local.vcn_id == null ? null : one(values(oci_core_network_security_group.nsg_internal)).id
  public_nsg_id   = local.vcn_id == null ? null : one(values(oci_core_network_security_group.nsg_public_www)).id
}

# Internal NSG rules
resource "oci_core_network_security_group_security_rule" "nsg_internal_self_ingress" {
  for_each                  = local.internal_nsg_id == null ? {} : { (local.internal_nsg_id) = true }
  network_security_group_id = each.key
  direction                 = "INGRESS"
  protocol                  = "all"
  source_type               = "NETWORK_SECURITY_GROUP"
  source                    = each.key
}

resource "oci_core_network_security_group_security_rule" "nsg_internal_egress_all" {
  for_each                  = local.internal_nsg_id == null ? {} : { (local.internal_nsg_id) = true }
  network_security_group_id = each.key
  direction                 = "EGRESS"
  protocol                  = "all"
  destination_type          = "CIDR_BLOCK"
  destination               = "0.0.0.0/0"
}

# Public NSG rules (80/443 from your allowlist)
locals {
  public_cidrs = [for r in try(jsondecode(var.ingress_rules_json), []) : r.cidr]
}

resource "oci_core_network_security_group_security_rule" "nsg_public_http" {
  for_each                  = local.public_nsg_id == null ? {} : { for cidr in toset(local.public_cidrs) : cidr => cidr }
  network_security_group_id = local.public_nsg_id
  direction                 = "INGRESS"
  protocol                  = "6" # TCP
  source_type               = "CIDR_BLOCK"
  source                    = each.key
  tcp_options {
    destination_port_range { min = 80, max = 80 }
  }
}

resource "oci_core_network_security_group_security_rule" "nsg_public_https" {
  for_each                  = local.public_nsg_id == null ? {} : { for cidr in toset(local.public_cidrs) : cidr => cidr }
  network_security_group_id = local.public_nsg_id
  direction                 = "INGRESS"
  protocol                  = "6" # TCP
  source_type               = "CIDR_BLOCK"
  source                    = each.key
  tcp_options {
    destination_port_range { min = 443, max = 443 }
  }
}

resource "oci_core_network_security_group_security_rule" "nsg_public_egress_all" {
  for_each                  = local.public_nsg_id == null ? {} : { (local.public_nsg_id) = true }
  network_security_group_id = each.key
  direction                 = "EGRESS"
  protocol                  = "all"
  destination_type          = "CIDR_BLOCK"
  destination               = "0.0.0.0/0"
}

# ---- Free tier guardrails -----------------------------------------
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

# ---- Derive private subnet id (null-safe) --------------------------
locals {
  private_subnet_id = local.vcn_id == null ? null : one(values(oci_core_subnet.private)).id
}

# ---- Instances (gated if VCN missing) ------------------------------
module "nodes" {
  source = "../../modules/instance"
  count  = local.vcn_id == null ? 0 : length(local.node_names)

  name                     = local.node_names[count.index]
  hostname                 = local.node_names[count.index]
  role                     = local.node_roles[count.index]
  availability_domain_name = local.ad_name
  fault_domain             = var.fault_domain

  compartment_ocid = var.compartment_ocid
  subnet_ocid      = count.index == 1 ? local.public_subnet_id : local.private_subnet_id
  image_ocid       = var.image_ocid
  ssh_public_key   = var.ssh_public_key

  assign_public_ip = count.index == 1
  nsg_ids          = count.index == 1 ? [local.internal_nsg_id, local.public_nsg_id] : [local.internal_nsg_id]

  ocpus             = var.ocpus
  memory_gb         = var.memory_gb
  cloud_init_base64 = local.cloud_init_b64
  tags              = var.tags
}
