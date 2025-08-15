variable "tenancy_ocid" {
  type = string
}

variable "user_ocid" {
  type = string
}

variable "fingerprint" {
  type = string
}

# Option A: inline PEM (preferred in CI)
variable "private_key_pem" {
  type    = string
  default = ""
  sensitive = true
}

# Option B: path to PEM file on disk
variable "private_key_path" {
  type    = string
  default = ""
}

variable "region" {
  type = string
}

variable "compartment_ocid" {
  type = string
}

# If null, we’ll fall back to compartment_ocid in main.tf
variable "network_compartment_ocid" {
  type    = string
  default = null
}

variable "availability_domain_number" {
  type = number
}

variable "fault_domain" {
  type = string
}

variable "image_ocid" {
  type = string
}

variable "ssh_public_key" {
  type = string
}

variable "ocpus" {
  type    = number
  default = 1
}

variable "memory_gb" {
  type    = number
  default = 6
}

# Security / networking defaults the env can override
variable "allowed_cidrs" {
  type    = list(string)
  default = ["0.0.0.0/0"]
}

variable "public_ingress_ports" {
  type    = list(number)
  default = [22, 80, 443]
}

variable "assign_public_ip" {
  type    = bool
  default = false
}
