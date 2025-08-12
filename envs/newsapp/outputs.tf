output "summary" {
  value = {
    names     = local.node_names
    ad        = local.ad_name
    fd        = var.fault_domain
    subnet_id = local.subnet_id
    image_id  = var.image_ocid
  }
}
