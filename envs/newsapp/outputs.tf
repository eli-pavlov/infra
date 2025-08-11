output "summary" {
  value = {
    instances = var.instances
    ad        = local.ad_name
    fd        = var.fault_domain
    subnet_id = local.subnet_id
    image_id  = local.image_id
  }
}
