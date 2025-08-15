variable "tenancy_ocid"   { type = string }
variable "user_ocid"      { type = string }
variable "fingerprint"    { type = string }
variable "private_key_pem"{ type = string }
variable "private_key_path" { type = string, default = "" } # either pem or path
variable "region"         { type = string }

variable "compartment_ocid"         { type = string } # MUST deploy here
variable "network_compartment_ocid" { type = string, default = null } # fallback to compartment_ocid
variable "availability_domain_number" { type = number }
variable "fault_domain" { type = string }

variable "image_ocid"    { type = string }
variable "ssh_public_key"{ type = string }

# Node shape sizing
variable "ocpus"     { type = number, default = 1 }
variable "memory_gb" { type = number, default = 6 }

# Public access defaults: allow 22/80/443 from world (tighten as needed)
variable "allowed_cidrs" {
  type    = list(string)
  default = ["0.0.0.0/0"]
}
variable "public_ingress_ports" {
  type    = list(number)
  default = [22, 80, 443]
}

# Whether nodes get public IPs (default off for k8s-ready private nodes)
variable "assign_public_ip" {
  type    = bool
  default = false
}
