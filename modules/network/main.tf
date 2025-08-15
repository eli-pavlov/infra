terraform {
  required_providers {
    oci = {
      source  = "oracle/oci"
      version = "~> 6.9"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

# Do NOT declare provider "oci" {} here (deprecated proxy provider).
# The root module will supply the provider configuration.

resource "random_string" "suffix" {
  length  = 5
  upper   = false
  lower   = true
  numeric = true
  special = false
}

data "oci_core_services" "all" {
  # Match "All <something> Services In Oracle Services Network"
  filter {
    name   = "name"
    values = ["All .* Services In Oracle Services Network"]
    regex  = true
  }
}

locals {
  suffix = var.randomize_names ? "-${random_string.suffix.result}" : ""
  name   = length(var.vcn_display_name) > 0 ? var.vcn_display_name : "${var.display_name_prefix}-vcn${local.suffix}"

  # Base addressing: carve the /16 VCN into four /20s for public & private tiers
  cidr_vcn         = var.vcn_cidr
  cidr_public_web  = cidrsubnet(local.cidr_vcn, 4, 0) # /20
  cidr_private_app = cidrsubnet(local.cidr_vcn, 4, 1) # /20 (k8s workers)
  cidr_private_ops = cidrsubnet(local.cidr_vcn, 4, 2) # /20 (bastion/tooling)
  cidr_private_db  = cidrsubnet(local.cidr_vcn, 4, 3) # /20 (DB/services)

  tags = merge({ "managed-by" = "terraform" }, var.freeform_tags)

  # Cross-product of allowed_cidrs × public_ingress_ports for NSG rules
  public_ingress_matrix = {
    for item in flatten([
      for cidr in var.allowed_cidrs : [
        for p in var.public_ingress_ports : {
          key  = "${cidr}-${p}"
          cidr = cidr
          port = p
        }
      ]
    ]) : item.key => { cidr = item.cidr, port = item.port }
  }
}

# -------------------------
# Core network primitives
# -------------------------
resource "oci_core_virtual_network" "vcn" {
  compartment_id = var.compartment_ocid
  display_name   = local.name
  cidr_blocks    = [local.cidr_vcn]
  dns_label      = var.dns_label
  freeform_tags  = local.tags
}

resource "oci_core_internet_gateway" "igw" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_virtual_network.vcn.id
  display_name   = "${var.display_name_prefix}-igw${local.suffix}"
  is_enabled     = true
  freeform_tags  = local.tags
}

resource "oci_core_nat_gateway" "nat" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_virtual_network.vcn.id
  display_name   = "${var.display_name_prefix}-nat${local.suffix}"
  freeform_tags  = local.tags
}

resource "oci_core_service_gateway" "sgw" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_virtual_network.vcn.id
  display_name   = "${var.display_name_prefix}-sgw${local.suffix}"

  services {
    service_id = data.oci_core_services.all.services[0].id
  }

  freeform_tags = local.tags
}

# -------------------------
# Route tables
# -------------------------
resource "oci_core_route_table" "rt_public" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_virtual_network.vcn.id
  display_name   = "${var.display_name_prefix}-rt-public${local.suffix}"
  freeform_tags  = local.tags

  route_rules {
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_internet_gateway.igw.id
  }
}

resource "oci_core_route_table" "rt_private" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_virtual_network.vcn.id
  display_name   = "${var.display_name_prefix}-rt-private${local.suffix}"
  freeform_tags  = local.tags

  route_rules {
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_nat_gateway.nat.id
    description       = "Private egress via NAT"
  }
}

resource "oci_core_route_table" "rt_svc" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_virtual_network.vcn.id
  display_name   = "${var.display_name_prefix}-rt-svc${local.suffix}"
  freeform_tags  = local.tags

  route_rules {
    destination       = data.oci_core_services.all.services[0].cidr_block
    destination_type  = "SERVICE_CIDR_BLOCK"
    network_entity_id = oci_core_service_gateway.sgw.id
    description       = "Private access to OCI Services via Service Gateway"
  }
}

# -------------------------
# NSGs
# -------------------------
resource "oci_core_network_security_group" "nsg_public" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_virtual_network.vcn.id
  display_name   = "nsg-public-www${local.suffix}"
  freeform_tags  = local.tags
}

resource "oci_core_network_security_group" "nsg_internal" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_virtual_network.vcn.id
  display_name   = "nsg-internal${local.suffix}"
  freeform_tags  = local.tags
}

# Internal: allow all within internal NSG
resource "oci_core_network_security_group_security_rule" "internal_ingress_self" {
  network_security_group_id = oci_core_network_security_group.nsg_internal.id
  direction                 = "INGRESS"
  protocol                  = "all"
  source_type               = "NETWORK_SECURITY_GROUP"
  source                    = oci_core_network_security_group.nsg_internal.id
}

resource "oci_core_network_security_group_security_rule" "internal_egress_all" {
  network_security_group_id = oci_core_network_security_group.nsg_internal.id
  direction                 = "EGRESS"
  protocol                  = "all"
  destination               = "0.0.0.0/0"
}

# Public NSG: ingress for each (cidr, port)
resource "oci_core_network_security_group_security_rule" "public_ingress" {
  for_each                  = local.public_ingress_matrix
  network_security_group_id = oci_core_network_security_group.nsg_public.id
  direction                 = "INGRESS"
  protocol                  = "6" # TCP
  source                    = each.value.cidr
  stateless                 = false

  tcp_options {
    destination_port_range {
      min = each.value.port
      max = each.value.port
    }
  }
}

resource "oci_core_network_security_group_security_rule" "public_egress_all" {
  network_security_group_id = oci_core_network_security_group.nsg_public.id
  direction                 = "EGRESS"
  protocol                  = "all"
  destination               = "0.0.0.0/0"
}

# -------------------------
# Subnets
# -------------------------
resource "oci_core_subnet" "public_web" {
  compartment_id             = var.compartment_ocid
  vcn_id                     = oci_core_virtual_network.vcn.id
  display_name               = "public-web${local.suffix}"
  cidr_block                 = local.cidr_public_web
  prohibit_public_ip_on_vnic = false
  dns_label                  = "pubweb"
  route_table_id             = oci_core_route_table.rt_public.id
  freeform_tags              = local.tags
}

resource "oci_core_subnet" "private_app" {
  compartment_id             = var.compartment_ocid
  vcn_id                     = oci_core_virtual_network.vcn.id
  display_name               = "private-app${local.suffix}"
  cidr_block                 = local.cidr_private_app
  prohibit_public_ip_on_vnic = true
  dns_label                  = "app"
  route_table_id             = oci_core_route_table.rt_private.id
  freeform_tags              = local.tags
}

resource "oci_core_subnet" "private_ops" {
  compartment_id             = var.compartment_ocid
  vcn_id                     = oci_core_virtual_network.vcn.id
  display_name               = "private-ops${local.suffix}"
  cidr_block                 = local.cidr_private_ops
  prohibit_public_ip_on_vnic = true
  dns_label                  = "ops"
  route_table_id             = oci_core_route_table.rt_private.id
  freeform_tags              = local.tags
}

resource "oci_core_subnet" "private_db" {
  compartment_id             = var.compartment_ocid
  vcn_id                     = oci_core_virtual_network.vcn.id
  display_name               = "private-db${local.suffix}"
  cidr_block                 = local.cidr_private_db
  prohibit_public_ip_on_vnic = true
  dns_label                  = "db"
  route_table_id             = oci_core_route_table.rt_svc.id
  freeform_tags              = local.tags
}
