variable "name" {
  type        = string
  description = "The display name for the compute instance."
}

variable "hostname" {
  type        = string
  description = "The hostname for the compute instance."
}

variable "role" {
  type        = string
  description = "The role of the instance (e.g., web-server, database)."
}

variable "availability_domain_name" {
  type        = string
  description = "The name of the availability domain to launch the instance in."
}

variable "fault_domain" {
  type        = string
  description = "The name of the fault domain to launch the instance in."
}

variable "compartment_ocid" {
  type        = string
  description = "The OCID of the compartment where the resources will be created."
}

variable "subnet_ocid" {
  type        = string
  description = "The OCID of the subnet to attach to the instance's primary VNIC."
}

variable "image_ocid" {
  type        = string
  description = "The OCID of the image to use for the instance."
}

variable "ssh_public_key" {
  type        = string
  description = "The SSH public key to be installed on the instance."
  sensitive   = true
}

variable "assign_public_ip" {
  type        = bool
  description = "Whether to assign a public IP address to the instance."
  default     = false
}

variable "nsg_ids" {
  type        = list(string)
  description = "A list of Network Security Group OCIDs to apply to the instance's VNIC."
  default     = []
}

variable "ocpus" {
  type        = number
  description = "The number of OCPUs for the instance."
}

variable "memory_gb" {
  type        = number
  description = "The amount of memory in GBs for the instance."
}

variable "cloud_init_base64" {
  type        = string
  description = "Cloud-init script to run on instance creation, encoded in base64."
  default     = ""
}

variable "tags" {
  type        = map(string)
  description = "A map of tags to apply to the instance."
  default     = {}
}