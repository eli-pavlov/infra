variable "tenancy_ocid"     { type = string, sensitive = true }
variable "user_ocid"        { type = string, sensitive = true }
variable "fingerprint"      { type = string, sensitive = true }
variable "private_key_pem"  { type = string, sensitive = true }

variable "ssh_public_key"   { type = string, sensitive = true }

variable "region"                     { type = string, sensitive = true }
variable "availability_domain_number" { type = number, sensitive = true }
variable "fault_domain"               { type = string, sensitive = true }

variable "vcn_display_name"           { type = string, sensitive = true }
variable "subnet_display_name"        { type = string, sensitive = true }

variable "compartment_ocid"           { type = string, sensitive = true } # compute
variable "network_compartment_ocid"   { type = string, sensitive = true } # where VCN/subnet live

variable "image_ocid"                 { type = string, sensitive = true }

# Security-list rules as JSON secrets (kept out of repo)
variable "ingress_rules_json"         { type = string, sensitive = true }
variable "egress_rules_json"          { type = string, sensitive = true }
