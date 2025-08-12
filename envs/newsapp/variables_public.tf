variable "instances" { type = number, default = 4 }
variable "ocpus"     { type = number, default = 1 }
variable "memory_gb" { type = number, default = 6 }

variable "cloud_init"  { type = string, default = "" }
variable "tags"        { type = map(string), default = {} }
