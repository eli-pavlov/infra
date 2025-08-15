terraform {
  required_providers {
    oci = {
      source  = "oracle/oci"
      version = "~> 6.9"
    }
  }
}

# Provider: accept either inline PEM or path
provider "oci" {
  tenancy_ocid = var.tenancy_ocid
  user_ocid    = var.user_ocid
  fingerprint  = var.fingerprint
  region       = var.region

  private_key      = var.private_key_pem != "" ? var.private_key_pem : null
  private_key_path = var.private_key_path != "" ? var.private_key_path : null
}

# -------------------
# Variables
# -------------------
variable "tenancy_ocid" {
  type = string
}

variable "user_ocid" {
  type = string
}

variable "fingerprint" {
  type = string
}

variable "private_key_pem" {
  type    = string
  default = ""
}

variable "private_key_path" {
  type    = string
  default = ""
}

variable "ssh_public_key" {
  type = string
}

variable "region" {
  type = string
}

variable "availability_domain_number" {
  type        = number
  description = "1-based AD number (1..3)"
}

locals {
  ad_index = var.availability_domain_number - 1
  ad_name  = data.oci_identity_availability_domains.ads.availability_domains[local.ad_index].name
}


variable "fault_domain" {
  type = string
}

variable "compartment_ocid" {
  type = string
}

variable "network_compartment_ocid" {
  type    = string
  default = null
}

variable "vcn_display_name" {
  type        = string
  description = "Display name for the VCN."
  default     = "newsapp-vcn"
}

variable "public_subnet_cidr" {
  type    = string
  default = "10.0.0.0/24"
}

variable "private_subnet_cidr" {
  type    = string
  default = "10.0.1.0/24"
}

variable "vcn_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "image_ocid" {
  type = string
}

variable "ingress_rules_json" {
  type        = string
  description = "JSON string describing allowed source CIDRs."
  default     = "[{\"cidr\":\"0.0.0.0/0\"}]"
}

variable "ocpus" {
  type    = number
  default = 1
}

variable "memory_gb" {
  type    = number
  default = 6
}

# -------------------
# Data / Locals
# -------------------
data "oci_identity_availability_domains" "ads" {
  compartment_id = var.tenancy_ocid
}

data "oci_core_services" "all" {
  filter {
    name   = "name"
    values = ["All .* Services In Oracle Services Network"]
    regex  = true
  }
}

locals {
  ad_name         = data.oci_identity_availability_domains.ads.availability_domains[var.availability_domain_number].name
  public_cidrs    = [for r in try(jsondecode(var.ingress_rules_json), []) : r.cidr]
  net_compartment = coalesce(var.network_compartment_ocid, var.compartment_ocid)

  # 4 nodes, all private (best-practice for k8s)
  node_config = {
    cp = {
      role             = "control-plane",
      subnet_id        = oci_core_subnet.private.id,
      nsg_ids          = [oci_core_network_security_group.nsg_internal.id],
      assign_public_ip = false
    }
    worker1 = {
      role             = "worker",
      subnet_id        = oci_core_subnet.private.id,
      nsg_ids          = [oci_core_network_security_group.nsg_internal.id],
      assign_public_ip = false
    }
    worker2 = {
      role             = "worker",
      subnet_id        = oci_core_subnet.private.id,
      nsg_ids          = [oci_core_network_security_group.nsg_internal.id],
      assign_public_ip = false
    }
    worker3 = {
      role             = "worker",
      subnet_id        = oci_core_subnet.private.id,
      nsg_ids          = [oci_core_network_security_group.nsg_internal.id],
      assign_public_ip = false
    }
  }
}

# --- Free tier guards (4 nodes × 1 OCPU, 6 GB each) ---
resource "null_resource" "free_tier_guards" {
  lifecycle {
    precondition {
      condition     = (length(local.node_config) * var.ocpus) <= 4
      error_message = "Exceeds free tier: ocpus=${length(local.node_config) * var.ocpus} (max 4)."
    }
    precondition {
      condition     = (length(local.node_config) * var.memory_gb) <= 24
      error_message = "Exceeds free tier: memory=${length(local.node_config) * var.memory_gb} GB (max 24 GB)."
    }
  }
}

# -------------------
# Network
# -------------------
resource "oci_core_virtual_network" "vcn" {
  cidr_blocks    = [var.vcn_cidr]
  compartment_id = local.net_compartment
  display_name   = var.vcn_display_name
  dns_label      = "newsappvcn"
}

resource "oci_core_internet_gateway" "igw" {
  compartment_id = local.net_compartment
  display_name   = "newsapp-igw"
  enabled        = true
  vcn_id         = oci_core_virtual_network.vcn.id
}

resource "oci_core_nat_gateway" "nat" {
  compartment_id = local.net_compartment
  display_name   = "newsapp-nat"
  vcn_id         = oci_core_virtual_network.vcn.id
}

resource "oci_core_service_gateway" "sgw" {
  compartment_id = local.net_compartment
  vcn_id         = oci_core_virtual_network.vcn.id
  display_name   = "newsapp-sgw"
  services {
    service_id = data.oci_core_services.all.services[0].id
  }
}

resource "oci_core_route_table" "public_rt" {
  compartment_id = local.net_compartment
  vcn_id         = oci_core_virtual_network.vcn.id
  display_name   = "newsapp-public-rt"
  route_rules {
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_internet_gateway.igw.id
  }
}

resource "oci_core_route_table" "private_rt" {
  compartment_id = local.net_compartment
  vcn_id         = oci_core_virtual_network.vcn.id
  display_name   = "newsapp-private-rt"

  route_rules {
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_nat_gateway.nat.id
  }

  route_rules {
    destination       = data.oci_core_services.all.services[0].cidr_block
    destination_type  = "SERVICE_CIDR_BLOCK"
    network_entity_id = oci_core_service_gateway.sgw.id
  }
}

resource "oci_core_subnet" "public" {
  cidr_block                 = var.public_subnet_cidr
  compartment_id             = local.net_compartment
  display_name               = "newsapp-public-subnet"
  dns_label                  = "newsapppub"
  prohibit_public_ip_on_vnic = false
  route_table_id             = oci_core_route_table.public_rt.id
  vcn_id                     = oci_core_virtual_network.vcn.id
}

resource "oci_core_subnet" "private" {
  cidr_block                 = var.private_subnet_cidr
  compartment_id             = local.net_compartment
  display_name               = "newsapp-private-subnet"
  dns_label                  = "newsapppriv"
  prohibit_public_ip_on_vnic = true
  route_table_id             = oci_core_route_table.private_rt.id
  vcn_id                     = oci_core_virtual_network.vcn.id
}

# NSGs
resource "oci_core_network_security_group" "nsg_public_www" {
  compartment_id = local.net_compartment
  vcn_id         = oci_core_virtual_network.vcn.id
  display_name   = "nsg-public-www"
}

resource "oci_core_network_security_group" "nsg_internal" {
  compartment_id = local.net_compartment
  vcn_id         = oci_core_virtual_network.vcn.id
  display_name   = "nsg-k8s-internal"
}

# NSG rules
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
  destination               = "0.0.0.0/0"
}

resource "oci_core_network_security_group_security_rule" "nsg_public_egress_all" {
  network_security_group_id = oci_core_network_security_group.nsg_public_www.id
  direction                 = "EGRESS"
  protocol                  = "all"
  destination               = "0.0.0.0/0"
}

# HTTP
resource "oci_core_network_security_group_security_rule" "nsg_public_http" {
  for_each                  = toset(local.public_cidrs)
  network_security_group_id = oci_core_network_security_group.nsg_public_www.id
  direction                 = "INGRESS"
  protocol                  = "6"
  source                    = each.value
  tcp_options {
    destination_port_range {
      min = 80
      max = 80
    }
  }
}

# HTTPS
resource "oci_core_network_security_group_security_rule" "nsg_public_https" {
  for_each                  = toset(local.public_cidrs)
  network_security_group_id = oci_core_network_security_group.nsg_public_www.id
  direction                 = "INGRESS"
  protocol                  = "6"
  source                    = each.value
  tcp_options {
    destination_port_range {
      min = 443
      max = 443
    }
  }
}

# -------------------
# Compute (4 nodes)
# -------------------
module "nodes" {
  source = "../../modules/instance"
  for_each = local.node_config

  name                     = each.key
  hostname                 = each.key
  role                     = each.value.role
  availability_domain_name = local.ad_name
  fault_domain             = var.fault_domain

  compartment_ocid = var.compartment_ocid
  subnet_ocid      = each.value.subnet_id
  image_ocid       = var.image_ocid
  ssh_public_key   = var.ssh_public_key

  assign_public_ip = each.value.assign_public_ip
  nsg_ids          = each.value.nsg_ids

  ocpus     = var.ocpus
  memory_gb = var.memory_gb
}