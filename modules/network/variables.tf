variable "compartment_ocid" {
  type = string
}

variable "region" {
  type = string
}

# Base addressing for the VCN (can be overridden per env)
variable "vcn_cidr" {
  type    = string
  default = "10.20.0.0/16"
}

# Prefix used in display names for all network resources
variable "display_name_prefix" {
  type    = string
  default = "newsapp"
}

# When true, appends a short random suffix to resource display names
variable "randomize_names" {
  type    = bool
  default = true
}

# Public ingress allow-list for NSG "nsg-public-www"
# Tighten to corporate IPs when possible (e.g., ["203.0.113.10/32"])
variable "allowed_cidrs" {
  type    = list(string)
  default = ["0.0.0.0/0"]
}

# TCP ports to allow from allowed_cidrs on the public NSG
variable "public_ingress_ports" {
  type    = list(number)
  default = [80, 443]
}

# Optional explicit VCN display name; if empty, computed from prefix + suffix
variable "vcn_display_name" {
  type    = string
  default = ""
}

# DNS label for the VCN (must be unique in tenancy/region; lowercase alnum)
variable "dns_label" {
  type    = string
  default = "newsapp"
}

# Freeform tags applied to all resources created by this module
variable "freeform_tags" {
  type    = map(string)
  default = {}
}
