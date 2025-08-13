# Define OCI Provider
terraform {
  required_providers {
    oci = {
      source  = "oracle/oci"
      version = "4.120.0"
    }
  }
}

# Provider configuration
provider "oci" {
  tenancy_ocid     = var.tenancy_ocid
  user_ocid        = var.user_ocid
  fingerprint      = var.fingerprint
  private_key_path = var.private_key_path
  region           = var.region
}

# OCI Variable Declarations
variable "tenancy_ocid" {
  type        = string
  description = "The tenancy OCID for your OCI account."
}

variable "user_ocid" {
  type        = string
  description = "The user OCID for your OCI API key."
}

variable "fingerprint" {
  type        = string
  description = "The fingerprint of the user's API key."
}

variable "private_key_path" {
  type        = string
  description = "The path to the private key file."
}

variable "ssh_public_key" {
  type        = string
  description = "Public key for SSH access."
}

variable "region" {
  type        = string
  description = "The region to create resources in."
}

variable "availability_domain_number" {
  type        = number
  description = "The availability domain number."
}

variable "fault_domain" {
  type        = string
  description = "The fault domain to use for the instance."
}

variable "compartment_ocid" {
  type        = string
  description = "The compartment OCID for the resources."
}

variable "network_compartment_ocid" {
  type        = string
  description = "The compartment OCID for network resources."
}

variable "vcn_display_name" {
  type        = string
  description = "Display name for the VCN."
}

variable "public_subnet_cidr" {
  type        = string
  description = "CIDR for the public subnet."
  default     = "10.0.0.0/24"
}

variable "private_subnet_cidr" {
  type        = string
  description = "CIDR for the private subnet."
  default     = "10.0.1.0/24"
}

variable "vcn_cidr" {
  type        = string
  description = "CIDR for the VCN."
  default     = "10.0.0.0/16"
}

variable "image_ocid" {
  type        = string
  description = "OCID of the image to use for the instance."
}

variable "ingress_rules_json" {
  type        = string
  description = "JSON string of ingress rules for the NSG."
}

variable "ocpus" {
  type        = number
  description = "Number of OCPUs for the instance."
}

variable "memory_gb" {
  type        = number
  description = "Amount of memory in GB for the instance."
}

# Data source for availability domains
data "oci_identity_availability_domains" "ads" {
  compartment_id = var.tenancy_ocid
}

# Local variables
locals {
  availability_domain_name = data.oci_identity_availability_domains.ads.availability_domains[var.availability_domain_number].name
  public_cidrs             = [for r in try(jsondecode(var.ingress_rules_json), []) : r.cidr]
  node_config = {
    master = {
      role      = "control-plane"
      subnet_id = oci_core_subnet.public.id
      nsg_ids   = [oci_core_network_security_group.nsg_internal.id, oci_core_network_security_group.nsg_public_www.id]
      assign_public_ip = true
    }
    node_1 = {
      role      = "frontend"
      subnet_id = oci_core_subnet.public.id
      nsg_ids   = [oci_core_network_security_group.nsg_internal.id, oci_core_network_security_group.nsg_public_www.id]
      assign_public_ip = true
    }
    node_2 = {
      role      = "worker"
      subnet_id = oci_core_subnet.private.id
      nsg_ids   = [oci_core_network_security_group.nsg_internal.id]
      assign_public_ip = false
    }
  }
}

# --- Free tier guards ---
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

# OCI Network resources
resource "oci_core_virtual_network" "vcn" {
  cidr_blocks    = [var.vcn_cidr]
  compartment_id = var.network_compartment_ocid
  display_name   = var.vcn_display_name
  dns_label      = "newsappvcn"
}

resource "oci_core_internet_gateway" "igw" {
  compartment_id = var.network_compartment_ocid
  display_name   = "newsapp-igw"
  enabled        = true
  vcn_id         = oci_core_virtual_network.vcn.id
}

resource "oci_core_nat_gateway" "nat" {
  compartment_id = var.network_compartment_ocid
  display_name   = "newsapp-nat"
  vcn_id         = oci_core_virtual_network.vcn.id
}

resource "oci_core_route_table" "public_rt" {
  compartment_id = var.network_compartment_ocid
  vcn_id         = oci_core_virtual_network.vcn.id
  display_name   = "newsapp-public-rt"
  route_rules {
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_internet_gateway.igw.id
  }
}

resource "oci_core_route_table" "private_rt" {
  compartment_id = var.network_compartment_ocid
  vcn_id         = oci_core_virtual_network.vcn.id
  display_name   = "newsapp-private-rt"
  route_rules {
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_nat_gateway.nat.id
  }
}

resource "oci_core_subnet" "public" {
  availability_domain        = local.availability_domain_name
  cidr_block                 = var.public_subnet_cidr
  compartment_id             = var.network_compartment_ocid
  display_name               = "newsapp-public-subnet"
  dns_label                  = "newsapppub"
  prohibit_public_ip_on_vnic = false
  route_table_id             = oci_core_route_table.public_rt.id
  vcn_id                     = oci_core_virtual_network.vcn.id
}

resource "oci_core_subnet" "private" {
  availability_domain        = local.availability_domain_name
  cidr_block                 = var.private_subnet_cidr
  compartment_id             = var.network_compartment_ocid
  display_name               = "newsapp-private-subnet"
  dns_label                  = "newsapppriv"
  prohibit_public_ip_on_vnic = true
  route_table_id             = oci_core_route_table.private_rt.id
  vcn_id                     = oci_core_virtual_network.vcn.id
}

# NSGs
resource "oci_core_network_security_group" "nsg_public_www" {
  compartment_id = var.network_compartment_ocid
  vcn_id         = oci_core_virtual_network.vcn.id
  display_name   = "nsg-public-www"
}

resource "oci_core_network_security_group" "nsg_internal" {
  compartment_id = var.network_compartment_ocid
  vcn_id         = oci_core_virtual_network.vcn.id
  display_name   = "nsg-k8s-internal"
}

# NSG Security Rules
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

resource "oci_core_network_security_group_security_rule" "nsg_public_http_https" {
  for_each                  = toset(local.public_cidrs)
  network_security_group_id = oci_core_network_security_group.nsg_public_www.id
  direction                 = "INGRESS"
  protocol                  = "6" # TCP
  source                    = each.value
  tcp_options {
    destination_port_range {
      min = 80
      max = 80
    }
  }
}

# OCI Compute Instances module call
module "nodes" {
  source = "../modules/instance"
  for_each = local.node_config

  name                     = each.key
  hostname                 = each.key
  role                     = each.value.role
  availability_domain_name = local.availability_domain_name
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
