variable "ocpus" {
  type    = number
  default = 1
}

variable "memory_gb" {
  type    = number
  default = 6
}

variable "cloud_init" {
  type    = string
  default = ""
}

variable "tags" {
  type    = map(string)
  default = {}
}

variable "private_subnet_cidr" {
  type    = string
  default = "10.0.1.0/24"
}
