# Lists
output "instance_ids" {
  value = [for m in module.nodes : m.id]
}

output "public_ips" {
  value = [for m in module.nodes : m.public_ip]
}

output "private_ips" {
  value = [for m in module.nodes : m.private_ip]
}

# Name -> values maps
output "node_public_ips" {
  value = zipmap(local.node_names, [for m in module.nodes : m.public_ip])
}

output "node_private_ips" {
  value = zipmap(local.node_names, [for m in module.nodes : m.private_ip])
}

output "node_ids" {
  value = zipmap(local.node_names, [for m in module.nodes : m.id])
}

output "node_roles" {
  value = zipmap(local.node_names, local.node_roles)
}

# Infra summary (explicitly declassify each potentially-sensitive contributor)
output "summary" {
  value = {
    names            = local.node_names
    roles            = local.node_roles
    ad               = nonsensitive(local.ad_name)
    fd               = nonsensitive(var.fault_domain)
    vcn_id           = nonsensitive(local.vcn_id)
    public_subnet_id = nonsensitive(local.public_subnet_id)
    private_subnet   = nonsensitive(oci_core_subnet.private.id)
  }
}
