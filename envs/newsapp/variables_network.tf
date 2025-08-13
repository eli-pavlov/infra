variable "vcn_cidr" {
  type        = string
  description = "VCN IPv4 CIDR for new deployments."
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
  type        = string
  description = "Public subnet CIDR (used if public subnet is created)."
  default     = "10.0.0.0/24"
}

# Already used earlier, but include here if you don’t have it yet:
variable "private_subnet_cidr" {
  type        = string
  description = "Private subnet CIDR (egress via NAT)."
  default     = "10.0.1.0/24"
}
