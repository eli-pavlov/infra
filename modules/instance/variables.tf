variable "name"                     { type = string }
variable "hostname"                 { type = string }
variable "role"                     { type = string }
variable "availability_domain_name" { type = string }
variable "fault_domain"             { type = string }
variable "compartment_ocid"         { type = string }
variable "subnet_ocid"              { type = string }
variable "image_ocid"               { type = string }
variable "ssh_public_key"           { type = string }
variable "ocpus"                    { type = number }
variable "memory_gb"                { type = number }
variable "cloud_init_base64"        { type = string, default = "" }
variable "tags"                     { type = map(string), default = {} }
