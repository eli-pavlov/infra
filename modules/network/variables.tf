variable "compartment_ocid" { type = string }
variable "region"           { type = string }

# Base addressing. You can override these per env if needed.
variable "vcn_cidr" {
  type    = string
  default = "10.20.0.0/16"
}

variable "display_name_prefix" {
  type    = string
  default = "newsapp"
}

# Allow auto-suffixing names for uniqueness
variable "randomize_names" {
  type    = bool
  default = true
}

# Public ingress allow-list. Keep tight by default.
variable "allowed_cidrs" {
  type    = list(string)
  default = ["0.0.0.0/0"] # tighten to corp IP(s) if possible
}

# Which TCP ports to allow on the public NSG
variable "public_ingress_ports" {
  type    = list(number)
  default = [80, 443]
}

# Optional explicit names (else computed)
variable "vcn_display_name"   { type = string, default = "" }
variable "dns_label"          { type = string, default = "newsapp" }

# Tags
variable "freeform_tags" {
  type    = map(string)
  default = {}
}
