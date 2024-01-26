output "namespace" {
  value = var.namespace
}

output "service_name" {
  value = {
    server = kubernetes_service_v1.prometheus_server.metadata.0.name
    alert_manager = kubernetes_service_v1.prometheus_alert_manager.metadata.0.name
  }
}

output "admin_username" {
  value = "admin"
}

output "admin_password" {
  value = random_password.prometheus_server_admin_password.result
}

//output "service_port" {
//  description = "Produces a map of port names and their values, e.g. {'epmd': 4369, 'ampq': 5672, 'management': 15672}"
//  value = {
//    for item in kubernetes_service.rabbitmq.spec.0.port : item["name"] => item["port"]
//  }
//}
//
//output "erlang_cookie" {
//  value = random_password.erland_cookie.result
//}
//
//output "default_user" {
//  value = "admin"
//}
//
//output "default_pass" {
//  value = random_password.default_pass.result
//}
//
