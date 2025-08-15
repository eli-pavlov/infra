# Network
output "vcn_id" {
  value = oci_core_virtual_network.vcn.id
}

output "subnet_ids" {
  value = {
    public  = oci_core_subnet.public.id
    private = oci_core_subnet.private.id
  }
}

output "nsg_ids" {
  value = {
    public_www = oci_core_network_security_group.nsg_public_www.id
    internal   = oci_core_network_security_group.nsg_internal.id
  }
}

# Instances (maps keyed by node name)
output "instance_ids" {
  value = { for k, m in module.nodes : k => m.id }
}

output "public_ips" {
  value = { for k, m in module.nodes : k => m.public_ip }
}

output "private_ips" {
  value = { for k, m in module.nodes : k => m.private_ip }
}
