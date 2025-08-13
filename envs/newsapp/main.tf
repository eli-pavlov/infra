locals {
  node_names = ["master", "node-1", "node-2", "node-3"]
  node_roles = ["control-plane", "frontend", "worker", "worker"]

  instances_count = length(local.node_names)
  total_ocpus     = local.instances_count * var.ocpus
  total_mem       = local.instances_count * var.memory_gb
}

data "oci_identity_availability_domains" "ads" {
  compartment_id = var.tenancy_ocid
}

locals {
  ads_names  = [for ad in try(data.oci_identity_availability_domains.ads.availability_domains, []) : ad.name]
  ad_index   = var.availability_domain_number - 1
  # Guarded lookup: if out-of-range, produce empty string; validation below will fail with a clear message
  ad_name    = (local.ad_index >= 0 && local.ad_index < length(local.ads_names)) ? local.ads_names[local.ad_index] : ""
  cloud_init_b64 = var.cloud_init == "" ? "" : base64encode(var.cloud_init)
}

resource "null_resource" "validate_ad" {
  lifecycle {
    precondition {
      condition     = length(local.ads_names) > 0 && local.ad_index >= 0 && local.ad_index < length(local.ads_names)
      error_message = "Invalid availability_domain_number=${var.availability_domain_number}. Found ${length(local.ads_names)} ADs; valid range is 1..${length(local.ads_names)}."
    }
  }
}

# --- VCN (find by display_name, null-safe) ---
data "oci_core_vcns" "vcns" {
  compartment_id = var.network_compartment_ocid
}

locals {
  vcns_all  = try(data.oci_core_vcns.vcns.virtual_networks, [])
  vcn_match = [for v in local.vcns_all : v if v.display_name == var.vcn_display_name]
  vcn_id    = (length(local.vcn_match) == 1) ? local.vcn_match[0].id : null
}


resource "null_resource" "validate_vcn" {
  lifecycle {
    precondition {
      condition     = length(local.vcn_match) == 1
      error_message = "VCN '${var.vcn_display_name}' not found (or not unique) in compartment '${var.network_compartment_ocid}'."
    }
  }
}

# --- PUBLIC subnet (find by display_name within that VCN), null-safe ---
data "oci_core_subnets" "subnets" {
  compartment_id = var.network_compartment_ocid
  vcn_id         = local.vcn_id
}

locals {
  subnets_all         = try(data.oci_core_subnets.subnets.subnets, [])
  public_subnet_match = [for s in local.subnets_all : s if s.display_name == var.subnet_display_name]
  public_subnet_id    = (length(local.public_subnet_match) == 1) ? local.public_subnet_match[0].id : null
}


resource "null_resource" "validate_public_subnet" {
  lifecycle {
    precondition {
      condition     = length(local.public_subnet_match) == 1
      error_message = "Subnet '${var.subnet_display_name}' not found (or not unique) in VCN '${var.vcn_display_name}'."
    }
  }
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
  nsg_ids          = count.index == 1 ? [
    oci_core_network_security_group.nsg_internal.id,
    oci_core_network_security_group.nsg_public_www.id
  ] : [
    oci_core_network_security_group.nsg_internal.id
  ]


  ocpus             = var.ocpus
  memory_gb         = var.memory_gb
  cloud_init_base64 = local.cloud_init_b64
  tags              = var.tags
}
