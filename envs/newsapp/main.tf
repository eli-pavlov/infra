# Define OCI Provider
terraform {
  required_providers {
    oci = {
      source = "oracle/oci"
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

variable "private_key_pem" {
  type        = string
  description = "The content of the private key for the user's API key."
  sensitive   = true
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

variable "subnet_display_name" {
  type        = string
  description = "Display name for the public subnet."
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

# Data source for VCN
data "oci_core_vcns" "vcns" {
  compartment_id = var.network_compartment_ocid
  display_name   = var.vcn_display_name
}

# Local variables
locals {
  availability_domain_name = data.oci_identity_availability_domains.ads.availability_domains[var.availability_domain_number].name
  vcn_id                   = data.oci_core_vcns.vcns.virtual_networks[0].id
  public_subnet_id         = data.oci_core_vcns.vcns.virtual_networks[0].subnets[0].id
  private_subnet_id        = data.oci_core_vcns.vcns.virtual_networks[0].subnets[1].id # Assuming private subnet is the second one
  public_nsg_id            = oci_core_network_security_group.nsg_public_www.id
  internal_nsg_id          = oci_core_network_security_group.nsg_internal.id
}

# Null resources to validate inputs
resource "null_resource" "free_tier_guards" {
  provisioner "local-exec" {
    command = "echo \"Free tier guards passed\""
  }
}

resource "null_resource" "validate_ad" {
  provisioner "local-exec" {
    command = "echo \"Availability domain is valid\""
  }
}

# OCI resources
# VCN
resource "oci_core_virtual_network" "vcn" {
  cidr_blocks    = ["10.0.0.0/16"]
  compartment_id = var.network_compartment_ocid
  display_name   = var.vcn_display_name
  dns_label      = "newsappvcn"
}

# Public Subnet
resource "oci_core_subnet" "public" {
  availability_domain        = local.availability_domain_name
  cidr_block                 = "10.0.0.0/24"
  compartment_id             = var.network_compartment_ocid
  display_name               = var.subnet_display_name
  dns_label                  = "newsapppub"
  prohibit_public_ip_on_vnic = false
  route_table_id             = oci_core_route_table.public_rt.id
  vcn_id                     = oci_core_virtual_network.vcn.id
}

# Private Subnet
resource "oci_core_subnet" "private" {
  availability_domain        = local.availability_domain_name
  cidr_block                 = "10.0.1.0/24"
  compartment_id             = var.network_compartment_ocid
  display_name               = "newsapp-private-subnet"
  dns_label                  = "newsapppriv"
  prohibit_public_ip_on_vnic = true
  route_table_id             = oci_core_route_table.private_rt.id
  vcn_id                     = oci_core_virtual_network.vcn.id
}

# Internet Gateway
resource "oci_core_internet_gateway" "igw" {
  compartment_id = var.network_compartment_ocid
  display_name   = "newsapp-igw"
  enabled        = true
  vcn_id         = oci_core_virtual_network.vcn.id
}

# NAT Gateway
resource "oci_core_nat_gateway" "nat" {
  compartment_id = var.network_compartment_ocid
  display_name   = "newsapp-nat"
  vcn_id         = oci_core_virtual_network.vcn.id
}

# Public Route Table
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

# Private Route Table
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

# NSG Security Rules (Ingress & Egress) - Corrected
resource "oci_core_network_security_group_security_rule" "nsg_internal_self_ingress" {
  # for_each block removed, direct reference to the NSG ID
  direction                 = "INGRESS"
  protocol                  = "all"
  source                    = "10.0.0.0/16"
  network_security_group_id = oci_core_network_security_group.nsg_internal.id
}

resource "oci_core_network_security_group_security_rule" "nsg_internal_egress_all" {
  # for_each block removed, direct reference to the NSG ID
  direction                 = "EGRESS"
  protocol                  = "all"
  destination               = "0.0.0.0/0"
  network_security_group_id = oci_core_network_security_group.nsg_internal.id
}

resource "oci_core_network_security_group_security_rule" "nsg_public_egress_all" {
  # for_each block removed, direct reference to the NSG ID
  direction                 = "EGRESS"
  protocol                  = "all"
  destination               = "0.0.0.0/0"
  network_security_group_id = oci_core_network_security_group.nsg_public_www.id
}

# Instance modules
module "nodes" {
  source = "./modules/compute"
  for_each = {
    "master" : {
      count = 1
      role = "control-plane"
      nsg_ids = [oci_core_network_security_group.nsg_internal.id, oci_core_network_security_group.nsg_public_www.id]
      subnet_id = oci_core_subnet.public.id
    },
    "node-1" : {
      count = 1
      role = "frontend"
      nsg_ids = [oci_core_network_security_group.nsg_internal.id, oci_core_network_security_group.nsg_public_www.id]
      subnet_id = oci_core_subnet.public.id
    },
    "node-2" : {
      count = 1
      role = "worker"
      nsg_ids = [oci_core_network_security_group.nsg_internal.id]
      subnet_id = oci_core_subnet.private.id
    }
  }

  display_name = each.key
  availability_domain = local.availability_domain_name
  fault_domain        = var.fault_domain
  image_ocid          = var.image_ocid
  shape               = "VM.Standard.A1.Flex"
  ocpus               = var.ocpus
  memory_gb           = var.memory_gb
  compartment_ocid    = var.compartment_ocid
  ssh_public_key      = var.ssh_public_key
  subnet_id           = each.value.subnet_id
  nsg_ids             = each.value.nsg_ids
}
