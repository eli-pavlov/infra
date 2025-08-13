#########################
# Non-secret variables  #
#########################

# Display names (used to find-or-create VCN/subnets)
variable "vcn_display_name" {
  type        = string
  description = "Display name of the VCN to reuse or create."
}

variable "subnet_display_name" {
  type        = string
  description = "Display name of the PUBLIC subnet to reuse or create."
}

# CIDRs for new deployments (ignored if reusing existing)
variable "vcn_cidr" {
  type        = string
  description = "VCN IPv4 CIDR when creating a new VCN."
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
  type        = string
  description = "Public subnet CIDR when creating a new public subnet."
  default     = "10.0.0.0/24"
}

variable "private_subnet_cidr" {
  type        = string
  description = "Private subnet CIDR (egress via NAT)."
  default     = "10.0.1.0/24"
}

# Node sizing / metadata
variable "ocpus" {
  type        = number
  description = "OCPUs per node."
  default     = 1
}

variable "memory_gb" {
  type        = number
  description = "Memory (GB) per node."
  default     = 6
}

variable "cloud_init" {
  type        = string
  description = "Optional cloud-init user data (plain text)."
  default     = ""
}

variable "tags" {
  type        = map(string)
  description = "Freeform tags for created resources."
  default     = {}
}

# Allowed CIDRs for public HTTP/HTTPS on node-1
# Example: '[{"cidr":"84.110.50.0/24"},{"cidr":"87.68.165.0/24"}]'
variable "ingress_rules_json" {
  type        = string
  description = "JSON list of CIDRs allowed to reach ports 80/443 on node-1."
  default     = "[]"
}

variable "ocpus" {
  type    = number
  default = 1
}

variable "memory_gb" {
  type    = number
  default = 6
}

variable "cloud_init" {
  type    = string
  default = ""
}

variable "tags" {
  type    = map(string)
  default = {}
}
