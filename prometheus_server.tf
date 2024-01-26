resource "kubernetes_stateful_set_v1" "prometheus_server" {

  metadata {
    name        = local.name.prometheus_server
    namespace   = var.namespace
    annotations = {}
    labels      = local.labels.prometheus_server
  }

  spec {

    pod_management_policy = "Parallel"
    replicas              = var.replicas.prometheus-server

    selector {
      match_labels = local.selector_labels.prometheus_server
    }

    service_name = kubernetes_service_v1.prometheus_server.metadata.0.name

    template {

      metadata {
        labels = merge(local.labels.prometheus_server, { "app.kubernetes.io/config-hash" = md5(kubernetes_config_map_v1.prometheus_server.data["prometheus.yml"]) })
      }
      spec {
        service_account_name            = kubernetes_service_account_v1.prometheus.metadata.0.name
        automount_service_account_token = true
        priority_class_name             = var.priority_class

        security_context {
          run_as_user  = var.user_id
          run_as_group = var.group_id
          fs_group     = var.group_id
        }

        affinity {
          pod_anti_affinity {
            required_during_scheduling_ignored_during_execution {
              label_selector {
                match_expressions {
                  key      = "app.kubernetes.io/name"
                  operator = "In"
                  values   = [local.name.prometheus_server]
                }
                match_expressions {
                  key      = "app.kubernetes.io/instance"
                  operator = "In"
                  values   = [var.instance]
                }
              }
              topology_key = "kubernetes.io/hostname"
            }
          }
        }

        container {
          name              = "prometheus-server"
          image             = "${var.image_name.prometheus-server}:${var.image_tag.prometheus-server}"
          image_pull_policy = var.image_tag == "latest" ? "Always" : "IfNotPresent"
          args = [
            "--config.file=/etc/prometheus/prometheus.yml",
            "--web.config.file=/etc/prometheus/web.yml",
            "--storage.tsdb.path=${var.storage_path}",
            "--web.console.libraries=/usr/share/prometheus/console_libraries",
            "--web.console.templates=/usr/share/prometheus/consoles",
            "--log.level=debug"
          ]

          dynamic "env" {
            for_each = merge(var.extra_env, {})
            content {
              name  = env.key
              value = env.value
            }
          }

          port {
            name           = "http"
            protocol       = "TCP"
            container_port = 9090
          }

          resources {
            requests = {
              cpu    = "100m"
              memory = "512Mi"
            }
            limits = {
              cpu    = "300m"
              memory = "1024Mi"
            }
          }

          volume_mount {
            name       = "data"
            mount_path = var.storage_path
          }

          volume_mount {
            name       = "config"
            mount_path = "/etc/prometheus"
            read_only  = true
          }

          //dynamic "volume_mount" { ToDo: may need to implement TLS
          //  for_each = var.prometheus_tls_secret != null ? { pki = {} } : {}
          //  content {
          //    name       = "pki"
          //    mount_path = "/usr/share/prometheus/config/pki"
          //    read_only  = true
          //  }
          //}

          //readiness_probe {
          //  period_seconds        = 10
          //  initial_delay_seconds = 60
          //  success_threshold     = 1
          //  failure_threshold     = 3
          //  timeout_seconds       = 3
//
          //  http_get {
          //    scheme = "HTTP"
          //    path   = "/-/ready"
          //    port   = "http"
          //  }
          //}

        }

        dynamic "volume" {
          for_each = var.storage_class == null ? { data = {} } : {}
          content {
            name = volume.key
            empty_dir {}
          }
        }

        volume {
          name = "config"
          config_map {
            name = kubernetes_config_map_v1.prometheus_server.metadata.0.name
          }
        }

        //dynamic "volume" { ToDo: may need to implement TLS
        //  for_each = var.prometheus_tls_secret != null ? { pki = {} } : {}
        //  content {
        //    name = "pki"
        //    secret {
        //      secret_name = var.prometheus_tls_secret
        //      items {
        //        key  = "ca.crt"
        //        path = "ca.crt"
        //      }
        //    }
        //  }
        //}

        dynamic "toleration" {
          for_each = {
            for toleration in var.tolerations : toleration["key"] => toleration
          }
          content {
            key      = toleration.key
            operator = toleration.value["operator"]
            value    = toleration.value["value"]
            effect   = toleration.value["effect"]
          }
        }

      }

    }

    dynamic "volume_claim_template" {

      for_each = var.storage_class != null ? { data = {} } : {}

      content {
        metadata {
          name = volume_claim_template.key
        }
        spec {

          storage_class_name = var.storage_class
          access_modes       = ["ReadWriteOnce"]

          resources {
            requests = {
              storage = var.storage_size
            }
          }

        }
      }

    }

  }
  wait_for_rollout = var.wait_for_rollout
}

resource "kubernetes_service_account_v1" "prometheus" {
  metadata {
    name        = local.name.prometheus_server
    namespace   = var.namespace
    labels      = local.labels.prometheus_server
    annotations = var.service_account_annotations
  }

  dynamic "image_pull_secret" {
    for_each = { for image_pull_secret in var.image_pull_secrets : image_pull_secret => {} }
    content {
      name = image_pull_secret.key
    }
  }

}

resource "kubernetes_config_map_v1" "prometheus_server" {
  metadata {
    name        = local.name.prometheus_server
    namespace   = var.namespace
    annotations = {}
    labels      = local.labels.prometheus_server
  }
  data = {
    "prometheus.yml" = replace(yamlencode({
      global = {
        scrape_interval : "5s"
      }
      scrape_configs = [
        {
          job_name = "kubernetes-nodes"
          scheme   = "https"
          tls_config = {
            insecure_skip_verify = true
          }
          bearer_token_file = "/var/run/secrets/kubernetes.io/serviceaccount/token"
          kubernetes_sd_configs = [
            {
              role = "node"
            }
          ]
          metrics_path = "/metrics/cadvisor"
        },
        {
          job_name = "kubernetes-pods"
          kubernetes_sd_configs = [
            {
              role = "pod"
              selectors = [
                {
                  role = "pod"
                }
              ]
            }
          ]
          relabel_configs = [
            {
              source_labels = ["__meta_kubernetes_namespace"]
              action        = "replace"
              regex         = "(.*)"
              replacement   = "$1"
              target_label  = "namespace"
            },
            {
              source_labels = ["__address__", "__meta_kubernetes_pod_annotation_prometheus_io_port"]
              action        = "replace"
              regex         = "([^:]+)(?::\\d+)?;(\\d+)"
              replacement   = "$1:$2"
              target_label  = "__address__"
            },
            {
              source_labels = ["__meta_kubernetes_pod_annotation_prometheus_io_path"]
              action        = "replace"
              regex         = "(.+)"
              target_label  = "__metrics_path__"
            },
            {
              source_labels = ["__meta_kubernetes_pod_annotation_prometheus_io_scrape", "__meta_kubernetes_pod_container_port_name"]
              action        = "keep"
              regex         = "true;metrics"
            }
          ]
          metrics_path = "/metrics"
        }
      ]
      //rule_files = [
      //  "/etc/prometheus/alert_rules.yml"
      //]
      alerting = {
        alertmanagers = [
          {
            static_configs = [
              {
                targets = [ for i in range(var.replicas.prometheus-alert-manager) :
                  "${kubernetes_service_v1.prometheus_alert_manager.metadata.0.name}-${i}.${kubernetes_service_v1.prometheus_alert_manager.metadata.0.name}:9093"
                ]
              }
            ]
          }
        ]
      }
    }), "\"", "") // Prometheus does not like quotas around regex
    "web.yml" = replace(yamlencode({
      basic_auth_users = {
        admin = random_password.prometheus_server_admin_password.bcrypt_hash
      }
    }), "\"", "") // Prometheus does not like quotas around regex
    "alert_rules.yml" = replace(yamlencode({
      groups = [
        {
          name = "alert"
          rules = [
            {
              alert = "InstanceDown"
              expr = "container_memory_usage_bytes > 0"
              for = "1m"
              labels = {
                severity = "critical"
              }
              annotations = {
                summary = "Endpoint {{ $labels.instance }} down"
                description = "{{ $labels.instance }} of job {{ $labels.job }} has been down for more than 1 minutes."
              }
            }
          ]
        }
        ]
    }), "\"", "") // Prometheus does not like quotas around regex
  }
}

resource "kubernetes_service_v1" "prometheus_server" {

  metadata {
    name        = local.name.prometheus_server
    namespace   = var.namespace
    annotations = var.service_annotations
    labels      = local.labels.prometheus_server
  }

  spec {
    type = "ClusterIP"

    port {
      name        = "http"
      protocol    = "TCP"
      port        = 80
      target_port = "http"
    }

    selector = local.selector_labels.prometheus_server

  }

}

resource "kubernetes_cluster_role_v1" "prometheus_server" {

  metadata {
    name   = local.name.prometheus_server
    labels = local.labels.prometheus_server
  }

  rule {
    api_groups = [""]
    resources = [
      "nodes",
      "services",
      "endpoints",
      "pods"
    ]
    verbs = [
      "get",
      "list",
      "watch"
    ]
  }

  rule {
    non_resource_urls = ["/metrics"]
    verbs = [
      "get"
    ]
  }

}

resource "kubernetes_cluster_role_binding_v1" "prometheus_server" {

  metadata {
    name   = local.name.prometheus_server
    labels = local.labels.prometheus_server
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "cluster-admin" // ToDo: fix RBAC
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account_v1.prometheus.metadata.0.name
    namespace = var.namespace
  }

}

resource "random_password" "prometheus_server_admin_password" {
  length  = 64
  upper   = true
  lower   = true
  numeric = true
  special = true
}
