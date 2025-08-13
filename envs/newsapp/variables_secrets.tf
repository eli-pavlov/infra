# ---- OCI auth ----
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
variable "ssh_public_key" {
  type      = string
  sensitive = true
}

# ---- placement ----
variable "availability_domain_number" {
  type      = number
  sensitive = true
}
variable "fault_domain" {
  type      = string
  sensitive = true
}

# ---- network selection ----
variable "vcn_display_name" {
  type      = string
  sensitive = true
}
variable "subnet_display_name" {
  type      = string
  sensitive = true
}

# ---- compartments ----
variable "compartment_ocid" {
  type      = string
  sensitive = true
}
variable "network_compartment_ocid" {
  type      = string
  sensitive = true
}

# ---- image ----
variable "image_ocid" {
  type      = string
  sensitive = true
}

# ---- public ingress allowlist (CIDRs) as JSON ----
variable "ingress_rules_json" {
  type      = string
  sensitive = true
}

variable "private_key_path" {
  type      = string
  sensitive = true
}
