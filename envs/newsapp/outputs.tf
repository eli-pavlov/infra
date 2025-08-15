output "vcn_id"        { value = module.network.vcn_id }
output "subnets"       { value = module.network.subnets }
output "nsg_ids"       { value = module.network.nsg_ids }

output "instance_ids"  { value = { for k, m in module.nodes : k => m.id } }
output "public_ips"    { value = { for k, m in module.nodes : k => m.public_ip } }
output "private_ips"   { value = { for k, m in module.nodes : k => m.private_ip } }
