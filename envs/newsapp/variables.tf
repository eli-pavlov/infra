#########################
# Non-secret variables  #
#########################

# Find-or-create by display name
variable "vcn_display_name" {
  type        = string
  description = "Display name of the VCN to reuse or create."
}
variable "subnet_display_name" {
  type        = string
  description = "Display name of the PUBLIC subnet to reuse or create."
}

# CIDRs for new deployments (used only if creating)
variable "vcn_cidr" {
  type        = string
  default     = "10.0.0.0/16"
  description = "VCN IPv4 CIDR when creating a new VCN."
}
variable "public_subnet_cidr" {
  type        = string
  default     = "10.0.0.0/24"
  description = "Public subnet CIDR when creating a new public subnet."
}
variable "private_subnet_cidr" {
  type        = string
  default     = "10.0.1.0/24"
  description = "Private subnet CIDR (egress via NAT)."
}

# Nodes
variable "ocpus" {
  type        = number
  default     = 1
  description = "OCPUs per node."
}
variable "memory_gb" {
  type        = number
  default     = 6
  description = "Memory (GB) per node."
}
variable "cloud_init" {
  type        = string
  default     = ""
  description = "Optional cloud-init user data (plain text)."
}
variable "tags" {
  type        = map(string)
  default     = {}
  description = "Freeform tags to apply to created resources."
}

# Allowed CIDRs for public 80/443 on node-1
# Example: '[{"cidr":"84.110.50.0/24"},{"cidr":"87.68.165.0/24"}]'
variable "ingress_rules_json" {
  type        = string
  default     = "[]"
  description = "JSON list of CIDRs allowed to reach ports 80/443 on node-1."
}

#######################
# Sensitive variables #
#######################

variable "tenancy_ocid" {
  type      = string
  sensitive = true
}

variable "user_ocid" {
  type      = string
  sensitive = true
}

variable "fingerprint" {
  type      = string
  sensitive = true
}

variable "private_key_pem" {
  type      = string
  sensitive = true
}

variable "region" {
  type      = string
  sensitive = true
}

variable "compartment_ocid" {
  type      = string
  sensitive = true
}

variable "network_compartment_ocid" {
  type      = string
  sensitive = true
}

variable "availability_domain_number" {
  type      = number
  sensitive = true
}

variable "fault_domain" {
  type      = string
  sensitive = true
}

variable "image_ocid" {
  type      = string
  sensitive = true
}

variable "ssh_public_key" {
  type      = string
  sensitive = true
}

# Optional absolute path to PEM on runner; if set, the provider ignores private_key_pem
variable "private_key_path" {
  type        = string
  default     = null
  sensitive   = true
  description = "Absolute path to OCI API key PEM file on the runner; leave null to use private_key_pem."
}

terraform {
  required_version = ">= 1.12.0"
}