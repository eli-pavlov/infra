#######################
# Sensitive variables #
#######################

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

variable "compartment_ocid" {
  type      = string
  sensitive = true
}

variable "network_compartment_ocid" {
  type      = string
  sensitive = true
}

variable "availability_domain_number" {
  type      = number
  sensitive = true
}

variable "fault_domain" {
  type      = string
  sensitive = true
}

variable "image_ocid" {
  type      = string
  sensitive = true
}

variable "ssh_public_key" {
  type      = string
  sensitive = true
}
