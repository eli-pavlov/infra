# OCI auth
variable "tenancy_ocid"     { type = string, sensitive = true }
variable "user_ocid"        { type = string, sensitive = true }
variable "fingerprint"      { type = string, sensitive = true }
variable "private_key_pem"  { type = string, sensitive = true }

# SSH for VM access
variable "ssh_public_key"   { type = string, sensitive = true }

# Placement / network (kept secret per your request)
variable "region"                     { type = string, sensitive = true }
variable "availability_domain_number" { type = number, sensitive = true }
variable "fault_domain"               { type = string, sensitive = true }
variable "vcn_display_name"           { type = string, sensitive = true }
variable "subnet_display_name"        { type = string, sensitive = true }

# Compartments (compute vs network can differ)
variable "compartment_ocid"         { type = string, sensitive = true }
variable "network_compartment_ocid" { type = string, sensitive = true }

# Image
variable "image_ocid"               { type = string, sensitive = true }
