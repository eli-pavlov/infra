variable "region"                     { type = string, default = "il-jerusalem-1" }
variable "vcn_display_name"           { type = string, default = "vcn-20230527-1933" }
variable "subnet_display_name"        { type = string, default = "subnet-20230527-1933" }
variable "availability_domain_number" { type = number, default = 1 }
variable "fault_domain"               { type = string, default = "FAULT-DOMAIN-3" }

variable "instances" { type = number, default = 4 }
variable "ocpus"     { type = number, default = 1 }
variable "memory_gb" { type = number, default = 6 }

variable "ubuntu_image_display_name" {
  type    = string
  default = "Canonical-Ubuntu-24.04-Minimal-aarch64-2025.05.20-0"
}

variable "cloud_init"  { type = string, default = "" }
variable "name_prefix" { type = string, default = "k3s" }
variable "role"        { type = string, default = "k8s-node" }
variable "tags"        { type = map(string), default = {} }
