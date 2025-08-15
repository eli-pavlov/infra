provider "oci" {
  tenancy_ocid = var.tenancy_ocid
  user_ocid    = var.user_ocid
  fingerprint  = var.fingerprint
  region       = var.region

  # Use exactly one of these. Leaving one empty is fine.
  private_key      = var.private_key_pem != ""  ? var.private_key_pem  : null
  private_key_path = var.private_key_path != "" ? var.private_key_path : null
}


# Availability Domains
data "oci_identity_availability_domains" "ads" {
  compartment_id = var.tenancy_ocid
}

locals {
  # Use same compartment unless a distinct network one is provided
  net_compartment = coalesce(var.network_compartment_ocid, var.compartment_ocid)

  # pick AD by index
  ad_name = data.oci_identity_availability_domains.ads.availability_domains[var.availability_domain_number].name

  tags = {
    app         = "newsapp"
    environment = "prod"
  }

  # Four nodes for a future k8s cluster
  nodes = {
    cp       = { role = "control-plane" }
    worker1  = { role = "worker" }
    worker2  = { role = "worker" }
    worker3  = { role = "worker" }
  }
}

# --- NETWORK FIRST ---
module "network" {
  source             = "../../modules/network"
  compartment_ocid   = local.net_compartment
  region             = var.region
  vcn_cidr           = "10.20.0.0/16"
  display_name_prefix= "newsapp"
  randomize_names    = true
  allowed_cidrs      = var.allowed_cidrs
  public_ingress_ports = var.public_ingress_ports
  freeform_tags      = local.tags
}

# --- INSTANCE GUARDS (simple, keep free-tier-ish) ---
resource "null_resource" "shape_guards" {
  lifecycle {
    precondition {
      condition     = (length(local.nodes) * var.ocpus) <= 8
      error_message = "Safety guard: total OCPUs would exceed 8 for demo."
    }
  }
}

# --- NODES ---
module "nodes" {
  source = "../../modules/instance"
  for_each = local.nodes

  name                     = "node-${each.key}"
  hostname                 = "node-${each.key}"
  role                     = each.value.role
  availability_domain_name = local.ad_name
  fault_domain             = var.fault_domain

  compartment_ocid = var.compartment_ocid
  subnet_ocid      = module.network.subnets.private_app
  image_ocid       = var.image_ocid
  ssh_public_key   = var.ssh_public_key

  assign_public_ip = var.assign_public_ip
  nsg_ids          = [module.network.nsg_ids.internal]

  ocpus            = var.ocpus
  memory_gb        = var.memory_gb

  # (Optional) Pass a cloud-init base64 if you want to preinstall deps
  cloud_init_base64 = ""
  tags              = local.tags
}
