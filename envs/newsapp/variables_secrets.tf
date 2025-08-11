variable "tenancy_ocid"    { type = string, sensitive = true }
variable "user_ocid"       { type = string, sensitive = true }
variable "fingerprint"     { type = string, sensitive = true }
variable "private_key_pem" { type = string, sensitive = true }
variable "ssh_public_key"  { type = string, sensitive = true }

variable "region"                     { type = string, default = "il-jerusalem-1" }
variable "vcn_display_name"           { type = string, default = "vcn-20230527-1933" }
variable "subnet_display_name"        { type = string, default = "subnet-20230527-1933" }
variable "availability_domain_number" { type = number, default = 1 }
variable "fault_domain"               { type = string, default = "FAULT-DOMAIN-3" }